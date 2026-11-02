#!/bin/bash

URL="http://127.0.0.1:8000"
LOG_FILE="/var/log/cloudpros/health.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Performs HTTP check. Silently request headers and pull the HTTP code status.
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL")

if [ "$HTTP_STATUS" -eq 200 ]; then
    echo "[$TIMESTAMP] HEALTH CHECK PASSED: Service is responding with HTTP 200." >> "$LOG_FILE"
else
    echo "[$TIMESTAMP] HEALTH CHECK FAILED: HTTP Status $HTTP_STATUS. Initiating recovery..." >> "$LOG_FILE"
    # Restart the service to heal the application
    sudo systemctl restart cloudpros-app.service

    if [ $? -eq 0 ]; then
        echo "[$TIMESTAMP] RECOVERY SUCCESSFUL: cloudpros-app.service has been restarted." >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] RECOVERY FAILED: Unable to restart cloudpros-app.service." >> "$LOG_FILE"
    fi
fi
