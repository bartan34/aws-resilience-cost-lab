#!/bin/bash
# Inject one fault and log the injection time.
# Usage: scripts/fault.sh f1|f2a|f2b t0|t1|t2
#   f1   terminate one running app instance of the tier
#   f2a  plain database reboot (same operation on every tier)
#   f2b  loss of the primary database:
#        Multi-AZ  -> reboot with forced failover
#        Single-AZ -> stop, wait until stopped, start (no standby to fail over to)
set -euo pipefail
export AWS_PROFILE=ca2 AWS_PAGER="" AWS_DEFAULT_REGION=eu-west-1

FAULT=$1
TIER_LC=$2
TIER_UC=$(echo "$TIER_LC" | tr '[:lower:]' '[:upper:]')
LOG="$(dirname "$0")/../data/raw/faults.csv"

now() {
  python3 -c 'from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat(timespec="milliseconds"))'
}

[ -f "$LOG" ] || echo "injected_utc,tier,fault,target,detail" > "$LOG"

case "$FAULT" in
  f1)
    TARGET=$(aws ec2 describe-instances \
      --filters Name=tag:Tier,Values="$TIER_UC" Name=instance-state-name,Values=running \
      --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' '\n' |
      awk 'NF {a[++n]=$0} END {srand(); if (n) print a[int(rand()*n)+1]}')
    [ -n "$TARGET" ] || { echo "no running instance for $TIER_UC"; exit 1; }
    T=$(now)
    aws ec2 terminate-instances --instance-ids "$TARGET" > /dev/null
    DETAIL="terminate-instances"
    ;;
  f2a)
    TARGET="ca2-$TIER_LC"
    T=$(now)
    aws rds reboot-db-instance --db-instance-identifier "$TARGET" > /dev/null
    DETAIL="reboot"
    ;;
  f2b)
    TARGET="ca2-$TIER_LC"
    MULTI=$(aws rds describe-db-instances --db-instance-identifier "$TARGET" \
      --query 'DBInstances[0].MultiAZ' --output text)
    T=$(now)
    if [ "$MULTI" = "True" ]; then
      aws rds reboot-db-instance --db-instance-identifier "$TARGET" --force-failover > /dev/null
      DETAIL="reboot-with-failover"
    else
      aws rds stop-db-instance --db-instance-identifier "$TARGET" > /dev/null
      echo "$T stop issued on $TARGET, waiting for status stopped..."
      until [ "$(aws rds describe-db-instances --db-instance-identifier "$TARGET" \
        --query 'DBInstances[0].DBInstanceStatus' --output text)" = "stopped" ]; do
        sleep 5
      done
      T_START=$(now)
      aws rds start-db-instance --db-instance-identifier "$TARGET" > /dev/null
      DETAIL="stop-then-start (start issued $T_START)"
    fi
    ;;
  *)
    echo "usage: $0 f1|f2a|f2b t0|t1|t2"
    exit 1
    ;;
esac

echo "$T,$TIER_UC,$FAULT,$TARGET,$DETAIL" >> "$LOG"
echo "$T injected $FAULT on $TIER_UC ($TARGET, $DETAIL)"