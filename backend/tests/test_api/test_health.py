from app.api.v1.endpoints import health


def test_liveness_is_independent_of_dependencies(client):
    response = client.get("/health/live")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_readiness_reports_all_dependencies(monkeypatch, client):
    monkeypatch.setattr(health, "_check_database", lambda: None)
    monkeypatch.setattr(health, "_check_redis", lambda: None)
    monkeypatch.setattr(health, "_check_chroma", lambda: None)

    response = client.get("/health/ready")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "checks": {"database": "ok", "redis": "ok", "chroma": "ok"},
    }


def test_readiness_returns_503_when_dependency_fails(monkeypatch, client):
    monkeypatch.setattr(health, "_check_database", lambda: None)
    monkeypatch.setattr(
        health, "_check_redis", lambda: (_ for _ in ()).throw(RuntimeError())
    )
    monkeypatch.setattr(health, "_check_chroma", lambda: None)

    response = client.get("/health/ready")

    assert response.status_code == 503
    assert response.json()["status"] == "not_ready"
    assert response.json()["checks"]["redis"] == "failed"
