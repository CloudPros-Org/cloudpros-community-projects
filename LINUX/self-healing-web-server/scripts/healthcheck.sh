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
        # Restart returning 0 only means systemd started the process, not that the app is healthy.
        # Re-checking the endpoint, with a brief delay to give the app time to bind to the port.
        HTTP_STATUS="000"
        for _ in 1 2 3 4 5; do
            sleep 2
            HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$URL")
            [ "$HTTP_STATUS" -eq 200 ] && break
        done

        if [ "$HTTP_STATUS" -eq 200 ]; then
            echo "[$TIMESTAMP] RECOVERY SUCCESSFUL: cloudpros-app.service restarted and responding with HTTP 200." >> "$LOG_FILE"
        else
            echo "[$TIMESTAMP] RECOVERY FAILED: Service restarted but still returning HTTP Status $HTTP_STATUS." >> "$LOG_FILE"
            exit 1
        fi
    else
        echo "[$TIMESTAMP] RECOVERY FAILED: Unable to restart cloudpros-app.service." >> "$LOG_FILE"
        exit 1
    fi
fi
