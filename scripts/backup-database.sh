# scripts/backup-database.sh
#!/bin/bash
set -e

# Hard-coded values for now
HOST="mysql"
PORT="3306" 
DB="demo"
USER="root"
PASSWORD="password123"

# Debug info about what was passed
echo "Received connection string: $1"
BACKUP_PATH=$2

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_PATH}/backup_${DB}_${TIMESTAMP}.sql"

mysqldump -h $HOST -P $PORT -u $USER -p$PASSWORD $DB > $BACKUP_FILE

echo "Backup created at $BACKUP_FILE"
