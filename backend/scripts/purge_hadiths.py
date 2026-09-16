"""Remove and verify hadith records from every local Chroma collection."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Any

import chromadb

BACKEND_DIR = Path(__file__).resolve().parents[1]
CHROMA_DIR = Path(os.environ.get("CHROMA_PATH", str(BACKEND_DIR / "chroma_db")))


def collection_name(collection: Any) -> str:
    return getattr(collection, "name", str(collection))


def hadith_ids(collection: Any) -> list[str]:
    result = collection.get(include=["metadatas"])
    return [
        record_id
        for record_id, metadata in zip(
            result.get("ids", []), result.get("metadatas", [])
        )
        if metadata and metadata.get("type") == "hadith"
    ]


def scan_hadiths(client: Any) -> dict[str, list[str]]:
    findings: dict[str, list[str]] = {}
    for collection in client.list_collections():
        ids = hadith_ids(collection)
        if ids:
            findings[collection_name(collection)] = ids
    return findings


def purge() -> int:
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    removed = 0
    for collection in client.list_collections():
        ids = hadith_ids(collection)
        if ids:
            collection.delete(ids=ids)
            removed += len(ids)
            print(f"Removed {len(ids)} hadith records from {collection_name(collection)}")

    remaining = scan_hadiths(client)
    if remaining:
        print(f"Hadith records remain: {remaining}", file=sys.stderr)
        return 1

    print(f"Quran-only Chroma verification passed; removed={removed}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Purge hadith records from local Chroma")
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify only; do not delete records",
    )
    args = parser.parse_args()

    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    if args.check:
        remaining = scan_hadiths(client)
        if remaining:
            print(f"Hadith records found: {remaining}", file=sys.stderr)
            return 1
        print("Quran-only Chroma verification passed")
        return 0

    return purge()


if __name__ == "__main__":
    sys.exit(main())
