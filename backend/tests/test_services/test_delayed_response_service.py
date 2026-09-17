from datetime import datetime, timedelta
import uuid

from app.db.models import DelayedResponse, Interaction, User
from app.services.delayed_response_service import DelayedResponseService
from app.services.user_manager import UserManager


def test_delayed_response_is_delivered_once(db_session):
    db = db_session
    suffix = uuid.uuid4().hex[:10]
    user = User(
        username=f"delayed_{suffix}",
        email=f"delayed_{suffix}@example.com",
        password_hash=UserManager().get_password_hash("password"),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    interaction = Interaction(
        user_id=user.id,
        query_text="أشعر بيأس شديد",
        detected_emotion="يأس",
        message="خذ نفساً عميقاً.",
        emotion_confidence=0.95,
        response_tier="minimal",
        response_delayed=True,
    )
    db.add(interaction)
    db.commit()
    db.refresh(interaction)

    try:
        service = DelayedResponseService(db)
        scheduled = service.schedule(
            user_id=user.id,
            interaction_id=interaction.id,
            payload={
                "emotion": "يأس",
                "confidence": 0.95,
                "tier": "full",
                "message": "رسالة مؤجلة للاختبار",
            },
            delay=timedelta(minutes=-1),
        )
        assert scheduled.is_delivered is False

        now = datetime.utcnow()
        delivered = service.deliver_due(user.id, now=now)
        assert len(delivered) == 1
        assert delivered[0]["message"] == "رسالة مؤجلة للاختبار"
        assert delivered[0]["interaction_id"] == interaction.id

        assert service.deliver_due(user.id, now=now) == []
    finally:
        db.rollback()
        db.query(DelayedResponse).filter(DelayedResponse.user_id == user.id).delete()
        db.delete(interaction)
        db.delete(user)
        db.commit()
