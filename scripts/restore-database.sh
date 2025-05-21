# scripts/restore-database.sh
#!/bin/bash
set -e

HOST=$(echo $1 | cut -d: -f1)
PORT=$(echo $1 | cut -d: -f2 | cut -d/ -f1)
DB=$(echo $1 | cut -d/ -f2 | cut -d: -f1)
USER=$(echo $1 | cut -d: -f2 | cut -d@ -f1)
PASSWORD=$(echo $1 | cut -d@ -f2)
BACKUP_FILE=$2

# Create database if it doesn't exist
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB"

# Restore the backup
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD $DB < $BACKUP_FILE

echo "Database $DB restored from $BACKUP_FILE"
