"""Print a small sample of stored interactions for local diagnostics."""

from app.db.database import SessionLocal
from app.db.models import Interaction


def main() -> None:
    db = SessionLocal()
    try:
        interactions = (
            db.query(Interaction)
            .order_by(Interaction.created_at.desc())
            .limit(10)
            .all()
        )
        for interaction in interactions:
            print(
                f"User ID: {interaction.user_id}\n"
                f"Input: {interaction.query_text}\n"
                f"Emotion: {interaction.detected_emotion}\n"
                f"Source: {interaction.source}\n"
                f"AI: {interaction.message}\n"
                + "-" * 40
            )
    finally:
        db.close()


if __name__ == "__main__":
    main()
