import time

import pytest

from app.services.ai import rag_engine as rag_module
from app.services.ai.embeddings import EmbeddingService
from app.services.ai.rag_engine import RAGEngine


class FakeEmbeddingModel:
    def encode(self, text):
        return [float(len(text) % 7)] * 8


class FakeCollection:
    def __init__(self, count=50):
        self.count = count

    def query(self, query_embeddings, n_results, where=None):
        count = min(n_results, self.count)
        ids = [f"verse:{index}" for index in range(count)]
        distances = [0.1 + (index * 0.01) for index in range(count)]
        return {
            "ids": [ids],
            "distances": [distances],
            "documents": [[f"آية اختبارية رقم {index}" for index in range(count)]],
            "metadatas": [[{"type": "verse", "source": f"اختبار:{index}"} for index in range(count)]],
        }


def fake_embedding_service():
    service = object.__new__(EmbeddingService)
    service.model = FakeEmbeddingModel()
    service.collection = FakeCollection()
    service.fingerprints = {
        "verse:49": {"dimensions": {"حزن": 1.0}},
    }
    return service


def p95_ms(samples):
    ordered = sorted(samples)
    index = max(0, int(len(ordered) * 0.95) - 1)
    return ordered[index] * 1000


@pytest.mark.performance
def test_hybrid_reranking_p95_under_budget():
    service = fake_embedding_service()
    results = service.collection.query([[]], 50)
    samples = []

    for _ in range(120):
        started = time.perf_counter()
        ranked = service._rerank_results(results, n_results=5, emotion="حزن")
        samples.append(time.perf_counter() - started)

    assert ranked["ids"][0][0] == "verse:49"
    assert p95_ms(samples) < 20, f"hybrid reranking p95={p95_ms(samples):.2f}ms"


@pytest.mark.performance
def test_semantic_search_orchestration_p95_under_budget():
    service = fake_embedding_service()
    samples = []

    for _ in range(120):
        started = time.perf_counter()
        result = service.search_similar(
            "أشعر بالحزن وأحتاج إلى السكينة",
            n_results=5,
            filters={"type": "verse"},
            emotion="حزن",
        )
        samples.append(time.perf_counter() - started)

    assert len(result["ids"][0]) == 5
    assert p95_ms(samples) < 20, f"semantic search p95={p95_ms(samples):.2f}ms"


@pytest.mark.performance
@pytest.mark.asyncio
async def test_rag_local_selection_p95_under_budget():
    rag = object.__new__(RAGEngine)
    rag._gemini_available = False
    verses = [
        {"text": "وَبَشِّرِ الصَّابِرِينَ", "source": "البقرة: 155", "tafsir": "اختبار"},
        {"text": "إِنَّ مَعَ الْعُسْرِ يُسْرًا", "source": "الشرح: 6", "tafsir": "اختبار"},
        {"text": "نص يتضمن عذاباً", "source": "اختبار: 3", "tafsir": "اختبار"},
    ] * 4
    samples = []

    for _ in range(120):
        started = time.perf_counter()
        selected = await rag.select_best_verse("أشعر بالحزن", "حزن", verses)
        samples.append(time.perf_counter() - started)

    assert selected["source"] in {"البقرة: 155", "الشرح: 6"}
    assert p95_ms(samples) < 20, f"RAG selection p95={p95_ms(samples):.2f}ms"


@pytest.mark.performance
@pytest.mark.asyncio
async def test_rag_template_fallback_p95_under_budget(monkeypatch):
    monkeypatch.setattr(rag_module, "LOCAL_LLM_AVAILABLE", False)
    rag = object.__new__(RAGEngine)
    rag._gemini_available = False
    samples = []

    for _ in range(120):
        started = time.perf_counter()
        response = await rag.format_response(
            user_text="أشعر بالقلق",
            emotion="قلق",
            retrieved_text="آية اختبارية",
            source="اختبار: 1",
            tafsir="تفسير اختباري",
        )
        samples.append(time.perf_counter() - started)

    assert "آية اختبارية" in response
    assert "اختبار: 1" in response
    assert p95_ms(samples) < 20, f"RAG template p95={p95_ms(samples):.2f}ms"
