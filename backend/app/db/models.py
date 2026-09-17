from datetime import datetime

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import relationship

from .database import Base


class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100), unique=True, index=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    preferences = Column(JSONB, default={
        "notification_style": "minimal",
        "language": "ar",
        "theme": "light",
        "font_size": "medium"
    })
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False)

    interactions = relationship("Interaction", back_populates="user")
    delayed_responses = relationship("DelayedResponse", back_populates="user")

class Verse(Base):
    __tablename__ = "verses"
    id = Column(Integer, primary_key=True, index=True)
    surah_number = Column(Integer, nullable=False)
    ayah_number = Column(Integer, nullable=False)
    text_arabic = Column(Text, nullable=False)
    text_uthmani = Column(Text)
    text_indopak = Column(Text)
    translation = Column(Text)
    tafsir = Column(Text)
    tafsir_source = Column(String(100))
    tags = Column(ARRAY(String))
    emotional_state = Column(String(50), index=True)
    keywords = Column(ARRAY(String))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False)

class Hadith(Base):
    __tablename__ = "hadiths"
    id = Column(Integer, primary_key=True, index=True)
    collection = Column(String(100), nullable=False, index=True)
    hadith_number = Column(String(50))
    text_arabic = Column(Text, nullable=False)
    translation = Column(Text)
    explanation = Column(Text)
    narrator = Column(String(255))
    grade = Column(String(50))
    tags = Column(ARRAY(String))
    emotional_state = Column(String(50), index=True)
    keywords = Column(ARRAY(String))
    is_authentic = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_deleted = Column(Boolean, default=False)

class Interaction(Base):
    __tablename__ = "interactions"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    query_text = Column(Text)
    detected_emotion = Column(String(50))
    emotion_confidence = Column(Float)
    recommendation_type = Column(String(20))
    recommendation_id = Column(Integer)
    # Added for history sync
    message = Column(Text)
    source = Column(String(255))
    tafsir = Column(Text)
    
    user_feedback = Column(Integer, default=0) # Changed to Integer (-1, 0, 1)
    response_tier = Column(String(20))
    response_delayed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    user = relationship("User", back_populates="interactions")
    delayed_response = relationship("DelayedResponse", back_populates="interaction")

class DelayedResponse(Base):
    __tablename__ = "delayed_responses"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    interaction_id = Column(Integer, ForeignKey("interactions.id"))
    recommendation_type = Column(String(20))
    recommendation_id = Column(Integer)
    reason = Column(String(100))
    is_delivered = Column(Boolean, default=False)
    scheduled_for = Column(DateTime)
    delivered_at = Column(DateTime)
    payload = Column(JSONB, nullable=False, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User", back_populates="delayed_responses")
    interaction = relationship("Interaction", back_populates="delayed_response")

