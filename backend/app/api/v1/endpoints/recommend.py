import logging

from fastapi import APIRouter, HTTPException, Request, Depends
from sqlalchemy.orm import Session
from app.api.v1.endpoints.auth import get_current_user_optional
from app.db.database import get_db
from pydantic import BaseModel, Field

from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES, EXTREME_EMOTIONS
from app.services.ai.embeddings import EmbeddingService
from app.services.ai.conversational_agent import ConversationalAgent
from app.services.ai.rag_engine import RAGEngine
from app.services.history_manager import HistoryService
from app.core.security import limiter

router = APIRouter()
agent = ConversationalAgent()
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
    interaction_id: int | None = None

@router.post("", response_model=RecommendationResponse)
@limiter.limit("15/minute")
async def get_recommendation(request: Request, payload: RecommendationRequest, user: dict | None = Depends(get_current_user_optional), db: Session = Depends(get_db)):
    try:
        history_service = HistoryService(db)
        
        # 1. جلب سياق المحادثة السابق إذا كان المستخدم مسجلاً
        chat_history = []
        if user:
            recent_interactions = history_service.get_history(user["id"])[:5]
            # Order from oldest to newest for context
            for interaction in reversed(recent_interactions):
                chat_history.append({"role": "user", "content": interaction["input_text"]})
                # if there is an AI response in history, add it too
                if interaction.get("recommendation") and interaction["recommendation"].get("message"):
                    chat_history.append({"role": "ai", "content": interaction["recommendation"]["message"]})

        # 2. تحليل الحالة العاطفية والموقف (الوكيل الاستقصائي)
        analysis = await agent.analyze(payload.text, chat_history=chat_history, user_context=payload.user_context)
        
        action = analysis.get("action", "guide")
        emotion = analysis.get("emotion", "طبيعي")
        confidence = float(analysis.get("confidence", 0.0))
        ai_message = analysis.get("ai_message", "")

        if action == "ask":
            # الوكيل قرر طرح سؤال توضيحي. لا حاجة لجلب آيات حالياً.
            final_message = ai_message
            if not final_message:
                final_message = "هل يمكنك توضيح ما تشعر به أكثر لنتمكن من المساعدة؟"
                
            interaction_id = None
            if user:
                interaction = history_service.add_record(
                    user_id=user["id"],
                    input_text=payload.text,
                    emotion=emotion,
                    message=final_message,
                    source=None,
                    tafsir=None
                )
                interaction_id = interaction.id
                
            return RecommendationResponse(
                emotion=emotion,
                confidence=confidence,
                tier="minimal",
                message=final_message,
                source=None,
                tafsir=None,
                interaction_id=interaction_id,
            )

        # إذا كان القرار هو الإرشاد (guide)
        if emotion == "طبيعي" and not ai_message:
            ai_message = "يبدو أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
            interaction_id = None
            if user:
                interaction = history_service.add_record(
                    user_id=user["id"], input_text=payload.text, emotion=emotion, message=ai_message, source="سكينة واطمئنان", tafsir=None
                )
                interaction_id = interaction.id
            return RecommendationResponse(emotion=emotion, confidence=confidence, tier="minimal", message=ai_message, interaction_id=interaction_id)

        # 3. بناء استعلام دلالي محسَّن للحالة
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

        # 4. البحث في القرآن الكريم
        verse_results = embedder.search_similar(
            query=semantic_query,
            n_results=3,
            filters={"type": "verse"},
            emotion=emotion
        )

        source = None
        tafsir = None
        base_message = "اذكر الله يهدأ قلبك."

        if (verse_results and verse_results.get('documents') and len(verse_results['documents'][0]) > 0):
            verses_list = []
            for i in range(len(verse_results['documents'][0])):
                verses_list.append({
                    "text": verse_results['documents'][0][i],
                    "source": verse_results['metadatas'][0][i].get("source", ""),
                    "tafsir": verse_results['metadatas'][0][i].get("tafsir", "")
                })
            
            best_verse = await rag_engine.select_best_verse(
                user_text=payload.text,
                emotion=emotion,
                verses=verses_list
            )
            
            base_message = best_verse.get("text", "")
            source = best_verse.get("source", "")
            tafsir = best_verse.get("tafsir", "")

        # 5. صياغة الرد الدافئ
        tier = "moderate"
        delayed_message = None

        if emotion in EXTREME_EMOTIONS:
            tier = "minimal"
            final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً."
            if ai_message:
                final_message = ai_message + f"\n\n📖 {source}\n{base_message}" if source else ai_message
            else:
                delayed_message = await rag_engine.format_response(
                    user_text=payload.text, emotion=emotion, retrieved_text=base_message, source=source, tafsir=tafsir
                )
        else:
            # إذا وفر الوكيل رسالة دافئة، ندمجها مع الآية المسترجعة لتقليل طلبات Gemini
            if ai_message:
                final_message = ai_message + f"\n\n📖 {source}\n{base_message}" if source else ai_message
            else:
                final_message = await rag_engine.format_response(
                    user_text=payload.text, emotion=emotion, retrieved_text=base_message, source=source, tafsir=tafsir
                )

        # 6. حفظ التفاعل
        interaction_id = None
        if user:
            interaction = history_service.add_record(
                user_id=user["id"],
                input_text=payload.text,
                emotion=emotion,
                message=final_message,
                source=source,
                tafsir=tafsir
            )
            interaction_id = interaction.id

        return RecommendationResponse(
            emotion=emotion,
            confidence=confidence,
            tier=tier,
            message=final_message,
            delayed_message=delayed_message,
            source=source,
            tafsir=tafsir,
            interaction_id=interaction_id
        )
    except Exception as e:
        logger.error(f"Error processing recommendation: {e}")
        raise HTTPException(status_code=500, detail="Internal Server Error")
