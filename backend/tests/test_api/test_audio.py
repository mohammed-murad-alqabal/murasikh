from app.api.v1.endpoints import audio


class FailingAudioAnalyzer:
    async def analyze_tone(self, file_bytes):
        raise RuntimeError("Internal Server Error")


def test_audio_upload_handles_general_exceptions(client, monkeypatch):
    monkeypatch.setattr(audio, "audio_analyzer", FailingAudioAnalyzer())

    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("test.wav", b"RIFF\x24\x00\x00\x00WAVEfmt ", "audio/wav")},
    )

    assert response.status_code == 500
    assert "Internal Server Error" in response.json()["detail"]

def test_audio_upload_invalid_json_context(client):
    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("test.wav", b"RIFF\x24\x00\x00\x00WAVEfmt ", "audio/wav")},
        data={"user_context": "{invalid_json}"},
    )

    assert response.status_code == 400
    assert "Invalid JSON in user_context" in response.json()["detail"]
