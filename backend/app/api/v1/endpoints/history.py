
from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

from app.core.security import limiter
from app.services.history_manager import HistoryManager

router = APIRouter()
history_manager = HistoryManager()

class FeedbackRequest(BaseModel):
    id: str
    feedback: int

@router.get("")
@router.get("/")
@router.get("/history")
@limiter.limit("30/minute")
async def get_history(request: Request):
    return history_manager.get_history()

@router.delete("")
@router.delete("/")
@limiter.limit("5/minute")
async def clear_history(request: Request):
    success = history_manager.clear_history()
    return {"status": "success" if success else "error"}

@router.post("/feedback")
@limiter.limit("30/minute")
async def update_feedback(request: Request, payload: FeedbackRequest):
    success = history_manager.update_feedback(payload.id, payload.feedback)
    if success:
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="Record not found")
