from fastapi import APIRouter, HTTPException, Depends, Request
from pydantic import BaseModel
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from app.services.user_manager import UserManager
from app.core.auth import create_access_token, verify_token
from app.core.security import limiter

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
async def register(request: Request, user: UserCreate):
    new_user = user_manager.create_user(user.username, user.password, user.email)
    if not new_user:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    access_token = create_access_token(data={"sub": new_user["username"]})
    return {"access_token": access_token, "token_type": "bearer"}

@router.post("/login", response_model=Token)
@limiter.limit("10/minute")
async def login(request: Request, form_data: OAuth2PasswordRequestForm = Depends()):
    user = user_manager.get_user_by_username(form_data.username)
    if not user or not user_manager.verify_password(form_data.password, user["password_hash"]):
        raise HTTPException(
            status_code=401,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": user["username"]})
    return {"access_token": access_token, "token_type": "bearer"}

async def get_current_user(token: str = Depends(oauth2_scheme)):
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    username = payload.get("sub")
    if username is None:
        raise HTTPException(status_code=401, detail="Invalid token")
    
    user = user_manager.get_user_by_username(username)
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    
    return user
