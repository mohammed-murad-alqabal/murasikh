import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.config import settings
from app.core.security import limiter
from app.db.database import Base, get_db
from app.services.user_manager import UserManager

# Test Database setup (Use actual PostgreSQL to support JSONB/ARRAY)
SQLALCHEMY_DATABASE_URL = settings.SQLALCHEMY_DATABASE_URI
engine = create_engine(SQLALCHEMY_DATABASE_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db


@pytest.fixture(scope="session", autouse=True)
def disable_rate_limits_for_tests():
    """Keep endpoint tests deterministic; rate limiting is tested separately."""
    previous_state = limiter.enabled
    limiter.enabled = False
    yield
    limiter.enabled = previous_state

@pytest.fixture(scope="session", autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="module")
def client():
    with TestClient(app) as c:
        yield c
