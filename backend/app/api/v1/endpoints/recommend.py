from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.ai.embeddings import EmbeddingService
from app.services.history_manager import HistoryManager
import logging

router = APIRouter()
analyzer = EmotionAnalyzer()
embedder = EmbeddingService()
history_manager = HistoryManager()
logger = logging.getLogger(__name__)

class RecommendationRequest(BaseModel):
    text: str
    user_context: Optional[str] = None 

class RecommendationResponse(BaseModel):
    emotion: str
    confidence: float
    tier: str
    message: str
    delayed_message: Optional[str] = None
    source: Optional[str] = None
    tafsir: Optional[str] = None

@router.post("", response_model=RecommendationResponse)
async def get_recommendation(request: RecommendationRequest):
    try:
        # 1. Analyze emotion from text
        analysis = await analyzer.analyze(request.text)
        emotion = analysis.get("emotion", "طبيعي")
        confidence = float(analysis.get("confidence", 0.0))
        
        if emotion == "طبيعي":
            return RecommendationResponse(
                emotion=emotion,
                confidence=confidence,
                tier="minimal",
                message="يبدو أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
            )
            
        # 2. Add backend context
        backend_context = history_manager.get_user_context()
        combined_text = request.text
        if backend_context:
            combined_text = f"Context: {backend_context}. Query: {request.text}"
            
        results = embedder.search_similar(query=request.text, n_results=1)
        
        source = None
        tafsir = None
        base_message = "اذكر الله يهدأ قلبك."
        
        if results and results['documents'] and len(results['documents'][0]) > 0:
            base_message = results['documents'][0][0]
            metadata = results['metadatas'][0][0]
            source = metadata.get("source")
            tafsir = metadata.get("tafsir")

        tier = "moderate"
        delayed_message = None
        
        # FR-8: Delayed Responses for extreme emotions
        if emotion in ["غضب", "حزن شديد", "إجهاد أو حزن", "يأس", "غضب شديد"]:
            tier = "minimal" 
            final_message = "تعوذ بالله من الشيطان الرجيم، وخذ نفساً عميقاً. (رسالة التهدئة الفورية)"
            delayed_message = f"أهلاً بك مجدداً، أتمنى أن تكون الآن أكثر هدوءاً. تذكر قول الله تعالى: {base_message}"
        else:
            final_message = base_message

        # Save to backend history automatically (so background Android Service records too)
        history_manager.add_record(
            input_text=request.text, 
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
