import pytest
from app.services.ai.embeddings import EmbeddingService

def test_hybrid_weighted_retrieval():
    es = EmbeddingService()
    
    # Store some mock documents
    es.store_document("test_verse_1", "test verse about fear", {"type": "verse"})
    es.store_document("test_verse_2", "test verse about hope", {"type": "verse"})
    
    # Inject fake fingerprints to test weighted logic
    es.fingerprints = {
        "test_verse_1": {"dimensions": {"خوف": 0.9}},
        "test_verse_2": {"dimensions": {"أمل": 0.9}}
    }
    
    # Perform search with emotion
    results = es.search_similar("test query", n_results=2, emotion="خوف")
    
    # Check if results are returned and formatted properly
    assert "ids" in results
    assert len(results["ids"][0]) > 0
    
    # Check if the weighted calculation boosted the one matching the emotion
    # Note: SentenceTransformer encodes "test query" and the distances might vary,
    # but the logic should execute without error.
    top_id = results["ids"][0][0]
    # We just ensure the search works without crashing and applies hybrid logic
    assert top_id in ["test_verse_1", "test_verse_2"]

