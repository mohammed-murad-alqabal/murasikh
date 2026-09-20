import json
import logging
import asyncio

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.api.v1.endpoints.auth import get_current_user_optional
from app.schemas.common import UserContextSchema
from app.api.v1.endpoints.recommend import (
    RecommendationResponse,
    embedder,
    rag_engine,
)
from app.core.security import limiter
from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES, EXTREME_EMOTIONS
from app.db.database import get_db
from app.services.ai.audio_analyzer import AudioAnalyzer
from app.services.delayed_response_service import DelayedResponseService
from app.services.history_manager import HistoryService

router = APIRouter()
audio_analyzer = AudioAnalyzer()
logger = logging.getLogger(__name__)


def check_magic_bytes(header_bytes: bytes) -> bool:
    """Validate the file signature instead of trusting the client MIME type."""
    if header_bytes.startswith(b"RIFF"):
        return b"WAVE" in header_bytes[:12]
    if header_bytes.startswith((b"OggS", b"\x1a\x45\xdf\xa3")):
        return True
    if header_bytes.startswith((b"ID3", b"\xff\xfb", b"\xff\xf3")):
        return True
    return b"ftyp" in header_bytes[:12]


MAX_AUDIO_BYTES = 10 * 1024 * 1024
ALLOWED_AUDIO_TYPES = {
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/webm",
    "audio/mp4",
    "audio/x-m4a",
}


@router.post("/analyze-audio", response_model=RecommendationResponse)
@limiter.limit("5/minute")
async def analyze_audio(
    request: Request,
    file: UploadFile = File(...),
    user_context: str = Form(None),
    user: dict | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
):
    try:
        if file.content_type not in ALLOWED_AUDIO_TYPES:
            raise HTTPException(
                status_code=415, detail="Unsupported audio content type"
            )

        audio_bytes = await file.read(MAX_AUDIO_BYTES + 1)
        if not audio_bytes:
            raise HTTPException(status_code=400, detail="Audio file is empty")
        if len(audio_bytes) > MAX_AUDIO_BYTES:
            raise HTTPException(
                status_code=413, detail="Audio file exceeds the 10 MB limit"
            )

        if not check_magic_bytes(audio_bytes[:12]):
            raise HTTPException(status_code=415, detail="Invalid audio file format")

        context_dict = None
        if user_context:
            try:
                raw_context = json.loads(user_context)
            except json.JSONDecodeError as exc:
                raise HTTPException(
                    status_code=400, detail="Invalid JSON in user_context"
                ) from exc
            try:
                context_dict = UserContextSchema.model_validate(raw_context).model_dump(
                    exclude_none=True
                )
            except ValidationError as exc:
                raise HTTPException(status_code=422, detail=exc.errors()) from exc

        analysis = await audio_analyzer.analyze_tone(audio_bytes)

        emotion = analysis.get("emotion", "طبيعي")
        confidence = analysis.get("confidence", 0.7)

        history_service = HistoryService(db)
        if emotion == "طبيعي":
            msg = (
                "يبدو من نبرة صوتك أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
            )
            interaction_id = None
            if user:
                interaction = history_service.add_record(
                    user_id=user["id"],
                    input_text="رسالة صوتية",
                    emotion=emotion,
                    message=msg,
                    source="سكينة واطمئنان",
                    tafsir=None,
                )
                interaction_id = interaction.id
            return RecommendationResponse(
                emotion=emotion,
                confidence=confidence,
                tier="minimal",
                message=msg,
                interaction_id=interaction_id,
            )

        semantic_query = EMOTION_SEMANTIC_QUERIES.get(
            emotion, "الصبر والطمأنينة والتوكل على الله"
        )
        backend_context = history_service.get_user_context(user["id"]) if user else ""
        if backend_context:
            semantic_query = f"{semantic_query} {backend_context}"

        if context_dict:
            if context_dict.get("age"):
                semantic_query += f" العمر: {context_dict['age']}"
            if context_dict.get("gender"):
                semantic_query += f" الجنس: {context_dict['gender']}"
            if context_dict.get("biometric_stress"):
                semantic_query += " يعاني من توتر جسدي أو نبض مرتفع"
            if context_dict.get("facial_emotion"):
                semantic_query += f" وملامح وجهه تظهر {context_dict['facial_emotion']}"

        # بحث في القرآن حصراً مع البحث الهجين
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
                user_text=f"أشعر بـ {emotion} استناداً لنبرة صوتي",
                emotion=emotion,
                verses=verses_list,
            )

            base_message = best_verse.get("text", "")
            source = best_verse.get("source", "")
            tafsir = best_verse.get("tafsir", "")

        tier = "moderate"
        delayed_message = None
        should_delay = emotion in EXTREME_EMOTIONS and confidence > 0.85
        user_text = f"أشعر بـ {emotion} (تم تحليله من نبرة الصوت)"

        if emotion in EXTREME_EMOTIONS:
            tier = "minimal"
            if should_delay:
                final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً."
                delayed_message = await rag_engine.format_response(
                    user_text=user_text,
                    emotion=emotion,
                    retrieved_text=base_message,
                    source=source,
                    tafsir=tafsir,
                )
            else:
                final_message = await rag_engine.format_response(
                    user_text=user_text,
                    emotion=emotion,
                    retrieved_text=base_message,
                    source=source,
                    tafsir=tafsir,
                )
        else:
            final_message = await rag_engine.format_response(
                user_text=user_text,
                emotion=emotion,
                retrieved_text=base_message,
                source=source,
                tafsir=tafsir,
            )

        interaction_id = None
        if user:
            interaction = history_service.add_record(
                user_id=user["id"],
                input_text="رسالة صوتية",
                emotion=emotion,
                message=final_message,
                source=source,
                tafsir=tafsir,
                confidence=confidence,
                response_tier=tier,
                response_delayed=bool(delayed_message and should_delay),
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
                )

        return RecommendationResponse(
            emotion=emotion,
            confidence=confidence,
            tier=tier,
            message=final_message,
            delayed_message=None,
            source=source,
            tafsir=tafsir,
            interaction_id=interaction_id,
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing audio: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Internal Server Error")
