import uuid

from app.api.v1.endpoints import recommend
from app.db.models import DelayedResponse, Interaction


class FakeAgent:
    def __init__(self, analysis=None):
        self.analysis = analysis or {
            "action": "guide",
            "emotion": "حزن",
            "confidence": 0.9,
            "ai_message": "رسالة اختبارية من الوكيل.",
        }

    async def analyze(self, text, chat_history=None, user_context=None):
        return self.analysis


class FakeEmbedder:
    def search_similar(self, **kwargs):
        return {
            "documents": [["وَبَشِّرِ الصَّابِرِينَ"]],
            "metadatas": [
                [
                    {
                        "type": "verse",
                        "source": "سورة البقرة: ١٥٥",
                        "tafsir": "تفسير الآية.",
                    }
                ]
            ],
            "ids": [["test_verse_1"]],
            "distances": [[0.1]],
        }


class FakeRagEngine:
    async def select_best_verse(self, user_text, emotion, verses):
        return verses[0]

    async def format_response(self, **kwargs):
        return "رسالة مهيأة من RAG"


class RecordingAskAgent:
    def __init__(self):
        self.chat_history = None

    async def analyze(self, text, chat_history=None, user_context=None):
        self.chat_history = chat_history
        return {
            "action": "ask",
            "emotion": "حيرة",
            "confidence": 0.4,
            "ai_message": "هل يمكنك توضيح الموقف أكثر؟",
        }


class RecordingContextAgent:
    def __init__(self):
        self.contexts = []

    async def analyze(self, text, chat_history=None, user_context=None):
        self.contexts.append(user_context)
        return {
            "action": "ask",
            "emotion": "حيرة",
            "confidence": 0.4,
            "ai_message": "هل يمكنك توضيح الموقف أكثر؟",
        }


def _register_and_login(client):
    suffix = uuid.uuid4().hex[:10]
    credentials = {
        "username": f"user_{suffix}",
        "password": "test-password",
        "email": f"{suffix}@example.com",
    }
    register = client.post("/api/v1/auth/register", json=credentials)
    assert register.status_code == 200, register.text

    # get user_id from db or just use token.
    # The register endpoint doesn't return user_id, only token.
    return register.json()["access_token"], credentials["username"]


def _headers(token):
    return {"Authorization": f"Bearer {token}"}


def test_authenticated_recommendation_saves_history(client, monkeypatch, db_session):
    monkeypatch.setattr(recommend, "agent", FakeAgent())
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    token, _username = _register_and_login(client)

    payload = {"text": "أشعر بالحزن والضيق"}
    response = client.post(
        "/api/v1/analyze",
        json=payload,
        headers=_headers(token),
    )

    assert response.status_code == 200, response.text
    data = response.json()

    assert data["emotion"] == "حزن"
    assert data["confidence"] == 0.9
    assert data["interaction_id"] is not None

    # Verify database state
    interaction = (
        db_session.query(Interaction)
        .filter(Interaction.id == data["interaction_id"])
        .first()
    )
    assert interaction is not None
    assert interaction.query_text == "أشعر بالحزن والضيق"
    assert interaction.detected_emotion == "حزن"
    assert interaction.source == "سورة البقرة: ١٥٥"


def test_extreme_emotion_creates_delayed_response(client, monkeypatch, db_session):
    # Setup agent to return extreme emotion "غضب" (anger) with high confidence.
    monkeypatch.setattr(
        recommend,
        "agent",
        FakeAgent(
            {
                "action": "guide",
                "emotion": "غضب",
                "confidence": 0.95,
                "ai_message": "تعوذ بالله من الشيطان.",
            }
        ),
    )
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    token, _username = _register_and_login(client)

    payload = {"text": "أنا غاضب جداً!"}
    response = client.post(
        "/api/v1/analyze",
        json=payload,
        headers=_headers(token),
    )

    assert response.status_code == 200, response.text
    data = response.json()

    assert data["emotion"] == "غضب"
    assert data["tier"] == "minimal"
    assert data["interaction_id"] is not None

    # We should have a delayed response scheduled
    interaction_id = data["interaction_id"]
    delayed_response = (
        db_session.query(DelayedResponse)
        .filter(DelayedResponse.interaction_id == interaction_id)
        .first()
    )

    assert delayed_response is not None
    assert delayed_response.is_delivered is False
    assert delayed_response.payload["emotion"] == "غضب"
    assert "تعوذ بالله من الشيطان الرجيم" in data["message"]


