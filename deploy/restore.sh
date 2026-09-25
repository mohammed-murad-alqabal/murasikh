#!/bin/bash
set -e

# Phase 5: RPO/RTO Restore Drill
# Restores PostgreSQL and ChromaDB from encrypted backups

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <db_backup_enc_file> <chroma_backup_enc_file>"
    exit 1
fi

DB_ENC=$1
CHROMA_ENC=$2
DB_CONTAINER="murassikh-production-db-1"
CHROMA_DIR="./backend/chroma_db"
ENCRYPTION_KEY="${BACKUP_ENCRYPTION_KEY:-default_secret_key_1234567890123}"

echo "[Restore] Decrypting database..."
openssl enc -d -aes-256-cbc -in "$DB_ENC" -out "/tmp/db_restore.sql" -k "$ENCRYPTION_KEY" -pbkdf2

echo "[Restore] Decrypting Chroma..."
openssl enc -d -aes-256-cbc -in "$CHROMA_ENC" -out "/tmp/chroma_restore.tar.gz" -k "$ENCRYPTION_KEY" -pbkdf2

echo "[Restore] Restoring Database..."
docker exec -i $DB_CONTAINER psql -U murassikh -d murassikh_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
cat /tmp/db_restore.sql | docker exec -i $DB_CONTAINER psql -U murassikh -d murassikh_db
echo "[Restore] Database restored."

echo "[Restore] Restoring Chroma..."
rm -rf "$CHROMA_DIR"/*
tar -xzf "/tmp/chroma_restore.tar.gz" -C "$CHROMA_DIR"
echo "[Restore] Chroma restored."

# Cleanup
rm /tmp/db_restore.sql
rm /tmp/chroma_restore.tar.gz

echo "[Restore] Restore completed successfully."
