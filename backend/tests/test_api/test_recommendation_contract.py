from app.api.v1.endpoints import recommend


class FakeAgent:
    def __init__(self, analysis):
        self.analysis = analysis

    async def analyze(self, text, chat_history=None, user_context=None):
        return self.analysis


class FailingEmbedder:
    def search_similar(self, **kwargs):
        raise AssertionError("Chroma must not be queried for an ask response")


class FakeEmbedder:
    def search_similar(self, **kwargs):
        return {
            "documents": [["آية اختبارية"]],
            "metadatas": [
                [
                    {
                        "type": "verse",
                        "source": "سورة اختبارية: 1",
                        "tafsir": "تفسير اختباري",
                    }
                ]
            ],
            "ids": [["verse_test:1"]],
            "distances": [[0.1]],
        }


class FakeRagEngine:
    async def select_best_verse(self, user_text, emotion, verses):
        return verses[0]

    async def format_response(self, **kwargs):
        return "رد اختباري"


def test_guest_ask_response_skips_retrieval(client, monkeypatch):
    monkeypatch.setattr(
        recommend,
        "agent",
        FakeAgent(
            {
                "action": "ask",
                "emotion": "غير محدد",
                "confidence": 0.2,
                "ai_message": "ما أكثر ما يزعجك الآن؟",
            }
        ),
    )
    monkeypatch.setattr(recommend, "embedder", FailingEmbedder())

    response = client.post("/api/v1/analyze", json={"text": "أحتاج مساعدة"})

    assert response.status_code == 200, response.text
    assert response.json() == {
        "emotion": "غير محدد",
        "confidence": 0.2,
        "tier": "minimal",
        "message": "ما أكثر ما يزعجك الآن؟",
        "delayed_message": None,
        "source": None,
        "tafsir": None,
        "interaction_id": None,
    }


def test_guest_guide_response_has_stable_contract(client, monkeypatch):
    monkeypatch.setattr(
        recommend,
        "agent",
        FakeAgent(
            {
                "action": "guide",
                "emotion": "حزن",
                "confidence": 0.85,
                "ai_message": "أنت لست وحدك.",
            }
        ),
    )
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    response = client.post("/api/v1/analyze", json={"text": "أشعر بالحزن"})

    assert response.status_code == 200, response.text
    data = response.json()
    assert data["emotion"] == "حزن"
    assert data["confidence"] == 0.85
    assert data["message"].startswith("أنت لست وحدك.")
    assert data["source"] == "سورة اختبارية: 1"
    assert data["interaction_id"] is None


def test_recommendation_rejects_invalid_input(client):
    too_short = client.post("/api/v1/analyze", json={"text": "x"})
    too_long = client.post("/api/v1/analyze", json={"text": "x" * 1001})

    assert too_short.status_code == 422
    assert too_long.status_code == 422
