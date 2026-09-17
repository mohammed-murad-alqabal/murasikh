import re

with open("backend/app/api/v1/endpoints/home.py", "r") as f:
    content = f.read()

models_import = """
from app.db.models import AppRating
"""

if "from app.db.models import AppRating" not in content:
    content = content.replace("from app.db.database import get_db", "from app.db.database import get_db\nfrom app.db.models import AppRating")

rating_payload = """

class AppRatingRequest(BaseModel):
    rating: int
    feedback: str | None = None
"""

content = content.replace("class ContextSignalsRequest(BaseModel):", rating_payload + "\nclass ContextSignalsRequest(BaseModel):")

endpoint = """
@router.post("/rating")
@limiter.limit("5/minute")
async def submit_app_rating(
    request: Request,
    payload: AppRatingRequest,
    user: dict | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    \"\"\"يستقبل تقييم التطبيق ويحفظه في قاعدة البيانات\"\"\"
    try:
        user_id = user["id"] if user else None
        new_rating = AppRating(
            user_id=user_id,
            rating=payload.rating,
            feedback=payload.feedback
        )
        db.add(new_rating)
        db.commit()
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Error saving app rating: {e}", exc_info=True)
        db.rollback()
        from fastapi import HTTPException
        raise HTTPException(status_code=500, detail="Internal Server Error")
"""

content = content + "\n" + endpoint

with open("backend/app/api/v1/endpoints/home.py", "w") as f:
    f.write(content)
