import uuid
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app.db.models import User

pwd_context = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")

class UserManager:
    def get_password_hash(self, password: str) -> str:
        return pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return pwd_context.verify(plain_password, hashed_password)

    def create_user(self, db: Session, username: str, password: str, email: str = None) -> dict:
        hashed_password = self.get_password_hash(password)
        db_user = User(
            username=username,
            email=email if email else f"{username}@example.com",
            password_hash=hashed_password
        )
        try:
            db.add(db_user)
            db.commit()
            db.refresh(db_user)
            return {"id": db_user.id, "username": db_user.username, "email": db_user.email}
        except IntegrityError:
            db.rollback()
            return None # Username or email already exists

    def get_user_by_username(self, db: Session, username: str) -> dict:
        user = db.query(User).filter(
            User.username == username,
            User.is_active.is_(True),
            User.is_deleted.is_(False),
        ).first()
        if user:
            return {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "password_hash": user.password_hash
            }
        return None
