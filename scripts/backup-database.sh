# scripts/backup-database.sh
#!/bin/bash
set -e

HOST=$(echo $1 | cut -d: -f1)
PORT=$(echo $1 | cut -d: -f2 | cut -d/ -f1)
DB=$(echo $1 | cut -d/ -f2 | cut -d: -f1)
USER=$(echo $1 | cut -d: -f2 | cut -d@ -f1)
PASSWORD=$(echo $1 | cut -d@ -f2)
BACKUP_PATH=$2

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_PATH}/backup_${DB}_${TIMESTAMP}.sql"

mysqldump -h $HOST -P $PORT -u $USER -p$PASSWORD $DB > $BACKUP_FILE

echo "Backup created at $BACKUP_FILE"
