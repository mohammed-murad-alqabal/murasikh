from fastapi import APIRouter, HTTPException, Request, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.security import limiter
from app.services.history_manager import HistoryService
from app.api.v1.endpoints.auth import get_current_user
from app.db.database import get_db

router = APIRouter()

class FeedbackRequest(BaseModel):
    id: str
    feedback: int

@router.get("")
@router.get("/")
@router.get("/history")
@limiter.limit("30/minute")
async def get_history(request: Request, user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    history_service = HistoryService(db)
    return history_service.get_history(user["id"])

@router.delete("")
@router.delete("/")
@limiter.limit("5/minute")
async def clear_history(request: Request, user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    history_service = HistoryService(db)
    success = history_service.clear_history(user["id"])
    return {"status": "success" if success else "error"}

@router.post("/feedback")
@limiter.limit("30/minute")
async def update_feedback(request: Request, payload: FeedbackRequest, user: dict = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        record_id = int(payload.id)
    except ValueError:
        return {"status": "success"}

    history_service = HistoryService(db)
    success = history_service.update_feedback(user["id"], record_id, payload.feedback)
    if success:
        return {"status": "success"}
    raise HTTPException(status_code=404, detail="Record not found")
