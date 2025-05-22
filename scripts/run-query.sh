#!/bin/bash
# scripts/run-query.sh
set -e

# Debug information
echo "Running query script with connection string: $1"
echo "Query: $2"

# Hard-coded values for now
HOST="mysql"
PORT="3306" 
DB="demo"
USER="root"
PASSWORD="password123"

# Debug info about what was passed
echo "Received connection string: $1"
QUERY=$2

echo "Connecting to MySQL: Host=$HOST, Port=$PORT, DB=$DB, User=$USER"
mysql -h $HOST -P $PORT -u $USER -p$PASSWORD $DB -e "$QUERY"
