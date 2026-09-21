#!/usr/bin/env bash
set -euo pipefail
umask 077

BACKUP_DIR=${BACKUP_DIR:-"/backups"}
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/db_backup_${TIMESTAMP}.sql.gz"
CHECKSUM_FILE="${BACKUP_FILE}.sha256"
RETENTION_DAYS=${RETENTION_DAYS:-7}

mkdir -p "$BACKUP_DIR"

echo "Starting database backup..."
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: POSTGRES_PASSWORD is not set."
    exit 1
fi

PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
    -h "${POSTGRES_SERVER:-db}" \
    -p "${POSTGRES_PORT:-5432}" \
    -U "${POSTGRES_USER:-murassikh}" \
    -d "${POSTGRES_DB:-murassikh_db}" \
    | gzip > "$BACKUP_FILE"
echo "Backup completed: $BACKUP_FILE"
sha256sum "$BACKUP_FILE" > "$CHECKSUM_FILE"

if [ -n "${CHROMA_PATH:-}" ] && [ -d "$CHROMA_PATH" ]; then
    tar -czf "${BACKUP_DIR}/chroma_${TIMESTAMP}.tar.gz" -C "$CHROMA_PATH" .
    sha256sum "${BACKUP_DIR}/chroma_${TIMESTAMP}.tar.gz" > "${BACKUP_DIR}/chroma_${TIMESTAMP}.tar.gz.sha256"
fi

echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type f \( -name "db_backup_*" -o -name "chroma_*" \) -mtime +"$RETENTION_DAYS" -delete
echo "Cleanup complete."
