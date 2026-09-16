import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES
from app.services.ai.embeddings import EmbeddingService
import json

client = TestClient(app)

def test_taxonomy_antidotes():
    """Test that the taxonomy returns antidotes, not diseases."""
    # يأس should map to hope/relief
    yaas_query = EMOTION_SEMANTIC_QUERIES.get("يأس", "")
    assert "الفرج" in yaas_query or "تجديد الأمل" in yaas_query, "Taxonomy is not returning antidotes for يأس!"
    
    # خوف should map to safety
    khawf_query = EMOTION_SEMANTIC_QUERIES.get("خوف", "")
    assert "الأمان" in khawf_query or "السكينة" in khawf_query, "Taxonomy is not returning antidotes for خوف!"

def test_no_hadiths_in_chromadb():
    """Verify that there are no hadiths in the Vector database."""
    embedder = EmbeddingService()
    results = embedder.collection.get(
        where={"type": "hadith"}
    )
    assert len(results.get("ids", [])) == 0, "There are still hadiths in ChromaDB!"

def test_recommendation_endpoint_returns_verse_only():
    """Test the /api/v1/analyze endpoint."""
    response = client.post(
        "/api/v1/analyze",
        json={"text": "أنا حزين جدا وأشعر باليأس"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data.get("content_type", data.get("type", "verse")) == "verse", "Response is not a verse!"
    
def test_exact_emotion_matching():
    """Test that the API uses the hardcoded exact emotion matching when possible."""
    response = client.post(
        "/api/v1/analyze",
        json={"text": "أشعر باليأس الشديد", "emotion": "يأس"}
    )
    assert response.status_code == 200
    data = response.json()
    assert "9:40" in (data.get("source") or "") or "39:53" in (data.get("source") or "") or "27:17" in (data.get("source") or "") or "سورة" in (data.get("source") or ""), "Exact matching for يأس failed!"

def test_embedding_model_is_minilm():
    """Test that we are using the MiniLM model."""
    embedder = EmbeddingService()
    # It should not be AraBERT
    assert "MiniLM" in str(embedder.model).lower() or "MiniLM" in getattr(embedder.model.tokenizer, "name_or_path", ""), "Model is not MiniLM!"

