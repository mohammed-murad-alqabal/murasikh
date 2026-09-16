from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
from typing import List, Dict, Any
from app.services.history_manager import HistoryManager
from app.core.security import limiter

router = APIRouter()
history_manager = HistoryManager()

class FeedbackRequest(BaseModel):
    id: str
    feedback: int

@router.get("")
@router.get("/")
@router.get("/history")
@limiter.limit("30/minute")
async def get_history(req: Request):
    return history_manager.get_history()

@router.delete("")
@router.delete("/")
@limiter.limit("5/minute")
async def clear_history(req: Request):
    success = history_manager.clear_history()
    return {"status": "success" if success else "error"}

@router.post("/feedback")
@limiter.limit("30/minute")
async def update_feedback(req: Request, request: FeedbackRequest):
    success = history_manager.update_feedback(request.id, request.feedback)
    if success:
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="Record not found")
