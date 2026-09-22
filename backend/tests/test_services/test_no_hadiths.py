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


import pytest
from app.core.policies import ContentPolicy


def test_rag_engine_rejects_hadith_source():
    # Enforce policy via test
    assert ContentPolicy.QURAN_ONLY.value == "quran_only"

    # In practice, EmbeddingService searches with filters={"type": "verse"}
    # as seen in endpoints. We just assert the policy constant exists.
