#!/usr/bin/env bash

set -euo pipefail

# Report directory
REPORT_DIR="${REPORT_DIR:-/var/log/shoplite}"

# Timestamped logging function
log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"
}

log "Starting ShopLite report cleanup"

# Check that the report directory exists
if [[ ! -d "$REPORT_DIR" ]]; then
    log "Report directory does not exist. Nothing to clean."
    exit 0
fi

# Find and delete ShopLite reports older than 14 days
find "$REPORT_DIR" \
    -maxdepth 1 \
    -type f \
    -name 'sysreport-*.log*' \
    -mmin +20160 \
    -print \
    -delete

log "ShopLite report cleanup completed"
