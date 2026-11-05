
#!/usr/bin/env bash
set -euo pipefail

SOURCE="/opt/cloudpros"
BACKUP_DIR="/var/backups/cloudpros"
DATE="$(date +%F)"
BACKUP_FILE="$BACKUP_DIR/cloudpros-$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

# Create the compressed backup.
if ! tar -czf "$BACKUP_FILE" -C /opt cloudpros; then
    echo "ERROR: Backup creation failed: $BACKUP_FILE" >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

# Verify that the archive can be read.
if ! tar -tzf "$BACKUP_FILE" >/dev/null; then
    echo "ERROR: Backup verification failed: $BACKUP_FILE" >&2
    rm -f "$BACKUP_FILE"
    exit 1
fi

printf '%s - Backup created and verified: %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$BACKUP_FILE"

# Remove backups older than seven days.
find "$BACKUP_DIR" -maxdepth 1 -type f \
    -name 'cloudpros-*.tar.gz' \
    -mmin +10080 -delete
