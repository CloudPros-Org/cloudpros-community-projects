#!/bin/bash
set -e

SOURCE_DIR="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
DATE=$(date "+%Y-%m-%d")
FILENAME="cloudpros-$DATE.tar.gz"
BACKUP_PATH="$BACKUP_DIR/$FILENAME"

# 1. Create the compressed tarball archive
echo "Starting backup of $SOURCE_DIR..."
tar -czf "$BACKUP_PATH" -C "$SOURCE_DIR" .

# 2. Verify that the backup archive can be extracted successfully (-t tests the archive)
echo "Verifying backup integrity..."
if tar -tzf "$BACKUP_PATH" > /dev/null; then
    echo "Backup verification PASSED successfully."
else
    echo "ERROR: Backup verification FAILED!" >&2
    rm -f "$BACKUP_PATH"
    exit 1
fi

# 3. Automatically delete backups older than 7 days
echo "Cleaning up backups older than 7 days..."
find "$BACKUP_DIR" -name "cloudpros-*.tar.gz" -type f -mtime +7 -delete

echo "Backup workflow completed successfully."
