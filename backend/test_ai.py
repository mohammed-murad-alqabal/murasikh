import asyncio
import json

from dotenv import load_dotenv

load_dotenv()

from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.notification.tiered_response import TieredResponse


async def run_test():
    analyzer = EmotionAnalyzer()
    tiered = TieredResponse()
    
    texts = [
        "أنا غاضب جداً، مديري يظلمني ولم أعد أحتمل!",
        "أشعر ببعض القلق بشأن امتحاني غداً، لكنني متفائل.",
    ]
    
    for t in texts:
        print(f"\n[نص المستخدم]: {t}")
        try:
            # 1. تحليل المشاعر عبر Gemini
            response = analyzer.model.generate_content(f"{analyzer.system_prompt}\nالنص: {t}")
            raw_text = response.text.strip().replace('```json', '').replace('```', '')
            print(f"[تحليل Gemini]: {raw_text}")
            
            emotion_data = json.loads(raw_text)
            emotion = emotion_data.get("emotion", "طبيعي")
            confidence = float(emotion_data.get("confidence", 0.0))
            
            # 2. تحديد مستوى الحماية
            tier = tiered.determine_tier(emotion, confidence)
            
            # 3. صياغة الرد
            if tier == 'minimal':
                res = tiered.get_minimal_response(emotion)
                res['confidence'] = confidence
            else:
                res = {
                    "emotion": emotion,
                    "confidence": confidence,
                    "tier": tier,
                    "message": "سيتم جلب آية للاطمئنان من قاعدة البيانات هنا."
                }
            print("[الرد النهائي للنظام]:")
            print(json.dumps(res, ensure_ascii=False, indent=2))
            
        except Exception as e:
            print(f"[خطأ في الاتصال]: {e}")

if __name__ == "__main__":
    asyncio.run(run_test())
