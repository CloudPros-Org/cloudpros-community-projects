#!/bin/bash

set -euo pipefail

BACKUP_DIR="/var/backups/cloudpros"
DATE=$(date +%F)

mkdir -p "$BACKUP_DIR"

tar -czf "$BACKUP_DIR/cloudpros-${DATE}.tar.gz" \
    -C /opt cloudpros

find "$BACKUP_DIR" \
    -type f \
    -name 'cloudpros-*.tar.gz' \
    -mmin +10080 \
    -delete

echo "$(date): Backup created successfully: cloudpros-${DATE}.tar.gz"
