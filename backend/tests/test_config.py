from app.core.config import Settings


def test_production_accepts_secret_key_loaded_from_environment(monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    monkeypatch.setenv("SECRET_KEY", "s" * 64)
    monkeypatch.setenv("POSTGRES_PASSWORD", "not-the-default-password")
    monkeypatch.setenv("CORS_ORIGINS", "https://app.example.com")

    settings = Settings()

    assert settings.SECRET_KEY == "s" * 64
    assert settings.ENVIRONMENT == "production"
