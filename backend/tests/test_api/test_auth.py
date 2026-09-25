import uuid
from datetime import timedelta

from app.core.auth import create_access_token
from app.db.models import DelayedResponse, Interaction, User


def test_register_user(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "username": "testuser",
            "password": "testpassword",
            "email": "test@example.com",
        },
    )
    assert response.status_code == 200
    assert "access_token" in response.json()
    assert "refresh_token" in response.json()
    assert response.json()["token_type"] == "bearer"


def test_register_existing_user(client):
    response = client.post(
        "/api/v1/auth/register",
        json={
            "username": "testuser",
            "password": "testpassword",
            "email": "test@example.com",
        },
    )
    assert response.status_code == 400
    assert "already exists" in response.json()["detail"]


def test_login_user(client):
    response = client.post(
        "/api/v1/auth/login", data={"username": "testuser", "password": "testpassword"}
    )
    assert response.status_code == 200
    assert "access_token" in response.json()
    assert "refresh_token" in response.json()


def test_login_wrong_password(client):
    response = client.post(
        "/api/v1/auth/login", data={"username": "testuser", "password": "wrongpassword"}
    )
    assert response.status_code == 401
    assert "Incorrect username or password" in response.json()["detail"]


def test_history_guest_access(client):
    # Route is now protected, guest should get 401
    response = client.get("/api/v1/history")
    assert response.status_code == 401


def test_jwt_expiration(client):
    expired_token = create_access_token(
        {"sub": "testuser"}, expires_delta=timedelta(seconds=-10)
    )
    response = client.get(
        "/api/v1/history", headers={"Authorization": f"Bearer {expired_token}"}
    )
    assert response.status_code == 401


def test_refresh_token(client):
    # First login to get tokens
    res = client.post(
        "/api/v1/auth/login", data={"username": "testuser", "password": "testpassword"}
    )
    refresh_token = res.json()["refresh_token"]

    # Try refreshing
    refresh_res = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": refresh_token}
    )
    assert refresh_res.status_code == 200
    assert "access_token" in refresh_res.json()
    assert "refresh_token" in refresh_res.json()


def test_refresh_token_reuse_is_rejected(client):
    suffix = uuid.uuid4().hex[:10]
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "username": f"rotation_{suffix}",
            "password": "test-password",
            "email": f"rotation_{suffix}@example.com",
        },
    )
    assert registered.status_code == 200
    old_refresh_token = registered.json()["refresh_token"]

    rotated = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": old_refresh_token}
    )
    assert rotated.status_code == 200

    reused = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": old_refresh_token}
    )
    assert reused.status_code == 401


def test_logout_revokes_access_and_refresh_tokens(client):
    suffix = uuid.uuid4().hex[:10]
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "username": f"logout_{suffix}",
            "password": "test-password",
            "email": f"logout_{suffix}@example.com",
        },
    )
    assert registered.status_code == 200
    tokens = registered.json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    logout = client.post("/api/v1/auth/logout", headers=headers)
    assert logout.status_code == 200

    history = client.get("/api/v1/history", headers=headers)
    assert history.status_code == 401
    refresh = client.post(
        "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
    )
    assert refresh.status_code == 401


