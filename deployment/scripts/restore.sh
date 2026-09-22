#!/bin/bash
# Restore script for Murassikh PostgreSQL Database
# F-17: Test restore periodic

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_backup_file.sql.gz>"
    exit 1
fi

BACKUP_FILE=$1
DB_CONTAINER="staging-postgres-1" # Update with actual container name if different
DB_USER=${POSTGRES_USER:-murassikh}
DB_NAME=${POSTGRES_DB:-murassikh_db}

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file $BACKUP_FILE does not exist."
    exit 1
fi

echo "[$(date)] Warning: This will overwrite the current database ($DB_NAME)."
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

echo "[$(date)] Restoring PostgreSQL database from $BACKUP_FILE..."

# Unzip and pipe into pg_restore inside the container
# Use --clean to drop objects before recreating them
gunzip -c "$BACKUP_FILE" | docker exec -i "$DB_CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists

echo "[$(date)] Restore completed successfully."
