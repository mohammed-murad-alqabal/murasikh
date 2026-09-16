from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.api.v1.endpoints import audio, history, recommend, auth
from app.core.config import settings
from app.core.security import limiter

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="API for Murassikh - The Smart Spiritual Companion"
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost", "http://127.0.0.1", "http://10.0.2.2"], # حظر النطاقات العشوائية (Strict CORS)
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# ربط واجهة التوصية (API Endpoint)
app.include_router(recommend.router, prefix="/api/v1/analyze", tags=["recommendations"])
app.include_router(history.router, prefix="/api/v1/history", tags=["history"])
app.include_router(audio.router, prefix="/api/v1", tags=["audio"])
app.include_router(auth.router, prefix="/api/v1/auth", tags=["auth"])

@app.get("/")
@limiter.limit("10/minute")
def read_root(request: Request):
    return {"message": "مرحباً بك في واجهة برمجة تطبيقات مُرَسِّخ (Murassikh API)"}

@app.get("/health")
@limiter.limit("20/minute")
def health_check(request: Request):
    return {"status": "ok"}

