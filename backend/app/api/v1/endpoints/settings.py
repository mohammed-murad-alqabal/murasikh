from fastapi import APIRouter, Depends, Request, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.db.database import get_db
from app.db.models import AppRating
from app.api.v1.endpoints.auth import get_current_user_optional
from app.core.security import limiter
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

class AppRatingRequest(BaseModel):
    rating: int
    feedback: str | None = None

@router.post("/rating")
@limiter.limit("5/minute")
async def submit_rating(
    request: Request,
    payload: AppRatingRequest,
    user: dict | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db)
):
    try:
        user_id = user["id"] if user else None

        new_rating = AppRating(
            user_id=user_id,
            rating=payload.rating,
            feedback=payload.feedback
        )
        db.add(new_rating)
        db.commit()
        return {"status": "success", "message": "Rating submitted successfully"}
    except Exception as e:
        logger.error(f"Error saving rating: {e}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail="Internal Server Error")
