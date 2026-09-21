from pathlib import Path


def test_api_route_registry_is_canonical(client):
    paths = client.get("/openapi.json").json()["paths"]

    assert "/api/v1/analyze" in paths
    assert "post" in paths["/api/v1/analyze"]
    assert "/api/v1/home/verse" in paths
    assert "post" in paths["/api/v1/home/verse"]
    assert "/api/v1/audio/analyze-audio" in paths
    assert "/api/v1/history/feedback" in paths
    assert "/health/live" in paths
    assert "/health/ready" in paths

    # These paths belonged to obsolete documentation and must not become contracts.
    assert "/api/v1/recommend" not in paths
    assert "/api/v1/home/daily-verse" not in paths


def test_flutter_client_uses_the_canonical_routes():
    api_service = (
        Path(__file__).resolve().parents[3]
        / "frontend"
        / "lib"
        / "services"
        / "api_service.dart"
    ).read_text(encoding="utf-8")

    assert "$baseUrl/analyze'" in api_service
    assert "$baseUrl/home/verse'" in api_service
    assert "$baseUrl/analyze/recommend" not in api_service
    assert "$baseUrl/home/daily-verse" not in api_service
