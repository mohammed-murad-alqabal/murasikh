import logging

from fastapi import APIRouter, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from app.api.v1.endpoints.auth import get_current_user_optional
from app.db.database import get_db
from pydantic import BaseModel, Field

from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES, EXTREME_EMOTIONS
from app.services.ai.embeddings import EmbeddingService
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.ai.rag_engine import RAGEngine
from app.services.history_manager import HistoryService

router = APIRouter()
analyzer = EmotionAnalyzer()
embedder = EmbeddingService()
rag_engine = RAGEngine()
logger = logging.getLogger(__name__)

class RecommendationRequest(BaseModel):
    text: str = Field(..., min_length=2, max_length=1000, description="نص المستخدم المراد تحليله")
    user_context: dict | None = Field(None, description="السياق الإضافي للمستخدم")

class RecommendationResponse(BaseModel):
    emotion: str
    confidence: float
    tier: str
    message: str
    delayed_message: str | None = None
    source: str | None = None
    tafsir: str | None = None

from app.core.security import limiter

@router.post("", response_model=RecommendationResponse)
@limiter.limit("15/minute")
async def get_recommendation(request: Request, payload: RecommendationRequest, user: dict | None = Depends(get_current_user_optional), db: Session = Depends(get_db)):
    try:
        # 1. تحليل الحالة العاطفية/الإيمانية مع سياق المستخدم
        analysis = await analyzer.analyze(payload.text, user_context=payload.user_context)
        emotion = analysis.get("emotion", "طبيعي")
        confidence = float(analysis.get("confidence", 0.0))

        history_service = HistoryService(db)
        if emotion == "طبيعي":
            msg = "يبدو أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
            if user:
                history_service.add_record(
                    user_id=user["id"],
                    input_text=payload.text,
                    emotion=emotion,
                    message=msg,
                    source="سكينة واطمئنان",
                    tafsir=None
                )
            return RecommendationResponse(
                emotion=emotion,
                confidence=confidence,
                tier="minimal",
                message=msg
            )

        # 2. بناء استعلام دلالي محسَّن للحالة
        semantic_query = EMOTION_SEMANTIC_QUERIES.get(
            emotion,
            f"الصبر والطمأنينة والتوكل على الله {payload.text}"
        )
        
        backend_context = history_service.get_user_context(user["id"]) if user else ""
        if backend_context:
            semantic_query = f"{semantic_query} {backend_context}"

        if payload.user_context:
            ctx = payload.user_context
            if ctx.get('age'): semantic_query += f" العمر: {ctx['age']}"
            if ctx.get('gender'): semantic_query += f" الجنس: {ctx['gender']}"
            if ctx.get('biometric_stress'): semantic_query += f" يعاني من توتر جسدي أو نبض مرتفع"
            if ctx.get('facial_emotion'): semantic_query += f" وملامح وجهه تظهر {ctx['facial_emotion']}"

        # 3. البحث في القرآن الكريم حصراً (بدون أحاديث) مع استخدام البحث الهجين
        verse_results = embedder.search_similar(
            query=semantic_query,
            n_results=3,        # نسترجع 3 لاختيار الأنسب
            filters={"type": "verse"},
            emotion=emotion
        )

        source = None
        tafsir = None
        base_message = "اذكر الله يهدأ قلبك."

        if (verse_results and verse_results.get('documents')
                and len(verse_results['documents'][0]) > 0):
            
            # تجهيز الآيات المسترجعة للفلترة الذكية
            verses_list = []
            for i in range(len(verse_results['documents'][0])):
                verses_list.append({
                    "text": verse_results['documents'][0][i],
                    "source": verse_results['metadatas'][0][i].get("source", ""),
                    "tafsir": verse_results['metadatas'][0][i].get("tafsir", "")
                })
            
            # اختيار أفضل آية للظرف الحالي عبر الذكاء الاصطناعي
            best_verse = await rag_engine.select_best_verse(
                user_text=payload.text,
                emotion=emotion,
                verses=verses_list
            )
            
            base_message = best_verse.get("text", "")
            source = best_verse.get("source", "")
            tafsir = best_verse.get("tafsir", "")

        # 4. صياغة الرد الدافئ عبر Gemini
        tier = "moderate"
        delayed_message = None

        if emotion in EXTREME_EMOTIONS:
            # للحالات الشديدة: رد فوري مختصر + رسالة تفصيلية لاحقة
            tier = "minimal"
            final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً."
            delayed_message = await rag_engine.format_response(
                user_text=payload.text,
                emotion=emotion,
                retrieved_text=base_message,
                source=source,
                tafsir=tafsir
            )
        else:
            final_message = await rag_engine.format_response(
                user_text=payload.text,
                emotion=emotion,
                retrieved_text=base_message,
                source=source,
                tafsir=tafsir
            )

        # 5. حفظ التفاعل
        if user:
            history_service.add_record(
                user_id=user["id"],
                input_text=payload.text,
                emotion=emotion,
                message=final_message,
                source=source,
                tafsir=tafsir
            )

        return RecommendationResponse(
            emotion=emotion,
            confidence=confidence,
            tier=tier,
            message=final_message,
            delayed_message=delayed_message,
            source=source,
            tafsir=tafsir
        )
    except Exception as e:
        logger.error(f"Error processing recommendation: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
