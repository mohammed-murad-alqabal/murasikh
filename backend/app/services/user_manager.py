import os
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from sqlalchemy.exc import IntegrityError
from sqlalchemy import update
from sqlalchemy.orm import Session

from app.db.models import User

# Configure Argon2id with lower costs in test environments for speed
if os.environ.get("ENVIRONMENT") == "testing":
    ph = PasswordHasher(time_cost=1, memory_cost=8, parallelism=1)
else:
    ph = PasswordHasher(time_cost=3, memory_cost=65536, parallelism=4)

class UserManager:
    def get_password_hash(self, password: str) -> str:
        return ph.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        try:
            return ph.verify(hashed_password, plain_password)
        except (VerifyMismatchError, ValueError):
            return False

    def create_user(
        self, db: Session, username: str, password: str, email: str | None = None
    ) -> dict:
        hashed_password = self.get_password_hash(password)
        db_user = User(
            username=username,
            email=email if email else f"{username}@example.com",
            password_hash=hashed_password,
        )
        try:
            db.add(db_user)
            db.commit()
            db.refresh(db_user)
            return {
                "id": db_user.id,
                "username": db_user.username,
                "email": db_user.email,
            }
        except IntegrityError:
            db.rollback()
            return None  # Username or email already exists

    def get_user_by_username(self, db: Session, username: str) -> dict:
        user = (
            db.query(User)
            .filter(
                User.username == username,
                User.is_active.is_(True),
                User.is_deleted.is_(False),
            )
            .first()
        )
        if user:
            return {
                "id": user.id,
                "username": user.username,
                "email": user.email,
                "password_hash": user.password_hash,
                "refresh_jti": getattr(user, "refresh_jti", None),
            }
        return None

    def set_refresh_jti(self, db: Session, username: str, jti: str | None):
        user_record = db.query(User).filter(User.username == username).first()
        if user_record:
            user_record.refresh_jti = jti
            db.commit()

    def rotate_refresh_jti(
        self, db: Session, username: str, old_jti: str, new_jti: str
    ) -> bool:
        """Atomically consume the old refresh JTI and install the new one."""
        result = db.execute(
            update(User)
            .where(User.username == username, User.refresh_jti == old_jti)
            .values(refresh_jti=new_jti)
        )
        db.commit()
        return result.rowcount == 1
