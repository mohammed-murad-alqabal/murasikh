import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_recommend_invalid_user_context():
    payload = {
        "text": "أنا حزين",
        "user_context": {
            "age": "invalid_age"
        }
    }
    response = client.post("/api/v1/analyze", json=payload)
    assert response.status_code == 422

    payload = {
        "text": "أنا حزين",
        "user_context": {
            "invalid_field": "value"
        }
    }
    response = client.post("/api/v1/analyze", json=payload)
    assert response.status_code == 422

def test_recommend_valid_user_context():
    payload = {
        "text": "أنا حزين",
        "user_context": {
            "age": 25,
            "gender": "male",
            "facial_emotion": "sad",
            "source": "camera"
        }
    }
    response = client.post("/api/v1/analyze", json=payload)
    assert response.status_code != 422
