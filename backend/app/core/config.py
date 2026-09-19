from pydantic import computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Murassikh API"
    API_V1_STR: str = "/api/v1"

    # Database Settings
    POSTGRES_SERVER: str = "localhost"
    POSTGRES_USER: str = "postgres"
    POSTGRES_PASSWORD: str = "postgres"
    POSTGRES_DB: str = "murassikh_db"
    POSTGRES_PORT: int = 5432

    @computed_field
    @property
    def SQLALCHEMY_DATABASE_URI(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_SERVER}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"

    # AI API Keys
    OPENAI_API_KEY: str = ""
    GEMINI_API_KEY: str = ""

    ENVIRONMENT: str = "development"
    CORS_ORIGINS: str = "http://localhost,http://127.0.0.1,http://10.0.2.2"

    # JWT Settings
    SECRET_KEY: str = "super-secret-key-change-in-production"
    ALGORITHM: str = "HS512"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 15  # 15 minutes
    REFRESH_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.ENVIRONMENT == "production":
            if (
                self.SECRET_KEY == "super-secret-key-change-in-production"
                or len(self.SECRET_KEY) < 32
            ):
                raise ValueError(
                    "SECRET_KEY must be set to at least 32 characters in production"
                )
            if self.POSTGRES_PASSWORD == "postgres":
                raise ValueError("POSTGRES_PASSWORD must be changed in production")

            # P3: Mandatory production CORS without localhost
            if not self.CORS_ORIGINS:
                raise ValueError("CORS_ORIGINS must be explicitly set in production")
            cors_list = [o.strip() for o in self.CORS_ORIGINS.split(",") if o.strip()]
            for origin in cors_list:
                if "localhost" in origin or "127.0.0.1" in origin:
                    raise ValueError(f"CORS_ORIGINS cannot contain localhost in production: {origin}")

    @property
    def cors_origins(self) -> list[str]:
        return [
            origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()
        ]

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
    )


settings = Settings()
