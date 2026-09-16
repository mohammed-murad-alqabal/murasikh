from app.services.ai.embeddings import EmbeddingService


def _service_with_fingerprints(fingerprints):
    service = object.__new__(EmbeddingService)
    service.fingerprints = fingerprints
    return service


def _results(distances):
    return {
        "ids": [["verse_a", "verse_b"]],
        "distances": [distances],
        "documents": [["آية أ", "آية ب"]],
        "metadatas": [[{"type": "verse"}, {"type": "verse"}]],
    }


def test_emotion_weight_changes_ranking():
    service = _service_with_fingerprints(
        {
            "verse_a": {"dimensions": {"قلق": 0.0}},
            "verse_b": {"dimensions": {"قلق": 1.0}},
        }
    )

    result = service._rerank_results(_results([0.2, 0.8]), n_results=2, emotion="قلق")

    assert result["ids"][0] == ["verse_b", "verse_a"]


def test_zero_distances_produce_finite_deterministic_scores():
    service = _service_with_fingerprints(
        {
            "verse_a": {"dimensions": {"قلق": 0.4}},
            "verse_b": {"dimensions": {"قلق": 0.2}},
        }
    )

    result = service._rerank_results(_results([0.0, 0.0]), n_results=2, emotion="قلق")

    assert result["ids"][0] == ["verse_a", "verse_b"]
    assert result["distances"][0] == [0.0, 0.0]
