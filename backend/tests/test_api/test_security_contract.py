import uuid

import jwt
import pytest
from app.core.auth import SECRET_KEY
from app.core.config import Settings
from app.db.models import User
from app.services.user_manager import UserManager


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


@pytest.mark.parametrize("is_active,is_deleted", [(False, False), (True, True)])
def test_inactive_or_deleted_accounts_cannot_login(
    client, db_session, is_active, is_deleted
):
    suffix = uuid.uuid4().hex[:10]
    username = f"blocked_{suffix}"
    db_session.add(
        User(
            username=username,
            email=f"{username}@example.com",
            password_hash=UserManager().get_password_hash("password"),
            is_active=is_active,
            is_deleted=is_deleted,
        )
    )
    db_session.commit()

    response = client.post(
        "/api/v1/auth/login",
        data={"username": username, "password": "password"},
    )

    assert response.status_code == 401


def test_jwt_signed_with_wrong_secret_cannot_access_private_route(client):
    wrong_secret = "wrong-secret-for-test-0123456789abcdef-0123456789abcdef-xyz"
    token = jwt.encode({"sub": "testuser"}, wrong_secret, algorithm="HS512")
    response = client.get(
        "/api/v1/history",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
    assert SECRET_KEY != wrong_secret


def test_production_settings_reject_default_secret():
    with pytest.raises(ValueError, match="SECRET_KEY"):
        Settings(
            ENVIRONMENT="production",
            SECRET_KEY="super-secret-key-change-in-production",
        )


def test_cors_origins_are_parsed_from_configuration():
    settings = Settings(CORS_ORIGINS="https://app.example, https://admin.example")

    assert settings.cors_origins == [
        "https://app.example",
        "https://admin.example",
    ]


def test_audio_upload_rejects_malformed_user_context(client):
    response = client.post(
        "/api/v1/audio/analyze-audio",
        files={"file": ("test.wav", b"RIFF\x24\x00\x00\x00WAVEfmt ", "audio/wav")},
        data={"user_context": "{malformed_json: true"},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Invalid JSON in user_context"
