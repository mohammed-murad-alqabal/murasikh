import pytest
from app.services.ai.embeddings import EmbeddingService

def test_no_hadiths_in_collection():
    es = EmbeddingService()
    results = es.collection.get()
    
    if results and results.get("metadatas"):
        for meta in results["metadatas"]:
            if meta:
                assert meta.get("type", "") != "hadith", "Found hadith in vector DB! Strict Quran-only rule violated."
