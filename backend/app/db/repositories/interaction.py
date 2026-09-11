from sqlalchemy.orm import Session
from app.db.models import Interaction
from app.db.repositories.base import CRUDBase

class CRUDInteraction(CRUDBase[Interaction]):
    def get_recent_by_user(self, db: Session, user_id: int, limit: int = 5):
        return (db.query(self.model)
                  .filter(self.model.user_id == user_id)
                  .order_by(self.model.created_at.desc())
                  .limit(limit)
                  .all())

interaction_repo = CRUDInteraction(Interaction)
