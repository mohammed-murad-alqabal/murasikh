from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.core.auth import create_access_token, create_refresh_token, verify_token
from app.core.security import limiter
from app.db.database import get_db
from app.services.history_manager import HistoryService
from app.services.user_manager import UserManager

router = APIRouter()
user_manager = UserManager()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")


class UserCreate(BaseModel):
    username: str = Field(
        ...,
        min_length=3,
        max_length=50,
        pattern=r"^[A-Za-z0-9_.-]+$",
    )
    password: str = Field(..., min_length=8, max_length=128)
    email: str | None = Field(None, max_length=254)


class Token(BaseModel):
    access_token: str
    token_type: str
    refresh_token: str | None = None


class RefreshToken(BaseModel):
    refresh_token: str


def _issue_tokens(user: dict) -> tuple[dict[str, str], str]:
    token_data = {
        "sub": user["username"],
        "session_version": user["session_version"],
    }
    access_token = create_access_token(data=token_data)
    refresh_token, jti = create_refresh_token(data=token_data)
    return (
        {
            "access_token": access_token,
            "token_type": "bearer",
            "refresh_token": refresh_token,
        },
        jti,
    )


@router.post("/register")
@limiter.limit("5/minute")
async def register(request: Request, user: UserCreate, db: Session = Depends(get_db)):
    new_user = user_manager.create_user(db, user.username, user.password, user.email)
    if not new_user:
        raise HTTPException(status_code=400, detail="Username or email already exists")

    tokens, jti = _issue_tokens(new_user)
    user_manager.set_refresh_jti(db, new_user["username"], jti)
    return tokens


@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    user = user_manager.get_user_by_username(db, form_data.username)
    if not user or not user_manager.verify_password(
        form_data.password, user["password_hash"]
    ):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    tokens, jti = _issue_tokens(user)
    user_manager.set_refresh_jti(db, user["username"], jti)
    return tokens


@router.post("/refresh", response_model=Token)
@limiter.limit("5/minute")
async def refresh_token(
    request: Request, body: RefreshToken, db: Session = Depends(get_db)
):
    payload = verify_token(body.refresh_token, token_type="refresh")
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    username = payload.get("sub")
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = user_manager.get_user_by_username(db, username)
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    if payload.get("session_version") != user["session_version"]:
        raise HTTPException(status_code=401, detail="Session has been revoked")

    jti = payload.get("jti")
    if not jti or user.get("refresh_jti") != jti:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    token_data = {
        "sub": user["username"],
        "session_version": user["session_version"],
    }
    new_access_token = create_access_token(data=token_data)
    new_refresh_token, new_jti = create_refresh_token(data=token_data)
    if not user_manager.rotate_refresh_jti(db, user["username"], jti, new_jti):
        raise HTTPException(status_code=401, detail="Refresh token already used")

    return {
        "access_token": new_access_token,
        "token_type": "bearer",
        "refresh_token": new_refresh_token,
    }


async def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
):
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    username = payload.get("sub")
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = user_manager.get_user_by_username(db, username)
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    if payload.get("session_version") != user["session_version"]:
        raise HTTPException(status_code=401, detail="Session has been revoked")

    return user


@router.get("/export")
@limiter.limit("5/minute")
async def export_user_data(
    request: Request,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Export only the authenticated user's account and interaction data."""
    history_service = HistoryService(db)
    return {
        "export_version": 1,
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "account": {
            "id": user["id"],
            "username": user["username"],
            "email": user["email"],
        },
        "interactions": history_service.get_history(user["id"]),
    }


oauth2_scheme_optional = OAuth2PasswordBearer(
    tokenUrl="api/v1/auth/login", auto_error=False
)


async def get_current_user_optional(
    token: str = Depends(oauth2_scheme_optional), db: Session = Depends(get_db)
):
    if not token:
        return None
    payload = verify_token(token)
    if payload is None:
        return None
    username = payload.get("sub")
    if username is None:
        return None
    user = user_manager.get_user_by_username(db, username)
    if user is None or payload.get("session_version") != user["session_version"]:
        return None
    return user


@router.post("/logout")
@limiter.limit("5/minute")
async def logout(
    request: Request,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if not user_manager.revoke_session(db, user["username"]):
        raise HTTPException(status_code=401, detail="Session is no longer active")
    return {"message": "Logged out successfully"}


@router.delete("/account")
@limiter.limit("3/hour")
async def delete_account(
    request: Request,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Permanently delete all account-owned server records and the account."""
    if not user_manager.delete_account(db, user["id"]):
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "message": "Account and account-owned data deleted",
        "deleted_user_id": user["id"],
    }
