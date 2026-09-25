import logging
import asyncio
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.v1.endpoints.auth import get_current_user_optional
from app.schemas.common import UserContextSchema
from app.core.security import limiter
from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES, EXTREME_EMOTIONS
from app.db.database import get_db
from app.services.ai.conversational_agent import ConversationalAgent
from app.services.ai.embeddings import EmbeddingService
from app.services.ai.rag_engine import RAGEngine
from app.services.delayed_response_service import DelayedResponseService
from app.services.history_manager import HistoryService

router = APIRouter()
agent = ConversationalAgent()
embedder = EmbeddingService()
rag_engine = RAGEngine()
logger = logging.getLogger(__name__)


class ChatHistoryMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(..., min_length=1, max_length=2000)


class RecommendationRequest(BaseModel):
    text: str = Field(
        ..., min_length=2, max_length=1000, description="نص المستخدم المراد تحليله"
    )
    user_context: UserContextSchema | None = Field(
        None, description="السياق الإضافي للمستخدم"
    )
    idempotency_key: str | None = Field(
        None, description="مفتاح فريد لمنع تكرار الطلب (Idempotency Key)"
    )
    chat_history: list[ChatHistoryMessage] = Field(
        default_factory=list,
        max_length=10,
        description="آخر رسائل الجلسة للضيف أو السياق غير المتزامن",
    )


class RecommendationResponse(BaseModel):
    emotion: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    tier: str
    message: str
    delayed_message: str | None = None
    source: str | None = None
    tafsir: str | None = None
    interaction_id: int | None = None


