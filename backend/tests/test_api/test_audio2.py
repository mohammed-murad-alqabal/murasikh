import pytest
from fastapi.testclient import TestClient
from app.main import app
import tempfile

client = TestClient(app)

def test_audio_invalid_magic_bytes():
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        f.write(b"this is just a normal text file pretending to be audio")
        f.seek(0)

        files = {"file": ("test.wav", f, "audio/wav")}

        response = client.post("/api/v1/audio/analyze-audio", files=files)
        assert response.status_code == 415
        assert "Invalid audio file format" in response.text

def test_audio_valid_magic_bytes():
    with tempfile.NamedTemporaryFile(suffix=".wav") as f:
        f.write(b"RIFF\x24\x00\x00\x00WAVEfmt ")
        f.seek(0)

        files = {"file": ("test.wav", f, "audio/wav")}

        response = client.post("/api/v1/audio/analyze-audio", files=files)
        assert response.status_code != 415
