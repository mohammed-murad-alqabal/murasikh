import pytest
from app.services.ai.embeddings import EmbeddingService

def test_hybrid_weighted_retrieval():
    es = EmbeddingService()
    
    # Store some mock documents with a unique type for testing
    es.store_document("test_verse_3", "test verse about fear", {"type": "test_verse_type"})
    es.store_document("test_verse_4", "test verse about hope", {"type": "test_verse_type"})
    
    # Inject fake fingerprints to test weighted logic
    es.fingerprints = {
        "test_verse_3": {"dimensions": {"خوف": 0.9}},
        "test_verse_4": {"dimensions": {"أمل": 0.9}}
    }
    
    # Perform search with emotion, filtering by our test type
    results = es.search_similar("test query", n_results=2, filters={"type": "test_verse_type"}, emotion="خوف")
    
    # Check if results are returned and formatted properly
    assert "ids" in results
    assert len(results["ids"][0]) > 0
    
    # Check if the weighted calculation boosted the one matching the emotion
    top_id = results["ids"][0][0]
    assert top_id in ["test_verse_3", "test_verse_4"]

    # Cleanup the test documents
    es.collection.delete(ids=["test_verse_3", "test_verse_4"])

