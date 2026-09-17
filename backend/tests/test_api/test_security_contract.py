def test_cors_allows_configured_local_origin_and_rejects_unknown_origin(client):
    allowed = client.get(
        "/health",
        headers={"Origin": "http://localhost"},
    )
    rejected = client.get(
        "/health",
        headers={"Origin": "https://evil.example"},
    )

    assert allowed.status_code == 200
    assert allowed.headers.get("access-control-allow-origin") == "http://localhost"
    assert rejected.status_code == 200
    assert "access-control-allow-origin" not in rejected.headers


def test_invalid_jwt_cannot_access_private_history(client):
    response = client.get(
        "/api/v1/history",
        headers={"Authorization": "Bearer not-a-valid-token"},
    )

    assert response.status_code == 401


def test_audio_upload_rejects_unsupported_content_type(client):
    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("payload.txt", b"not audio", "text/plain")},
    )

    assert response.status_code == 415
    assert "Unsupported audio" in response.json()["detail"]


def test_audio_upload_rejects_empty_audio(client):
    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("empty.wav", b"", "audio/wav")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Audio file is empty"


def test_audio_upload_rejects_files_over_10_mb(client):
    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("large.wav", b"0" * (10 * 1024 * 1024 + 1), "audio/wav")},
    )

    assert response.status_code == 413
    assert "10 MB" in response.json()["detail"]
