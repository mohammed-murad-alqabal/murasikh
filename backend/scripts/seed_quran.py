"""Seed and verify the Quran-only Chroma collection.

The script is intentionally idempotent: once the collection contains the
validated 6,236 Quran verses, a normal run performs only verification and does
not load the embedding model again.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any

import chromadb

SCRIPT_DIR = Path(__file__).resolve().parent
BACKEND_DIR = SCRIPT_DIR.parent
QURAN_FILE = BACKEND_DIR / "quran.json"
CHROMA_DIR = Path(os.environ.get("CHROMA_PATH", str(BACKEND_DIR / "chroma_db")))
COLLECTION_NAME = "islamic_content_minilm"
ALLOWED_COLLECTIONS = {COLLECTION_NAME}
EXPECTED_VERSE_COUNT = 6236
INDEX_VERSION = "quran-v1"
MODEL_NAME = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"

# A small curated set of context hints. The Quran remains the only stored
# content; these fields are optional metadata used by the hybrid reranker.
EMOTION_MAPPING: dict[str, dict[str, str]] = {
    "3:134": {
        "emotion": "غضب",
        "tafsir": "الذين يمسكون ما في أنفسهم من الغضب، ويعفون عمن أساء إليهم.",
    },
    "2:155": {
        "emotion": "حزن",
        "tafsir": "بشارة عظيمة لمن يصبر على الحزن والمصيبة محتسباً الأجر من الله.",
    },
    "2:156": {
        "emotion": "حزن",
        "tafsir": "بشارة عظيمة لمن يصبر على الحزن والمصيبة محتسباً الأجر من الله.",
    },
    "13:28": {
        "emotion": "قلق",
        "tafsir": "القلوب تسكن وتستريح بذكر الله والتوكل عليه في أوقات التوتر والقلق.",
    },
    "9:40": {
        "emotion": "يأس",
        "tafsir": "لا تيأس ولا تحزن، فإن الله يحفظنا ويرعانا في أشد الأوقات ضيقاً.",
    },
    "94:5": {"emotion": "توتر", "tafsir": "فإن مع الشدة والضيق يسرًا وفرجًا."},
    "94:6": {"emotion": "توتر", "tafsir": "إن مع الشدة والضيق يسرًا وفرجًا."},
    "2:286": {"emotion": "إرهاق", "tafsir": "لا يكلف الله نفساً إلا وسعها."},
    "39:53": {
        "emotion": "ذنب",
        "tafsir": "لا تقنطوا من رحمة الله إن الله يغفر الذنوب جميعاً.",
    },
    "14:7": {"emotion": "شكر", "tafsir": "لئن شكرتم لأزيدنكم."},
    "20:46": {"emotion": "خوف", "tafsir": "لا تخافا إنني معكما أسمع وأرى."},
    "65:3": {"emotion": "حيرة", "tafsir": "ومن يتوكل على الله فهو حسبه."},
}


def load_verses() -> list[dict[str, Any]]:
    with QURAN_FILE.open("r", encoding="utf-8") as handle:
        data = json.load(handle)

    verses: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for chapter_key, chapter_verses in data.items():
        if not isinstance(chapter_verses, list):
            raise TypeError(f"Chapter {chapter_key} is not a list")
        for verse in chapter_verses:
            chapter = int(verse["chapter"])
            number = int(verse["verse"])
            text = str(verse["text"]).strip()
            if not text:
                raise ValueError(f"Empty Quran text at {chapter}:{number}")
            verse_id = f"verse_{chapter}:{number}"
            if verse_id in seen_ids:
                raise ValueError(f"Duplicate Quran id: {verse_id}")
            seen_ids.add(verse_id)
            metadata: dict[str, Any] = {
                "type": "verse",
                "source": f"سورة رقم {chapter} : آية {number}",
                "chapter": chapter,
                "verse": number,
            }
            metadata.update(EMOTION_MAPPING.get(f"{chapter}:{number}", {}))
            verses.append({"id": verse_id, "text": text, "metadata": metadata})

    if len(verses) != EXPECTED_VERSE_COUNT:
        raise ValueError(
            f"Expected {EXPECTED_VERSE_COUNT} Quran verses, found {len(verses)}"
        )
    return verses


def get_collection(client):
    return client.get_or_create_collection(
        name=COLLECTION_NAME,
        metadata={
            "description": "القرآن الكريم فقط",
            "hnsw:space": "cosine",
            "index_version": INDEX_VERSION,
        },
    )


def dataset_checksum(verses: list[dict[str, Any]]) -> str:
    payload = "\n".join(f"{verse['id']}\t{verse['text']}" for verse in verses)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def verify_collection(collection, verses: list[dict[str, Any]]) -> None:
    metadata = getattr(collection, "metadata", None) or {}
    expected_checksum = dataset_checksum(verses)
    if metadata and (
        metadata.get("index_version") != INDEX_VERSION
        or metadata.get("dataset_checksum") != expected_checksum
    ):
        raise RuntimeError("Chroma index metadata does not match the Quran artifact")
    if collection.count() != EXPECTED_VERSE_COUNT:
        raise RuntimeError(
            f"Chroma collection has {collection.count()} records; expected {EXPECTED_VERSE_COUNT}."
        )

    result = collection.get(include=["metadatas"])
    ids = set(result.get("ids", []))
    expected_ids = {verse["id"] for verse in verses}
    if ids != expected_ids:
        missing = sorted(expected_ids - ids)[:5]
        unexpected = sorted(ids - expected_ids)[:5]
        raise RuntimeError(
            f"Chroma IDs do not match Quran dataset. missing={missing}, unexpected={unexpected}"
        )

    for metadata in result.get("metadatas", []):
        if not metadata or metadata.get("type") != "verse":
            raise RuntimeError(
                "Chroma contains a non-verse record in the Quran collection"
            )


def verify_quran_only_collections(client) -> None:
    """Fail closed if a production Chroma path contains another collection."""
    collections = client.list_collections()
    names = {
        getattr(collection, "name", str(collection)) for collection in collections
    }
    unexpected = sorted(names - ALLOWED_COLLECTIONS)
    if unexpected:
        raise RuntimeError(
            "Quran-only verification found unexpected Chroma collections: "
            f"{unexpected}"
        )


def seed_quran(*, reset: bool = False, batch_size: int = 128) -> None:
    verses = load_verses()
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    verify_quran_only_collections(client)

    if reset:
        try:
            client.delete_collection(COLLECTION_NAME)
        except Exception:
            pass

    collection = get_collection(client)
    if not reset and collection.count() == EXPECTED_VERSE_COUNT:
        try:
            verify_collection(collection, verses)
            print(f"Quran collection already verified: {EXPECTED_VERSE_COUNT} verses")
            return
        except RuntimeError:
            print("Existing collection failed verification; rebuilding it")

    if collection.count() != 0 or reset:
        client.delete_collection(COLLECTION_NAME)
        collection = get_collection(client)

    # Import the model only when actual seeding is required. This keeps the
    # verification path lightweight and avoids downloading a model unnecessarily.
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer(MODEL_NAME)
    for start in range(0, len(verses), batch_size):
        batch = verses[start : start + batch_size]
        embeddings = model.encode(
            [item["text"] for item in batch],
            show_progress_bar=False,
        ).tolist()
        collection.upsert(
            ids=[item["id"] for item in batch],
            embeddings=embeddings,
            documents=[item["text"] for item in batch],
            metadatas=[item["metadata"] for item in batch],
        )
        print(f"Seeded {min(start + batch_size, len(verses))}/{len(verses)} verses")

    if hasattr(collection, "modify"):
        collection.modify(
            metadata={
                "description": "القرآن الكريم فقط",
                "hnsw:space": "cosine",
                "index_version": INDEX_VERSION,
                "dataset_checksum": dataset_checksum(verses),
            }
        )

    verify_collection(collection, verses)
    print(f"Quran collection seeded and verified: {EXPECTED_VERSE_COUNT} verses")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Seed or verify the Quran-only Chroma collection"
    )
    parser.add_argument(
        "--verify",
        action="store_true",
        help="verify without loading the embedding model",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="replace the target collection before seeding",
    )
    parser.add_argument("--batch-size", type=int, default=128)
    args = parser.parse_args()

    if args.batch_size <= 0:
        parser.error("--batch-size must be positive")

    verses = load_verses()
    client = chromadb.PersistentClient(path=str(CHROMA_DIR))
    verify_quran_only_collections(client)
    collection = get_collection(client)
    if args.verify:
        verify_collection(collection, verses)
        print(f"Quran collection verified: {EXPECTED_VERSE_COUNT} verses")
    else:
        seed_quran(reset=args.reset, batch_size=args.batch_size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