def test_unauthenticated_recommendation_does_not_save_history(
    client, monkeypatch, db_session
):
    monkeypatch.setattr(recommend, "agent", FakeAgent())
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    # Count interactions before request
    initial_count = db_session.query(Interaction).count()

    payload = {"text": "أشعر بالحزن"}
    response = client.post(
        "/api/v1/analyze",
        json=payload,
        # No Authorization header
    )

    assert response.status_code == 200, response.text
    data = response.json()

    assert data["emotion"] == "حزن"
    assert data["interaction_id"] is None

    # Count interactions after request
    final_count = db_session.query(Interaction).count()
    assert initial_count == final_count, (
        "No new interaction should be saved for unauthenticated user"
    )


def test_guest_chat_history_is_bounded_and_passed_to_agent(client, monkeypatch):
    agent = RecordingAskAgent()
    monkeypatch.setattr(recommend, "agent", agent)

    response = client.post(
        "/api/v1/analyze",
        json={
            "text": "أحتاج توضيحاً",
            "chat_history": [
                {"role": "user", "content": "أشعر بالتعب"},
                {"role": "assistant", "content": "هل هو تعب جسدي أم نفسي؟"},
            ],
        },
    )

    assert response.status_code == 200, response.text
    assert agent.chat_history == [
        {"role": "user", "content": "أشعر بالتعب"},
        {"role": "assistant", "content": "هل هو تعب جسدي أم نفسي؟"},
    ]


def test_chat_history_contract_rejects_more_than_ten_messages(client, monkeypatch):
    monkeypatch.setattr(recommend, "agent", RecordingAskAgent())
    response = client.post(
        "/api/v1/analyze",
        json={
            "text": "رسالة",
            "chat_history": [
                {"role": "user", "content": str(index)} for index in range(11)
            ],
        },
    )
    assert response.status_code == 422


def test_sensitive_context_requires_explicit_consent(client, monkeypatch):
    agent = RecordingContextAgent()
    monkeypatch.setattr(recommend, "agent", agent)

    without_consent = client.post(
        "/api/v1/analyze",
        json={
            "text": "أشعر بالتوتر",
            "user_context": {
                "age": 30,
                "gender": "male",
                "facial_emotion": "قلق",
                "biometric_stress": True,
            },
        },
    )
    assert without_consent.status_code == 200
    assert agent.contexts[-1] == {}

    with_consent = client.post(
        "/api/v1/analyze",
        json={
            "text": "أشعر بالتوتر",
            "user_context": {
                "age": 30,
                "gender": "male",
                "facial_emotion": "قلق",
                "biometric_stress": True,
                "sensitive_context_consent": True,
            },
        },
    )
    assert with_consent.status_code == 200
    assert agent.contexts[-1] == {
        "age": 30,
        "gender": "male",
        "facial_emotion": "قلق",
        "biometric_stress": True,
    }


def test_ask_persists_actual_confidence_and_tier(client, monkeypatch, db_session):
    token, _username = _register_and_login(client)
    monkeypatch.setattr(recommend, "agent", RecordingAskAgent())

    response = client.post(
        "/api/v1/analyze",
        json={"text": "أحتاج توضيحاً"},
        headers=_headers(token),
    )

    assert response.status_code == 200, response.text
    interaction = (
        db_session.query(Interaction)
        .filter(Interaction.id == response.json()["interaction_id"])
        .first()
    )
    assert interaction is not None
    assert interaction.emotion_confidence == 0.4
    assert interaction.response_tier == "minimal"


def test_recommendation_injects_user_context(client, monkeypatch, db_session):
    # We want to verify that history context actually gets injected and processed without errors.

    # Mock services
    monkeypatch.setattr(recommend, "agent", FakeAgent())
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    token, _username = _register_and_login(client)

    # First interaction to seed history
    payload1 = {"text": "أشعر بالحزن"}
    response1 = client.post("/api/v1/analyze", json=payload1, headers=_headers(token))
    interaction_id = response1.json()["interaction_id"]

    # User provides positive feedback to generate context
    feedback_response = client.post(
        "/api/v1/history/feedback",
        json={"id": interaction_id, "feedback": 1},
        headers=_headers(token),
    )
    assert feedback_response.status_code == 200

    # Second interaction should now utilize the context string successfully
    payload2 = {
        "text": "أشعر بالضيق مرة أخرى",
        "user_context": {"age": 25, "gender": "male"},
    }
    response2 = client.post("/api/v1/analyze", json=payload2, headers=_headers(token))

    assert response2.status_code == 200, response2.text
    data2 = response2.json()
    assert data2["emotion"] == "حزن"  # from FakeAgent
    assert data2["interaction_id"] is not None
