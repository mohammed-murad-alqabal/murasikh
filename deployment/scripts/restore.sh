#!/bin/bash
# Restore PostgreSQL and optionally Chroma backups for Murassikh.

set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: $0 <postgres_backup.sql.gz> [chroma_backup.tar.gz]"
    exit 1
fi

DB_BACKUP_FILE=$1
CHROMA_BACKUP_FILE=${2:-}
DB_CONTAINER=${DB_CONTAINER:-"staging-postgres-1"}
CHROMA_VOLUME=${CHROMA_VOLUME:-}
DB_USER=${POSTGRES_USER:-murassikh}
DB_NAME=${POSTGRES_DB:-murassikh_db}

if [ ! -f "$DB_BACKUP_FILE" ]; then
    echo "Error: Backup file $DB_BACKUP_FILE does not exist."
    exit 1
fi

if [ ! -f "$DB_BACKUP_FILE.sha256" ]; then
    echo "Error: checksum file $DB_BACKUP_FILE.sha256 is required."
    exit 1
fi
sha256sum --check "$DB_BACKUP_FILE.sha256"

if [ -n "$CHROMA_BACKUP_FILE" ]; then
    if [ -z "$CHROMA_VOLUME" ]; then
        echo "Error: CHROMA_VOLUME is required when restoring Chroma."
        exit 1
    fi
    if [ ! -f "$CHROMA_BACKUP_FILE" ] || [ ! -f "$CHROMA_BACKUP_FILE.sha256" ]; then
        echo "Error: Chroma backup and checksum files are both required."
        exit 1
    fi
    sha256sum --check "$CHROMA_BACKUP_FILE.sha256"
fi

echo "[$(date)] Warning: This will overwrite the current database ($DB_NAME)."
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
 echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Restore cancelled."
    exit 1
fi

echo "[$(date)] Restoring PostgreSQL database from $DB_BACKUP_FILE..."
gunzip -c "$DB_BACKUP_FILE" | docker exec -i "$DB_CONTAINER" pg_restore -U "$DB_USER" -d "$DB_NAME" --clean --if-exists

if [ -n "$CHROMA_BACKUP_FILE" ]; then
    echo "[$(date)] Restoring Chroma volume $CHROMA_VOLUME..."
    CHROMA_BACKUP_NAME=$(basename "$CHROMA_BACKUP_FILE")
    CHROMA_BACKUP_DIR=$(cd "$(dirname "$CHROMA_BACKUP_FILE")" && pwd)
    docker run --rm \
      -v "$CHROMA_VOLUME:/target" \
      -v "$CHROMA_BACKUP_DIR:/backup:ro" \
      -e "ARCHIVE_NAME=$CHROMA_BACKUP_NAME" \
      alpine:3.20 \
      sh -c 'rm -rf /target/* && tar -xzf "/backup/$ARCHIVE_NAME" -C /target'
fi

echo "[$(date)] Restore completed successfully."
