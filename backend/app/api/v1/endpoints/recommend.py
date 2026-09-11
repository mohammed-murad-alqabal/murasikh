from fastapi import APIRouter
from pydantic import BaseModel
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.notification.tiered_response import TieredResponse
from app.services.ai.embeddings import EmbeddingService

router = APIRouter()
analyzer = EmotionAnalyzer()
tiered = TieredResponse()
embedder = EmbeddingService()

class UserInput(BaseModel):
    text: str

@router.post("/analyze")
async def analyze_and_recommend(user_input: UserInput):
    # 1. تحليل المشاعر وشدتها عبر الذكاء الاصطناعي
    emotion_data = await analyzer.analyze(user_input.text)
    emotion = emotion_data.get("emotion", "طبيعي")
    confidence = float(emotion_data.get("confidence", 0.0))
    
    # 2. تحديد مستوى التدخل (الاستجابة المدرجة)
    tier = tiered.determine_tier(emotion, confidence)
    
    # 3. صياغة الرد המبدئي
    if tier == 'minimal':
        response = tiered.get_minimal_response(emotion)
        response['confidence'] = confidence
        return response
        
    # 4. البحث الدلالي (RAG) لجلب أفضل آية أو حديث يطابق الموقف
    results = embedder.search_similar(query=user_input.text, n_results=1)
    
    if results and results['documents'] and len(results['documents'][0]) > 0:
        best_match_text = results['documents'][0][0]
        metadata = results['metadatas'][0][0]
        
        return {
            "emotion": emotion,
            "confidence": confidence,
            "tier": tier,
            "content_type": metadata.get("type"),
            "text": best_match_text,
            "source": metadata.get("source"),
            "tafsir": metadata.get("tafsir", "") if tier == 'full' else "التفسير متاح عند الطلب"
        }
        
    return {
        "emotion": emotion,
        "confidence": confidence,
        "tier": tier,
        "message": "لم يتم العثور على نص مناسب في الوقت الحالي."
    }
