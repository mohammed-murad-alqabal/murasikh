from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.db.models import Interaction

class HistoryService:
    def __init__(self, db: Session):
        self.db = db

    def add_record(self, user_id: int, input_text: str, emotion: str, message: str, source: str = None, tafsir: str = None):
        interaction = Interaction(
            user_id=user_id,
            query_text=input_text,
            detected_emotion=emotion,
            message=message,
            source=source,
            tafsir=tafsir,
            emotion_confidence=1.0,
            response_tier="moderate",
            user_feedback=0
        )
        self.db.add(interaction)
        self.db.commit()
        self.db.refresh(interaction)
        return interaction

    def update_feedback(self, user_id: int, record_id: int, feedback: int):
        interaction = self.db.query(Interaction).filter(Interaction.id == record_id, Interaction.user_id == user_id).first()
        if interaction:
            interaction.user_feedback = feedback
            self.db.commit()
            return True
        return False

    def clear_history(self, user_id: int) -> bool:
        try:
            self.db.query(Interaction).filter(Interaction.user_id == user_id).delete()
            self.db.commit()
            return True
        except Exception:
            self.db.rollback()
            return False

    def get_history(self, user_id: int) -> list[dict]:
        interactions = self.db.query(Interaction).filter(Interaction.user_id == user_id).order_by(desc(Interaction.created_at)).all()
        history = []
        for row in interactions:
            history.append({
                "id": row.id,
                "timestamp": row.created_at.isoformat(),
                "input_text": row.query_text,
                "recommendation": {
                    "emotion": row.detected_emotion,
                    "message": row.message,
                    "source": row.source,
                    "tafsir": row.tafsir,
                    "confidence": row.emotion_confidence,
                    "tier": row.response_tier
                },
                "feedback": row.user_feedback
            })
        return history
            
    def get_user_context(self, user_id: int) -> str:
        try:
            interactions = self.db.query(Interaction).filter(
                Interaction.user_id == user_id,
                Interaction.user_feedback != 0
            ).order_by(desc(Interaction.created_at)).all()
            
            liked = set()
            disliked = set()
            
            for row in interactions:
                if row.user_feedback == 1 and len(liked) < 3:
                    liked.add(row.detected_emotion)
                elif row.user_feedback == -1 and len(disliked) < 3:
                    disliked.add(row.detected_emotion)
            
            if not liked and not disliked:
                return ""
                
            context = ""
            if liked:
                context += f"User finds guidance helpful for: {', '.join(liked)}. "
            if disliked:
                context += f"User disliked previous guidance for: {', '.join(disliked)}."
            return context
        except Exception:
            return ""
