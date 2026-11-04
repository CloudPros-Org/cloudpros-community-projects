#!/bin/bash

LOGFILE="/var/log/cloudpros/health.log"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Check application health
HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000)

if [ "$HTTP_RESPONSE" -eq 200 ]; then
    echo "$TIMESTAMP - HEALTHY (HTTP $HTTP_RESPONSE)" >> "$LOGFILE"
else
    echo "$TIMESTAMP - UNHEALTHY (HTTP $HTTP_RESPONSE) - Restarting cloudpros-app" >> "$LOGFILE"
    systemctl restart cloudpros-app
fi
