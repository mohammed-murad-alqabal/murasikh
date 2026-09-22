#!/bin/bash
set -e

echo "Running database migrations..."
alembic upgrade head

echo "Verifying Quran Chroma index..."
python -m scripts.seed_quran --verify

echo "Starting server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
