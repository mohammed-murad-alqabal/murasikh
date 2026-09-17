from pydantic_settings import BaseSettings
from pydantic import computed_field


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
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        if self.ENVIRONMENT == "production":
            if self.SECRET_KEY == "super-secret-key-change-in-production" or len(self.SECRET_KEY) < 32:
                raise ValueError("SECRET_KEY must be set to at least 32 characters in production")
            if self.POSTGRES_PASSWORD == "postgres":
                raise ValueError("POSTGRES_PASSWORD must be changed in production")

    @property
    def cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True

settings = Settings()
