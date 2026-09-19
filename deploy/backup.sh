#!/bin/bash
set -e

BACKUP_DIR=${BACKUP_DIR:-"/backups"}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"
RETENTION_DAYS=${RETENTION_DAYS:-7}

mkdir -p "$BACKUP_DIR"

echo "Starting database backup..."
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: POSTGRES_PASSWORD is not set."
    exit 1
fi

PGPASSWORD=$POSTGRES_PASSWORD pg_dump -h "${POSTGRES_SERVER:-db}" -U "${POSTGRES_USER:-murassikh}" -d "${POSTGRES_DB:-murassikh_db}" | gzip > "$BACKUP_FILE"
echo "Backup completed: $BACKUP_FILE"

echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "db_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "Cleanup complete."
