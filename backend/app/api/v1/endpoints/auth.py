from fastapi import APIRouter, HTTPException, Depends, Request
from sqlalchemy.orm import Session
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from app.services.user_manager import UserManager
from app.core.auth import create_access_token, verify_token
from app.core.security import limiter
from app.db.database import get_db

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

@router.post("/register")
@limiter.limit("5/minute")
async def register(request: Request, user: UserCreate, db: Session = Depends(get_db)):
    new_user = user_manager.create_user(db, user.username, user.password, user.email)
    if not new_user:
        raise HTTPException(status_code=400, detail="Username or email already exists")
    
    access_token = create_access_token(data={"sub": new_user["username"]})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = user_manager.get_user_by_username(db, form_data.username)
    if not user or not user_manager.verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": user["username"]})
    return {"access_token": access_token, "token_type": "bearer"}

async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
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

oauth2_scheme_optional = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login", auto_error=False)

async def get_current_user_optional(token: str = Depends(oauth2_scheme_optional), db: Session = Depends(get_db)):
    if not token:
        return None
    payload = verify_token(token)
    if payload is None:
        return None
    username = payload.get("sub")
    if username is None:
        return None
    return user_manager.get_user_by_username(db, username)
