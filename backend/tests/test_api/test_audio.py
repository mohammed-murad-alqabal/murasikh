import pytest
from app.api.v1.endpoints import audio

class FailingAudioAnalyzer:
    async def analyze_tone(self, file_bytes):
        raise Exception("Mocked internal error")

def test_audio_upload_handles_general_exceptions(client, monkeypatch):
    monkeypatch.setattr(audio, "audio_analyzer", FailingAudioAnalyzer())

    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("test.wav", b"dummy audio data", "audio/wav")},
    )

    assert response.status_code == 500
    assert "Mocked internal error" in response.json()["detail"]
