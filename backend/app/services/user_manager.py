import base64
import hashlib
import warnings

import bcrypt
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db.models import User

with warnings.catch_warnings():
    warnings.simplefilter("ignore")
    import passlib.utils.handlers as uh
    from passlib.context import CryptContext

    class ModernBcrypt(uh.GenericHandler):
        """
        A custom passlib handler to wrap modern bcrypt (>= 4.0) properly,
        because passlib's built-in bcrypt handler is broken on newer versions.
        """

        name = "bcrypt"
        setting_kwds = ("salt", "rounds")
        ident = "$2b$"
        checksum_chars = uh.H64_CHARS
        checksum_size = 31

        @classmethod
        def identify(cls, hash):
            if isinstance(hash, bytes):
                hash = hash.decode("ascii")
            return hash.startswith(("$2b$", "$2a$", "$2y$"))

        @classmethod
        def from_string(cls, hash):
            if isinstance(hash, bytes):
                hash = hash.decode("ascii")
            if not cls.identify(hash):
                raise ValueError("Invalid bcrypt hash")
            return cls(checksum=hash)

        def to_string(self):
            return self.checksum

        @classmethod
        def _pre_hash(cls, secret):
            """
            Pre-hashes the password using SHA-256 to avoid bcrypt's 72-byte truncation limit.
            """
            if isinstance(secret, str):
                secret = secret.encode("utf-8")
            return base64.b64encode(hashlib.sha256(secret).digest())

        @classmethod
        def hash(cls, secret, **kwds):
            secret = cls._pre_hash(secret)
            rounds = kwds.get("rounds", 12)
            salt = bcrypt.gensalt(rounds=rounds)
            return bcrypt.hashpw(secret, salt).decode("ascii")

        @classmethod
        def verify(cls, secret, hash):
            secret = cls._pre_hash(secret)
            if isinstance(hash, str):
                hash = hash.encode("ascii")
            try:
                return bcrypt.checkpw(secret, hash)
            except ValueError:
                return False


# Register our custom bcrypt implementation and keep pbkdf2_sha256 for backwards compatibility.
pwd_context = CryptContext(schemes=[ModernBcrypt, "pbkdf2_sha256"], deprecated=["pbkdf2_sha256"])


class UserManager:
    def get_password_hash(self, password: str) -> str:
        return pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return pwd_context.verify(plain_password, hashed_password)

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
