#!/bin/bash

SOURCE_DIR="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
DATE=$(date +"%Y-%m-%d")
BACKUP_FILE="$BACKUP_DIR/cloudpros-$DATE.tar.gz"
LOGFILE="/var/log/cloudpros/backup.log"

mkdir -p "$BACKUP_DIR"

# Create backup
tar -czf "$BACKUP_FILE" "$SOURCE_DIR"
STATUS=$?

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

if [ $STATUS -eq 0 ]; then
    echo "$TIMESTAMP - Backup created: $BACKUP_FILE" >> "$LOGFILE"
else
    echo "$TIMESTAMP - Backup FAILED" >> "$LOGFILE"
    exit 1
fi

# Delete backups older than 7 days
find "$BACKUP_DIR" -type f -mtime +7 -name "cloudpros-*.tar.gz" -exec rm {} \;

# Verify backup integrity
tar -tzf "$BACKUP_FILE" > /dev/null
VERIFY=$?

if [ $VERIFY -eq 0 ]; then
    echo "$TIMESTAMP - Backup verified successfully" >> "$LOGFILE"
else
    echo "$TIMESTAMP - Backup verification FAILED" >> "$LOGFILE"
fi
