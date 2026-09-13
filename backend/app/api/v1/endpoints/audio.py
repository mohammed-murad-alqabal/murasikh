from fastapi import APIRouter, HTTPException, UploadFile, File
from app.services.ai.audio_analyzer import AudioAnalyzer
from app.api.v1.endpoints.recommend import RecommendationResponse, embedder, rag_engine, history_manager
from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES, EXTREME_EMOTIONS
import logging

router = APIRouter()
audio_analyzer = AudioAnalyzer()
logger = logging.getLogger(__name__)

@router.post("/analyze-audio", response_model=RecommendationResponse)
async def analyze_audio(file: UploadFile = File(...)):
    try:
        audio_bytes = await file.read()
        analysis = await audio_analyzer.analyze_tone(audio_bytes)
        
        emotion = analysis.get("emotion", "طبيعي")
        confidence = analysis.get("confidence", 0.7)
        
        if emotion == "طبيعي":
            msg = "يبدو من نبرة صوتك أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
            history_manager.add_record(
                input_text="رسالة صوتية", emotion=emotion, message=msg,
                source="سكينة واطمئنان", tafsir=None
            )
            return RecommendationResponse(
                emotion=emotion, confidence=confidence, tier="minimal", message=msg
            )
            
        semantic_query = EMOTION_SEMANTIC_QUERIES.get(emotion, "الصبر والطمأنينة والتوكل على الله")
        backend_context = history_manager.get_user_context()
        if backend_context:
            semantic_query = f"{semantic_query} {backend_context}"
            
        # بحث في القرآن حصراً مع البحث الهجين
        verse_results = embedder.search_similar(
            query=semantic_query,
            n_results=3,
            filters={"type": "verse"},
            emotion=emotion
        )
        
        source = None
        tafsir = None
        base_message = "اذكر الله يهدأ قلبك."
        
        if verse_results and verse_results.get('documents') and len(verse_results['documents'][0]) > 0:
            base_message = verse_results['documents'][0][0]
            metadata = verse_results['metadatas'][0][0]
            source = metadata.get("source")
            tafsir = metadata.get("tafsir")

        tier = "moderate"
        delayed_message = None
        user_text = f"أشعر بـ {emotion} (تم تحليله من نبرة الصوت)"
        
        if emotion in EXTREME_EMOTIONS:
            tier = "minimal"
            final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً."
            delayed_message = await rag_engine.format_response(
                user_text=user_text, emotion=emotion,
                retrieved_text=base_message, source=source, tafsir=tafsir
            )
        else:
            final_message = await rag_engine.format_response(
                user_text=user_text, emotion=emotion,
                retrieved_text=base_message, source=source, tafsir=tafsir
            )

        history_manager.add_record(
            input_text="رسالة صوتية", emotion=emotion,
            message=final_message, source=source, tafsir=tafsir
        )

        return RecommendationResponse(
            emotion=emotion, confidence=confidence, tier=tier,
            message=final_message, delayed_message=delayed_message,
            source=source, tafsir=tafsir
        )
    except Exception as e:
        logger.error(f"Error processing audio: {e}")
        raise HTTPException(status_code=500, detail=str(e))
