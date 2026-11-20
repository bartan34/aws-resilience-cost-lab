#!/bin/bash
# Run the formal fault sequence for one tier.
# Start the probe in another terminal first.
# Usage: scripts/run_tier.sh t1|t2
set -euo pipefail
export AWS_PROFILE=ca2 AWS_PAGER="" AWS_DEFAULT_REGION=eu-west-1
cd "$(dirname "$0")/.."

TIER=$1
case "$TIER" in
  t1) SEQ="f1 f2a f2a f1 f2b f1 f2a f2b f1 f2a f1 f2a f2b" ;;
  t2) SEQ="f2b f1 f2a f2b f1 f2b f2a f1 f2b f2a f2b" ;;
  *) echo "usage: $0 t1|t2"; exit 1 ;;
esac

[ -n "${2:-}" ] && SEQ="$2"

URL=$(terraform -chdir=terraform/envs/"$TIER" output -raw app_url)
TG=$(aws elbv2 describe-target-groups --names "ca2-$TIER" \
  --query 'TargetGroups[0].TargetGroupArn' --output text)

healthy_targets() {
  aws elbv2 describe-target-health --target-group-arn "$TG" \
    --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
    --output text
}

db_reachable() {
  [ "$(curl -s -m 3 -o /dev/null -w '%{http_code}' "$URL/health/deep")" = "200" ]
}

db_available() {
  [ "$(aws rds describe-db-instances --db-instance-identifier "ca2-$TIER" \
    --query 'DBInstances[0].DBInstanceStatus' --output text)" = "available" ]
}

wait_steady() {
  until [ "$(healthy_targets)" = "2" ] && db_reachable && db_available; do
    sleep 10
  done
}

stamp() { date -u +%H:%M:%S; }

echo "$(stamp) waiting for steady state, then 180 s baseline"
wait_steady
sleep 180

n=0
for F in $SEQ; do
  n=$((n + 1))
  echo "$(stamp) run $n: $F"
  scripts/fault.sh "$F" "$TIER"
  sleep 60
  wait_steady
  echo "$(stamp) run $n: steady again, settling 120 s"
  sleep 120
done

echo "$(stamp) sequence complete - stop the probe now"