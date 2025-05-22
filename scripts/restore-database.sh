# scripts/restore-database.sh
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
BACKUP_FILE=$2

# Create database if it doesn't exist
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD -e "CREATE DATABASE IF NOT EXISTS $DB"

# Restore the backup
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD $DB < $BACKUP_FILE

echo "Database $DB restored from $BACKUP_FILE"
