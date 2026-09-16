import uuid

from app.api.v1.endpoints import recommend


class FakeAgent:
    async def analyze(self, text, chat_history=None, user_context=None):
        return {
            "action": "guide",
            "emotion": "وحدة",
            "confidence": 0.9,
            "ai_message": "رسالة اختبارية.",
        }


class FakeEmbedder:
    def search_similar(self, **kwargs):
        return {
            "documents": [["وَبَشِّرِ الصَّابِرِينَ"]],
            "metadatas": [[
                {
                    "type": "verse",
                    "source": "سورة البقرة: ١٥٥",
                    "tafsir": "اختبار عزل السجل.",
                }
            ]],
            "ids": [["test_isolation_verse"]],
            "distances": [[0.1]],
        }


class FakeRagEngine:
    async def select_best_verse(self, user_text, emotion, verses):
        return verses[0]


def _register_and_login(client):
    suffix = uuid.uuid4().hex[:10]
    credentials = {
        "username": f"user_{suffix}",
        "password": "test-password",
        "email": f"{suffix}@example.com",
    }
    register = client.post("/api/v1/auth/register", json=credentials)
    assert register.status_code == 200, register.text
    return register.json()["access_token"]


def _headers(token):
    return {"Authorization": f"Bearer {token}"}


def test_users_cannot_read_or_mutate_each_others_history(client, monkeypatch):
    monkeypatch.setattr(recommend, "agent", FakeAgent())
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    token_a = _register_and_login(client)
    token_b = _register_and_login(client)

    record = client.post(
        "/api/v1/analyze",
        json={"text": "أشعر بالوحدة"},
        headers=_headers(token_a),
    )
    assert record.status_code == 200, record.text
    interaction_id = record.json().get("interaction_id")
    assert isinstance(interaction_id, int)

    history_a = client.get("/api/v1/history", headers=_headers(token_a))
    history_b = client.get("/api/v1/history", headers=_headers(token_b))
    assert history_a.status_code == 200
    assert history_b.status_code == 200
    assert len(history_a.json()) >= 1
    assert history_b.json() == []

    record_id = str(history_a.json()[0]["id"])
    assert record_id == str(interaction_id)
    update_by_owner = client.post(
        "/api/v1/history/feedback",
        json={"id": record_id, "feedback": 1},
        headers=_headers(token_a),
    )
    assert update_by_owner.status_code == 200

    update = client.post(
        "/api/v1/history/feedback",
        json={"id": record_id, "feedback": 1},
        headers=_headers(token_b),
    )
    assert update.status_code == 404

    clear = client.delete("/api/v1/history", headers=_headers(token_b))
    assert clear.status_code == 200
    assert client.get("/api/v1/history", headers=_headers(token_a)).json()


def test_history_requires_authentication(client):
    response = client.get("/api/v1/history")
    assert response.status_code == 401
