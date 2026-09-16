import pytest
from app.services.ai.embeddings import EmbeddingService

def test_no_hadiths_in_collection():
    es = EmbeddingService()
    collections = es.client.list_collections()
    for collection in collections:
        results = collection.get(include=["metadatas"])
        for meta in results.get("metadatas") or []:
            if meta:
                assert meta.get("type", "") != "hadith", (
                    "Found hadith in vector DB! Strict Quran-only rule violated."
                )
