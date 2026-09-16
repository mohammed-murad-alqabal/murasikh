from app.db.database import SessionLocal
from app.db.models import Interaction

db = SessionLocal()
interactions = db.query(Interaction).order_by(Interaction.created_at.desc()).limit(10).all()
for i in interactions:
    print(f"User: {i.input_text}\nEmotion: {i.emotion}\nSource: {i.source}\nAI: {i.message}\n" + "-"*40)
