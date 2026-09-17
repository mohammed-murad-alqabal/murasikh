import pytest

from app.services.ai import rag_engine as rag_module
from app.services.ai.rag_engine import RAGEngine


@pytest.mark.asyncio
async def test_rag_falls_back_to_template_when_gemini_quota_fails(monkeypatch):
    monkeypatch.setattr(rag_module, "LOCAL_LLM_AVAILABLE", False)
    rag = object.__new__(RAGEngine)
    rag._gemini_available = True

    async def fail_with_quota(*args, **kwargs):
        raise RuntimeError("resource_exhausted: quota")

    rag._format_with_gemini = fail_with_quota

    response = await rag.format_response(
        user_text="أشعر بالقلق",
        emotion="قلق",
        retrieved_text="آية اختبارية",
        source="اختبار: 1",
        tafsir="تفسير اختباري",
    )

    assert "آية اختبارية" in response
    assert "اختبار: 1" in response
    assert rag._gemini_available is False
