#!/usr/bin/env bash
# Checks the website and restarts the app if it does not answer.
LOG=/var/log/cloudpros/healthcheck.log
URL=http://127.0.0.1/

mkdir -p /var/log/cloudpros
if curl -fsS --max-time 5 -o /dev/null "$URL"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') OK site is up" >> "$LOG"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') DOWN site not responding, restarting cloudpros-app" >> "$LOG"
    systemctl restart cloudpros-app
fi
