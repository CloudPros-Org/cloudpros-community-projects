#!/usr/bin/env bash
# Backs up /opt/cloudpros daily and deletes backups 7 days old or more.
set -euo pipefail
DEST=/var/backups/cloudpros

mkdir -p "$DEST"
tar -czf "$DEST/cloudpros-$(date +%F).tar.gz" -C /opt cloudpros
find "$DEST" -name 'cloudpros-*.tar.gz' -mtime +6 -delete
echo "$(date '+%Y-%m-%d %H:%M:%S') backup done" >> /var/log/cloudpros/backup.log
