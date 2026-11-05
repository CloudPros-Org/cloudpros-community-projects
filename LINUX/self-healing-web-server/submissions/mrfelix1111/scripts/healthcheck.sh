#!/bin/bash
set -euo pipefail

APP_URL="http://127.0.0.1:8000"
SERVICE="cloudpros-app.service"
LOG_FILE="/var/log/cloudpros/healthcheck.log"

mkdir -p /var/log/cloudpros

if curl --silent --fail --max-time 5 "$APP_URL" > /dev/null; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Application is healthy." | tee -a "$LOG_FILE"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Application is unhealthy. Restarting $SERVICE." | tee -a "$LOG_FILE"
    systemctl restart "$SERVICE"
fi
