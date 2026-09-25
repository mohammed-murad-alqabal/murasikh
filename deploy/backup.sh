#!/bin/bash
set -e

# Phase 5: RPO/RTO Backup Policy
# Encrypts and backs up PostgreSQL and ChromaDB

BACKUP_DIR="/tmp/murassikh_backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
DB_CONTAINER="murassikh-production-db-1"
CHROMA_DIR="./backend/chroma_db"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-default_secret_key_1234567890123}"

mkdir -p "$BACKUP_DIR"

echo "[Backup] Starting Postgres dump..."
docker exec $DB_CONTAINER pg_dump -U murassikh murassikh_db > "$BACKUP_DIR/db_$TIMESTAMP.sql"
echo "[Backup] Postgres dump completed."

echo "[Backup] Tarring Chroma DB..."
tar -czf "$BACKUP_DIR/chroma_$TIMESTAMP.tar.gz" -C "$CHROMA_DIR" .
echo "[Backup] Chroma tar completed."

echo "[Backup] Encrypting backups..."
openssl enc -aes-256-cbc -salt -in "$BACKUP_DIR/db_$TIMESTAMP.sql" -out "$BACKUP_DIR/db_$TIMESTAMP.sql.enc" -k "$ENCRYPTION_KEY" -pbkdf2
openssl enc -aes-256-cbc -salt -in "$BACKUP_DIR/chroma_$TIMESTAMP.tar.gz" -out "$BACKUP_DIR/chroma_$TIMESTAMP.tar.gz.enc" -k "$ENCRYPTION_KEY" -pbkdf2

# Remove unencrypted
rm "$BACKUP_DIR/db_$TIMESTAMP.sql"
rm "$BACKUP_DIR/chroma_$TIMESTAMP.tar.gz"

echo "[Backup] Backup completed and encrypted at $BACKUP_DIR"
