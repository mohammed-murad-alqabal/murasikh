import pytest
from pydantic import ValidationError

from app.api.v1.endpoints.recommend import RecommendationRequest


def test_recommendation_request_rejects_invalid_user_context():
    with pytest.raises(ValidationError):
        RecommendationRequest.model_validate(
            {"text": "أنا حزين", "user_context": {"age": "invalid_age"}}
        )

    with pytest.raises(ValidationError):
        RecommendationRequest.model_validate(
            {"text": "أنا حزين", "user_context": {"invalid_field": "value"}}
        )


def test_recommendation_request_accepts_valid_user_context():
    request = RecommendationRequest.model_validate(
        {
            "text": "أنا حزين",
            "user_context": {
                "age": 25,
                "gender": "male",
                "facial_emotion": "sad",
                "source": "camera",
            },
        }
    )

    assert request.user_context is not None
    assert request.user_context.age == 25
    assert request.user_context.gender == "male"
