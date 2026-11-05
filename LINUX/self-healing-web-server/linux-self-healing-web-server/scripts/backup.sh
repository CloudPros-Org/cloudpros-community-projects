#!/bin/bash
mkdir  -p /var/backups/cloudpros/
SOURCE_DIR="/opt/cloudpros/"
filename="cloudpros_backup_$(date +%Y%m%d).tar.gz"
backupdir="/var/backups/cloudpros"
tar -czf "$backupdir/$filename" -C "$(dirname "$SOURCE_DIR")" "$(basename "$SOURCE_DIR")" || exit 1 
tar -tzf "$backupdir/$filename" > /dev/null #Ensure backup is zippable
statuschecker=$?
if [ "$statuschecker" -eq 0 ]; then
	echo "Archiving complete"
else 
	echo "not complete"
fi

find "$backupdir/" -type f -name "cloudpros_backup_*.tar.gz" -mtime +7 -delete #Delete backup after 7days 

