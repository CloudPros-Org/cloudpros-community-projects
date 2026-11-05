#!/usr/bin/env bash
set -u

LOG_DIR="/var/log/cloudpros"
LOG_FILE="$LOG_DIR/healthcheck.log"
URL="http://127.0.0.1:8000"

mkdir -p "$LOG_DIR"

log() {
    printf '%s - %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" \
        >> "$LOG_FILE"
}

if curl --silent --fail --max-time 5 "$URL" >/dev/null; then
    log "HEALTHY: Application returned HTTP success"
else
    log "UNHEALTHY: Application check failed; restarting service"

    if systemctl restart cloudpros-app; then
        log "RECOVERY: Restart command completed"
    else
        log "ERROR: Failed to restart cloudpros-app"
        exit 1
    fi
fi

