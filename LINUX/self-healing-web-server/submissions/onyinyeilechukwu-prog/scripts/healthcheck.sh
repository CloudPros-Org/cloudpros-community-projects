#!/usr/bin/env bash
# CloudPros health check: request the app, log the result, restart it if unhealthy.

URL="http://127.0.0.1:8000"
LOG="/var/log/cloudpros/healthcheck.log"

now() { date '+%Y-%m-%d %H:%M:%S'; }

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$URL")

if [ "$code" = "200" ]; then
  echo "$(now) OK: $URL returned HTTP $code" >> "$LOG"
else
  echo "$(now) FAIL: $URL returned HTTP $code, restarting cloudpros-app" >> "$LOG"
  systemctl restart cloudpros-app
fi
