#!/bin/bash
# Backup PostgreSQL and the Chroma data volume for Murassikh.
# The caller must provide DB_CONTAINER and CHROMA_VOLUME for a complete backup.

set -euo pipefail

BACKUP_DIR=${BACKUP_DIR:-"/var/backups/murassikh"}
RETENTION_DAYS=${RETENTION_DAYS:-7}
DB_CONTAINER=${DB_CONTAINER:-"staging-postgres-1"}
CHROMA_VOLUME=${CHROMA_VOLUME:?CHROMA_VOLUME is required for a complete backup}
DB_USER=${POSTGRES_USER:-murassikh}
DB_NAME=${POSTGRES_DB:-murassikh_db}
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
DB_BACKUP_FILE="$BACKUP_DIR/murassikh_db_$TIMESTAMP.sql.gz"
CHROMA_BACKUP_FILE="$BACKUP_DIR/murassikh_chroma_$TIMESTAMP.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[$(date)] Starting PostgreSQL backup for $DB_NAME..."
docker exec -i "$DB_CONTAINER" pg_dump -U "$DB_USER" -d "$DB_NAME" -F c | gzip > "$DB_BACKUP_FILE"
sha256sum "$DB_BACKUP_FILE" > "$DB_BACKUP_FILE.sha256"

echo "[$(date)] Starting Chroma volume backup from $CHROMA_VOLUME..."
docker run --rm \
  -v "$CHROMA_VOLUME:/source:ro" \
  -v "$BACKUP_DIR:/backup" \
  alpine:3.20 \
  tar -czf "/backup/$(basename "$CHROMA_BACKUP_FILE")" -C /source .
sha256sum "$CHROMA_BACKUP_FILE" > "$CHROMA_BACKUP_FILE.sha256"

echo "[$(date)] Backups completed: $DB_BACKUP_FILE and $CHROMA_BACKUP_FILE"

echo "[$(date)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f -name "murassikh_*" -mtime +"$RETENTION_DAYS" -delete

echo "[$(date)] Cleanup finished."
