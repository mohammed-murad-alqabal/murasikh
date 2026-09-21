from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
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
    username: str
    password: str
    email: str | None = None


class Token(BaseModel):
    access_token: str
    token_type: str
    refresh_token: str | None = None


@router.post("/register")
@limiter.limit("5/minute")
async def register(request: Request, user: UserCreate, db: Session = Depends(get_db)):
    new_user = user_manager.create_user(db, user.username, user.password, user.email)
    if not new_user:
        raise HTTPException(status_code=400, detail="Username or email already exists")

    access_token = create_access_token(data={"sub": new_user["username"]})
    refresh_token, jti = create_refresh_token(data={"sub": new_user["username"]})
    user_manager.set_refresh_jti(db, new_user["username"], jti)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token,
    }


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

    access_token = create_access_token(data={"sub": user["username"]})
    refresh_token, jti = create_refresh_token(data={"sub": user["username"]})
    user_manager.set_refresh_jti(db, user["username"], jti)
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token,
    }


class RefreshToken(BaseModel):
    refresh_token: str


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

    jti = payload.get("jti")
    if not jti or user.get("refresh_jti") != jti:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    new_access_token = create_access_token(data={"sub": user["username"]})
    new_refresh_token, new_jti = create_refresh_token(data={"sub": user["username"]})
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
    return user_manager.get_user_by_username(db, username)


@router.post("/logout")
@limiter.limit("5/minute")
async def logout(
    request: Request,
    user: dict = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    user_manager.set_refresh_jti(db, user["username"], None)
    return {"message": "Logged out successfully"}
