#!/bin/bash
cd "$(dirname "$0")/../terraform/envs/t0" || exit 1

START=$(date +%s)
terraform apply -auto-approve
APPLIED=$(date +%s)

URL=$(terraform output -raw app_url)
until [ "$(curl -s -o /dev/null -m 2 -w '%{http_code}' -X POST $URL/write)" = "200" ]; do
  sleep 1
done
READY=$(date +%s)

echo "terraform apply:   $((APPLIED-START)) s"
echo "boot to first 200: $((READY-APPLIED)) s"
echo "total:             $((READY-START)) s"
date -u +"finished %Y-%m-%dT%H:%M:%SZ"
curl -s $URL/read