with open("backend/app/db/models.py", "r") as f:
    content = f.read()

new_model = """
class AppRating(Base):
    __tablename__ = "app_ratings"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    rating = Column(Integer, nullable=False)
    feedback = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", backref="app_ratings")
"""

with open("backend/app/db/models.py", "w") as f:
    f.write(content + "\n" + new_model)
