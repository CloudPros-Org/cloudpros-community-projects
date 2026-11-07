#!/usr/bin/env bash
# CloudPros backup: archive /opt/cloudpros with the date in the name,
# then delete backups older than seven days.
set -e

DEST="/var/backups/cloudpros"
FILE="$DEST/cloudpros-$(date +%F).tar.gz"

mkdir -p "$DEST"
tar -czf "$FILE" -C /opt cloudpros
find "$DEST" -name 'cloudpros-*.tar.gz' -type f -mtime +7 -delete