@router.post("", response_model=RecommendationResponse)
@limiter.limit("15/minute")
async def get_recommendation(
    request: Request,
    payload: RecommendationRequest,
    user: dict | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    # 0. Idempotency Check
    cache = None
    try:
        from app.services.cache.redis_cache import RedisCache
        cache = RedisCache()
    except Exception:
        pass
        
    if cache and payload.idempotency_key:
        cache_key = f"idemp_rec:{payload.idempotency_key}"
        try:
            cached_res = cache.get(cache_key)
            if cached_res:
                return RecommendationResponse(**cached_res)
        except Exception as e:
            logger.warning(f"Redis idempotency check failed: {e}")

    try:
        history_service = HistoryService(db)

        # 1. جلب سياق المحادثة السابق إذا كان المستخدم مسجلاً
        chat_history = []
        if user:
            recent_interactions = history_service.get_history(user["id"], limit=5)
            # Order from oldest to newest for context
            for interaction in reversed(recent_interactions):
                chat_history.append(
                    {"role": "user", "content": interaction["input_text"]}
                )
                # if there is an AI response in history, add it too
                if interaction.get("recommendation") and interaction[
                    "recommendation"
                ].get("message"):
                    chat_history.append(
                        {
                            "role": "ai",
                            "content": interaction["recommendation"]["message"],
                        }
                    )
        elif payload.chat_history:
            # Guest sessions have no server-side memory. Accept only the
            # bounded, validated client transcript for this request.
            chat_history = [message.model_dump() for message in payload.chat_history]

        # 2. تحليل الحالة العاطفية والموقف (الوكيل الاستقصائي)
        raw_context = (
            payload.user_context.model_dump(exclude_none=True)
            if payload.user_context
            else {}
        )
        context_consent = raw_context.pop("sensitive_context_consent", False)
        # Do not send age, gender, facial signals, or biometric stress to an
        # external model unless the user explicitly opted in for this request.
        context_dict = raw_context if context_consent else {}
        analysis = await agent.analyze(
            payload.text, chat_history=chat_history, user_context=context_dict
        )

        action = analysis.get("action", "guide")
        emotion = analysis.get("emotion", "طبيعي")
        confidence = max(0.0, min(1.0, float(analysis.get("confidence", 0.0))))
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
                    tafsir=None,
                    confidence=confidence,
                    response_tier="minimal",
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
                    user_id=user["id"],
                    input_text=payload.text,
                    emotion=emotion,
                    message=ai_message,
                    source="سكينة واطمئنان",
                    tafsir=None,
                )
                interaction_id = interaction.id
            return RecommendationResponse(
                emotion=emotion,
                confidence=confidence,
                tier="minimal",
                message=ai_message,
                interaction_id=interaction_id,
            )

        # 3. بناء استعلام دلالي محسَّن للحالة
        semantic_query = EMOTION_SEMANTIC_QUERIES.get(
            emotion, f"الصبر والطمأنينة والتوكل على الله {payload.text}"
        )

        backend_context = history_service.get_user_context(user["id"]) if user else ""
        if backend_context:
            semantic_query = f"{semantic_query} {backend_context}"

        if payload.user_context:
            ctx = context_dict or {}
            if ctx.get("age"):
                semantic_query += f" العمر: {ctx['age']}"
            if ctx.get("gender"):
                semantic_query += f" الجنس: {ctx['gender']}"

        # 4. البحث في القرآن الكريم
        verse_results = await asyncio.to_thread(
            embedder.search_similar,
            query=semantic_query,
            n_results=3,
            filters={"type": "verse"},
            emotion=emotion,
        )

        source = None
        tafsir = None
        base_message = "اذكر الله يهدأ قلبك."

        if (
            verse_results
            and verse_results.get("documents")
            and len(verse_results["documents"][0]) > 0
        ):
            verses_list = []
            for i in range(len(verse_results["documents"][0])):
                verses_list.append(
                    {
                        "text": verse_results["documents"][0][i],
                        "source": verse_results["metadatas"][0][i].get("source", ""),
                        "tafsir": verse_results["metadatas"][0][i].get("tafsir", ""),
                    }
                )

            best_verse = await rag_engine.select_best_verse(
                user_text=payload.text, emotion=emotion, verses=verses_list
            )

            base_message = best_verse.get("text", "")
            source = best_verse.get("source", "")
            tafsir = best_verse.get("tafsir", "")

        # 5. صياغة الرد الدافئ
        tier = "moderate"
        delayed_message = None
        should_delay = emotion in EXTREME_EMOTIONS and confidence > 0.85

        if emotion in EXTREME_EMOTIONS:
            tier = "minimal"
            if should_delay:
                final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً."
                delayed_message = await rag_engine.format_response(
                    user_text=payload.text,
                    emotion=emotion,
                    retrieved_text=base_message,
                    source=source,
                    tafsir=tafsir,
                )
            elif ai_message:
                final_message = (
                    ai_message + f"\n\n📖 {source}\n{base_message}"
                    if source
                    else ai_message
                )
            else:
                final_message = await rag_engine.format_response(
                    user_text=payload.text,
                    emotion=emotion,
                    retrieved_text=base_message,
                    source=source,
                    tafsir=tafsir,
                )
        else:
            # إذا وفر الوكيل رسالة دافئة، ندمجها مع الآية المسترجعة لتقليل طلبات Gemini
            if ai_message:
                final_message = (
                    ai_message + f"\n\n📖 {source}\n{base_message}"
                    if source
                    else ai_message
                )
            else:
                final_message = await rag_engine.format_response(
                    user_text=payload.text,
                    emotion=emotion,
                    retrieved_text=base_message,
                    source=source,
                    tafsir=tafsir,
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
                tafsir=tafsir,
                confidence=confidence,
                response_tier=tier,
                response_delayed=bool(delayed_message and should_delay),
                commit=not (delayed_message and should_delay),
            )
            interaction_id = interaction.id

            if delayed_message and should_delay:
                DelayedResponseService(db).schedule(
                    user_id=user["id"],
                    interaction_id=interaction.id,
                    payload={
                        "emotion": emotion,
                        "confidence": confidence,
                        "tier": "full",
                        "message": delayed_message,
                        "source": source,
                        "tafsir": tafsir,
                    },
                    commit=False,
                )
                db.commit()
                db.refresh(interaction)

        response = RecommendationResponse(
            emotion=emotion,
            confidence=confidence,
            tier=tier,
            message=final_message,
            delayed_message=None,
            source=source,
            tafsir=tafsir,
            interaction_id=interaction_id,
        )

        if cache and payload.idempotency_key:
            try:
                # Cache successful responses for 24h to prevent duplicates
                cache_key = f"idemp_rec:{payload.idempotency_key}"
                cache.set(cache_key, response.model_dump(), ttl=86400)
            except Exception as e:
                logger.warning(f"Failed to cache idempotency key: {e}")

        return response
    except Exception as e:
        logger.error(f"Error processing recommendation: {e}")
        db.rollback()
        raise HTTPException(status_code=500, detail="Internal Server Error")
