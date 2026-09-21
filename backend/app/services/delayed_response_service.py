from datetime import datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.db.models import DelayedResponse


class DelayedResponseService:
    """Persists delayed guidance and delivers it once it becomes due.

    Delivery is pull-based: the authenticated client asks for due messages,
    which keeps deployment free of a separate worker while preserving a
    durable queue in PostgreSQL.
    """

    DEFAULT_DELAY = timedelta(minutes=5)

    def __init__(self, db: Session):
        self.db = db

    def schedule(
        self,
        *,
        user_id: int,
        interaction_id: int,
        payload: dict,
        reason: str = "high_emotion",
        delay: timedelta | None = None,
    ) -> DelayedResponse:
        response = DelayedResponse(
            user_id=user_id,
            interaction_id=interaction_id,
            recommendation_type="guidance",
            reason=reason,
            is_delivered=False,
            scheduled_for=datetime.now(timezone.utc) + (delay or self.DEFAULT_DELAY),
            payload=payload,
        )
        self.db.add(response)
        self.db.commit()
        self.db.refresh(response)
        return response

    def deliver_due(self, user_id: int, *, now: datetime | None = None) -> list[dict]:
        current_time = now or datetime.now(timezone.utc)
        responses = (
            self.db.query(DelayedResponse)
            .filter(
                DelayedResponse.user_id == user_id,
                DelayedResponse.is_delivered.is_(False),
                DelayedResponse.scheduled_for <= current_time,
            )
            .order_by(DelayedResponse.scheduled_for.asc(), DelayedResponse.id.asc())
            .with_for_update(skip_locked=True)
            .all()
        )

        delivered = []
        for response in responses:
            response.is_delivered = True
            response.delivered_at = current_time
            delivered.append(
                {
                    "id": response.id,
                    "interaction_id": response.interaction_id,
                    "reason": response.reason,
                    "scheduled_for": response.scheduled_for.isoformat()
                    if response.scheduled_for
                    else None,
                    "delivered_at": current_time.isoformat(),
                    **(response.payload or {}),
                }
            )

        if responses:
            self.db.commit()
        return delivered
