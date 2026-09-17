from unittest.mock import MagicMock, patch

from app.services.ai.embeddings import EmbeddingService


# Use monkeypatch to mock database if needed, or we can just mock chromadb and sentencetransformer directly
@patch("app.services.ai.embeddings.chromadb")
@patch("app.services.ai.embeddings.SentenceTransformer")
def test_create_embedding_caching(mock_st, mock_chroma):
    mock_model = MagicMock()
    # Ensure it returns a mock array with a tolist method
    mock_array = MagicMock()
    mock_array.tolist.return_value = [0.1, 0.2, 0.3]
    mock_model.encode.return_value = mock_array

    mock_st.return_value = mock_model

    service = EmbeddingService()

    test_text = "بسم الله الرحمن الرحيم"

    # First call should miss the cache and call encode
    result1 = service.create_embedding(test_text)
    assert mock_model.encode.call_count == 1

    # Second call with the same text should hit the cache and NOT call encode
    result2 = service.create_embedding(test_text)
    assert mock_model.encode.call_count == 1

    # Results should be identical
    assert result1 == result2

    # Call with different text should miss the cache
    test_text_2 = "الحمد لله"
    service.create_embedding(test_text_2)
    assert mock_model.encode.call_count == 2
