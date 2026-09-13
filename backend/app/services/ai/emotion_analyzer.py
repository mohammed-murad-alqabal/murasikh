import json
import google.generativeai as genai
from app.core.config import settings
from app.core.taxonomy import EMOTION_TAXONOMY

class EmotionAnalyzer:
    def __init__(self):
        if settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)
        self.model = genai.GenerativeModel('gemini-3.6-flash')
        
        # قائمة الحالات المتاحة (مشتقة من التاكسونومي)
        emotion_list = "، ".join(EMOTION_TAXONOMY.keys())
        
        self.system_prompt = f"""أنت خبير في التحليل النفسي الإسلامي. حلِّل النص التالي واستخرج الحالة العاطفية أو الإيمانية الأساسية.
الخيارات المتاحة: ({emotion_list}).
يجب أن يكون الرد بصيغة JSON فقط، يحتوي على مفتاحين حصراً:
1. "emotion": القيمة النصية للحالة من القائمة أعلاه بالضبط.
2. "confidence": رقم عشري من 0.0 إلى 1.0 يعبر عن شدة الانفعال أو يقين التصنيف.
لا تكتب أي نص آخر خارج الـ JSON."""

    async def analyze(self, text: str, user_context: dict = None) -> dict:
        try:
            if not settings.GEMINI_API_KEY:
                raise ValueError("No API_KEY provided")
            
            prompt = self.system_prompt + f"\nالنص: {text}"
            if user_context:
                if user_context.get("age"):
                    prompt += f"\n(معلومة: عمر المستخدم {user_context['age']} سنة)"
                if user_context.get("gender"):
                    g = "ذكر" if user_context["gender"] == "male" else "أنثى"
                    prompt += f"\n(معلومة: المستخدم {g})"
            
            response = self.model.generate_content(prompt)
            raw_text = response.text.strip().replace('```json', '').replace('```', '')
            result = json.loads(raw_text)
            
            # تحقق من أن الحالة ضمن القائمة المعتمدة
            if result.get("emotion") not in EMOTION_TAXONOMY:
                result["emotion"] = "طبيعي"
            return result
        except Exception as e:
            print(f"EmotionAnalyzer Fallback due to: {e}")
            return self._local_fallback_analyze(text)

    def _local_fallback_analyze(self, text: str) -> dict:
        text_lower = text.lower()
        # خريطة كلمات مفتاحية -> حالة
        keyword_map = [
            (["غاضب", "غضب", "مستفز", "معصب", "ثائر"], "غضب"),
            (["حزين", "ابكي", "اكتئاب", "زعلان", "حزن", "ضيق"], "حزن"),
            (["قلق", "خايف", "متوتر", "خوف", "مرعوب"], "قلق"),
            (["يائس", "مستحيل", "استسلم", "فقدت الأمل", "لا فائدة"], "يأس"),
            (["تعبان", "مرهق", "ارهاق", "مجهد", "منهك"], "إرهاق"),
            (["فرحان", "سعيد", "مبسوط", "بهجة"], "فرح"),
            (["شاكر", "الحمد لله", "ممتن", "شكر"], "شكر"),
            (["وحيد", "عزلة", "لا أحد", "وحده"], "وحدة"),
            (["مريض", "مرض", "علة", "آلام"], "مرض"),
            (["ذنب", "خطأت", "تبت", "ندمان"], "ذنب"),
            (["ظلم", "ظلمني", "مظلوم", "حق"], "ظلم"),
            (["توكلت", "بالله", "الله يعلم", "توكل"], "توكل"),
            (["استغفر", "أستغفر", "اللهم اغفر"], "استغفار"),
        ]
        for keywords, emotion in keyword_map:
            if any(w in text_lower for w in keywords):
                return {"emotion": emotion, "confidence": 0.75}
        return {"emotion": "طبيعي", "confidence": 0.0}

