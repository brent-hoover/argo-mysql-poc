# scripts/run-query.sh
#!/bin/bash
set -e

HOST=$(echo $1 | cut -d: -f1)
PORT=$(echo $1 | cut -d: -f2 | cut -d/ -f1)
DB=$(echo $1 | cut -d/ -f2 | cut -d: -f1)
USER=$(echo $1 | cut -d: -f2 | cut -d@ -f1)
PASSWORD=$(echo $1 | cut -d@ -f2)
QUERY=$2

mysql -h $HOST -P $PORT -u $USER -p$PASSWORD $DB -e "$QUERY"
