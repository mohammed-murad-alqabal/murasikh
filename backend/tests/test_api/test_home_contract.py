from app.api.v1.endpoints import home


class FakeEmbedder:
    def search_similar(self, **kwargs):
        return {
            "documents": [["أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ"]],
            "metadatas": [[
                {
                    "type": "verse",
                    "source": "سورة الرعد: ٢٨",
                    "tafsir": "ذكر الله يورث الطمأنينة.",
                }
            ]],
            "ids": [["verse_13_28"]],
            "distances": [[0.1]],
        }


class FakeRagEngine:
    async def select_best_verse(self, user_text, emotion, verses):
        return verses[0]


def test_home_verse_contract(client, monkeypatch):
    monkeypatch.setattr(home, "embedder", FakeEmbedder())
    monkeypatch.setattr(home, "rag_engine", FakeRagEngine())

    response = client.post(
        "/api/v1/home/verse",
        json={
            "dominant_emotion": "قلق",
            "confidence": 0.8,
            "signal_source": "face",
            "time_of_day": "مساء",
        },
    )

    assert response.status_code == 200, response.text
    data = response.json()
    assert set(
        ("verse", "source", "emotion_context", "signal_used", "confidence", "cached")
    ).issubset(data)
    assert data["source"] == "سورة الرعد: ٢٨"
    assert data["emotion_context"] == "قلق"
    assert data["signal_used"] == "face"
    assert data["confidence"] == 0.8
    assert data["cached"] is False


def test_home_verse_openapi_contract(client):
    schema = client.get("/openapi.json").json()
    operation = schema["paths"]["/api/v1/home/verse"]["post"]
    response_schema = operation["responses"]["200"]["content"]["application/json"]["schema"]
    assert response_schema["$ref"].endswith("/VerseResponse")


def test_legacy_home_route_is_not_the_contract(client):
    response = client.post(
        "/api/v1/home",
        json={"dominant_emotion": "قلق", "confidence": 0.8},
    )
    assert response.status_code in (404, 405)
