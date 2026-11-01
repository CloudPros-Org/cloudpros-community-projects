#!/usr/bin/env bash
set -euo pipefail

SOURCE="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
DATE="$(date +%F)"
BACKUP_FILE="$BACKUP_DIR/cloudpros-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_FILE" -C /opt cloudpros

# Remove backups older than seven days.
find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'cloudpros-*.tar.gz' \
    -mmin +10080 -delete

printf '%s - Backup created: %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$BACKUP_FILE"
