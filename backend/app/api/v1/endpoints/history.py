from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any
from app.services.history_manager import HistoryManager

router = APIRouter()
history_manager = HistoryManager()

class FeedbackRequest(BaseModel):
    id: str
    feedback: int

@router.get("")
@router.get("/")
@router.get("/history")
async def get_history():
    return history_manager.get_history()

@router.delete("")
@router.delete("/")
async def clear_history():
    success = history_manager.clear_history()
    return {"status": "success" if success else "error"}

@router.post("/feedback")
async def update_feedback(request: FeedbackRequest):
    success = history_manager.update_feedback(request.id, request.feedback)
    if success:
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="Record not found")
