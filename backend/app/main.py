from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.endpoints import recommend

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="0.1.0",
    description="API for Murassikh - The Smart Spiritual Companion"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ربط واجهة التوصية (API Endpoint)
from app.api.v1.endpoints import recommend, history
app.include_router(recommend.router, prefix="/api/v1/analyze", tags=["recommendations"])
app.include_router(history.router, prefix="/api/v1/history", tags=["history"])

@app.get("/")
def read_root():
    return {"message": "مرحباً بك في واجهة برمجة تطبيقات مُرَسِّخ (Murassikh API)"}

@app.get("/health")
def health_check():
    return {"status": "ok"}