def test_delete_account_removes_owned_data_and_revokes_tokens(
    client, db_session, monkeypatch
):
    from app.api.v1.endpoints import recommend

    class FakeAgent:
        async def analyze(self, text, chat_history=None, user_context=None):
            return {
                "action": "guide",
                "emotion": "حزن",
                "confidence": 0.9,
                "ai_message": "رسالة حذف اختبارية.",
            }

    class FakeEmbedder:
        def search_similar(self, **kwargs):
            return {
                "documents": [["وَبَشِّرِ الصَّابِرِينَ"]],
                "metadatas": [[{"type": "verse", "source": "اختبار"}]],
                "ids": [["delete-test-verse"]],
                "distances": [[0.1]],
            }

    class FakeRagEngine:
        async def select_best_verse(self, user_text, emotion, verses):
            return verses[0]

        async def format_response(self, **kwargs):
            return "رد حذف اختباري"

    monkeypatch.setattr(recommend, "agent", FakeAgent())
    monkeypatch.setattr(recommend, "embedder", FakeEmbedder())
    monkeypatch.setattr(recommend, "rag_engine", FakeRagEngine())

    suffix = uuid.uuid4().hex[:10]
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "username": f"delete_{suffix}",
            "password": "test-password",
            "email": f"delete_{suffix}@example.com",
        },
    )
    assert registered.status_code == 200
    tokens = registered.json()
    headers = {"Authorization": f"Bearer {tokens['access_token']}"}

    recommendation = client.post(
        "/api/v1/analyze",
        json={"text": "أحتاج إلى مواساة"},
        headers=headers,
    )
    assert recommendation.status_code == 200

    user = db_session.query(User).filter(User.username == f"delete_{suffix}").one()
    assert db_session.query(Interaction).filter(Interaction.user_id == user.id).count()
    assert (
        db_session.query(DelayedResponse)
        .filter(DelayedResponse.user_id == user.id)
        .count()
        == 0
    )

    deleted = client.delete("/api/v1/auth/account", headers=headers)
    assert deleted.status_code == 200
    assert deleted.json()["deleted_user_id"] == user.id
    assert db_session.query(User).filter(User.id == user.id).one_or_none() is None
    assert (
        db_session.query(Interaction).filter(Interaction.user_id == user.id).count()
        == 0
    )
    assert (
        db_session.query(DelayedResponse)
        .filter(DelayedResponse.user_id == user.id)
        .count()
        == 0
    )

    assert client.get("/api/v1/history", headers=headers).status_code == 401
    assert (
        client.post(
            "/api/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]}
        ).status_code
        == 401
    )
    assert (
        client.post(
            "/api/v1/auth/login",
            data={"username": f"delete_{suffix}", "password": "test-password"},
        ).status_code
        == 401
    )


def test_export_requires_authentication_and_excludes_password(client):
    unauthenticated = client.get("/api/v1/auth/export")
    assert unauthenticated.status_code == 401

    suffix = uuid.uuid4().hex[:10]
    registered = client.post(
        "/api/v1/auth/register",
        json={
            "username": f"export_{suffix}",
            "password": "test-password",
            "email": f"export_{suffix}@example.com",
        },
    )
    assert registered.status_code == 200

    response = client.get(
        "/api/v1/auth/export",
        headers={"Authorization": f"Bearer {registered.json()['access_token']}"},
    )
    assert response.status_code == 200
    data = response.json()
    assert data["account"]["username"] == f"export_{suffix}"
    assert "password_hash" not in data["account"]
    assert isinstance(data["interactions"], list)


def test_user_isolation(client):
    # Register user 2
    client.post(
        "/api/v1/auth/register",
        json={
            "username": "user2",
            "password": "test-password",
            "email": "user2@example.com",
        },
    )
    res2 = client.post(
        "/api/v1/auth/login",
        data={"username": "user2", "password": "test-password"},
    )
    token2 = res2.json()["access_token"]

    # User 1
    res1 = client.post(
        "/api/v1/auth/login", data={"username": "testuser", "password": "testpassword"}
    )
    token1 = res1.json()["access_token"]

    # User 1 saves history by making a recommendation
    rec_res = client.post(
        "/api/v1/analyze",
        json={"text": "I am feeling lonely"},
        headers={"Authorization": f"Bearer {token1}"},
    )
    assert rec_res.status_code == 200, f"Recommend failed: {rec_res.json()}"

    # User 2 reads history
    history_user2 = client.get(
        "/api/v1/history", headers={"Authorization": f"Bearer {token2}"}
    ).json()
    assert len(history_user2) == 0, "User 2 should not see User 1's history"

    # User 1 reads history
    history_user1 = client.get(
        "/api/v1/history", headers={"Authorization": f"Bearer {token1}"}
    ).json()
    assert len(history_user1) > 0, "User 1 should see their own history"
