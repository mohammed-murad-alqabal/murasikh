from fastapi import APIRouter
from pydantic import BaseModel
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.notification.tiered_response import TieredResponse

router = APIRouter()
analyzer = EmotionAnalyzer()
tiered = TieredResponse()

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
    
    # 3. صياغة الرد المبدئي
    if tier == 'minimal':
        response = tiered.get_minimal_response(emotion)
        response['confidence'] = confidence
        return response
        
    # هنا سيتم لاحقاً حقن (RAG) لجلب الآية من قاعدة البيانات للـ (Moderate & Full)
    return {
        "emotion": emotion,
        "confidence": confidence,
        "tier": tier,
        "message": "سيقوم محرك البحث الدلالي بجلب الآية أو الحديث المناسب هنا."
    }
