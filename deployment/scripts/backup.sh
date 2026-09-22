#!/bin/bash
# Backup script for Murassikh PostgreSQL Database
# F-17: Backup and Monitoring (pg_dump, retention, encryption)

set -e

# Configuration
BACKUP_DIR=${BACKUP_DIR:-"/var/backups/murassikh"}
RETENTION_DAYS=${RETENTION_DAYS:-7}
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DB_CONTAINER="staging-postgres-1" # Update with actual container name if different
DB_USER=${POSTGRES_USER:-murassikh}
DB_NAME=${POSTGRES_DB:-murassikh_db}
BACKUP_FILE="$BACKUP_DIR/murassikh_db_$TIMESTAMP.sql.gz"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting PostgreSQL backup for $DB_NAME..."

# Execute pg_dump inside the postgres container and gzip the output
docker exec -t "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -F c | gzip > "$BACKUP_FILE"

echo "[$(date)] Backup completed: $BACKUP_FILE"

# F-17 #2: Enforce Retention Policy
echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "[$(date)] Cleanup finished."
