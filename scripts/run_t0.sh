#!/bin/bash
# Formal T0 sequence: 3 x (terminate the instance, rebuild it with
# Terraform, wait for the first healthy response).
# Start the probe in another terminal first.
set -euo pipefail
export AWS_PROFILE=ca2 AWS_PAGER="" AWS_DEFAULT_REGION=eu-west-1
cd "$(dirname "$0")/.."

TF="terraform -chdir=terraform/envs/t0"
URL=$($TF output -raw app_url)
OUT=data/raw/t0_rebuilds.csv
[ -f "$OUT" ] || echo "run,max_seq_before,fault_epoch,apply_done_epoch,ready_epoch,max_seq_after" > "$OUT"

stamp() { date -u +%H:%M:%S; }
max_seq() {
  curl -s -m 3 "$URL/read" | python3 -c 'import sys, json; print(json.load(sys.stdin)["max_seq"])'
}

echo "$(stamp) baseline 180 s"
sleep 180

for n in 1 2 3; do
  BEFORE=$(max_seq)
  echo "$(stamp) run $n: f1 (max_seq before = $BEFORE)"
  scripts/fault.sh f1 t0
  T_FAULT=$(date +%s)
  $TF apply -auto-approve -replace=aws_instance.app > /dev/null
  T_APPLIED=$(date +%s)
  until [ "$(curl -s -m 2 -o /dev/null -w '%{http_code}' "$URL/health/deep")" = "200" ]; do
    sleep 1
  done
  T_READY=$(date +%s)
  AFTER=$(max_seq)
  echo "$n,$BEFORE,$T_FAULT,$T_APPLIED,$T_READY,$AFTER" >> "$OUT"
  echo "$(stamp) run $n: back after $((T_READY - T_FAULT)) s (apply $((T_APPLIED - T_FAULT)) s), max_seq after = $AFTER; settling 120 s"
  sleep 120
done

echo "$(stamp) sequence complete - stop the probe now"