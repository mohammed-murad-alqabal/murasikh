import time
import os
import sys
import datetime

# Setup environment
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.services.history_manager import HistoryService
import app.db.models

def setup_db():
    engine = create_engine('postgresql://postgres:postgres@localhost:5432/postgres')
    app.db.models.Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()

    user_id = 9999

    # Check if user exists, if not, create it
    user = session.query(app.db.models.User).filter(app.db.models.User.id == user_id).first()
    if not user:
        user = app.db.models.User(id=user_id, username="benchmark_user", email="benchmark@test.com", password_hash="test")
        session.add(user)
        session.commit()

    # Clean up interactions
    session.query(app.db.models.Interaction).filter(app.db.models.Interaction.user_id == user_id).delete()
    session.commit()

    interactions = []
    # Create 10000 dummy interactions
    for i in range(10000):
        feedback = 1 if i % 2 == 0 else -1
        interactions.append(app.db.models.Interaction(
            user_id=user_id,
            query_text=f"test {i}",
            detected_emotion=f"emotion_{i % 10}",
            message="msg",
            user_feedback=feedback,
            created_at=datetime.datetime.now(datetime.timezone.utc)
        ))
    session.bulk_save_objects(interactions)
    session.commit()
    return session, user_id

def run_benchmark():
    session, user_id = setup_db()
    history_service = HistoryService(session)

    print("Running optimized benchmark...")
    start_time = time.time()
    # Run multiple times to get a stable measurement
    num_iterations = 100
    for _ in range(num_iterations):
        history_service.get_user_context(user_id)
    end_time = time.time()

    duration = end_time - start_time
    print(f"Time taken for {num_iterations} iterations: {duration:.4f} seconds")
    print(f"Average time per call: {(duration / num_iterations) * 1000:.2f} ms")

    # Cleanup
    session.query(app.db.models.Interaction).filter(app.db.models.Interaction.user_id == user_id).delete()
    session.query(app.db.models.User).filter(app.db.models.User.id == user_id).delete()
    session.commit()

    return duration

if __name__ == "__main__":
    run_benchmark()
