import uuid


def test_stale_refresh_token_does_not_revoke_current_session(client):
    suffix = uuid.uuid4().hex[:10]
    response = client.post(
        "/api/v1/auth/register",
        json={
            "username": f"stale_{suffix}",
            "password": "test-password",
            "email": f"stale_{suffix}@example.com",
        },
    )
    assert response.status_code == 200
    old_token = response.json()["refresh_token"]

    rotated = client.post("/api/v1/auth/refresh", json={"refresh_token": old_token})
    assert rotated.status_code == 200
    current_token = rotated.json()["refresh_token"]

    stale = client.post("/api/v1/auth/refresh", json={"refresh_token": old_token})
    assert stale.status_code == 401

    current = client.post("/api/v1/auth/refresh", json={"refresh_token": current_token})
    assert current.status_code == 200
