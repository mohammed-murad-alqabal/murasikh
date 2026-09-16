import json
import logging
import google.generativeai as genai
from app.core.config import settings
from app.core.taxonomy import EMOTION_TAXONOMY

logger = logging.getLogger(__name__)

class ConversationalAgent:
    def __init__(self):
        self._gemini_available = False
        if settings.GEMINI_API_KEY:
            try:
                genai.configure(api_key=settings.GEMINI_API_KEY)
                self.model = genai.GenerativeModel('gemini-3.6-flash')
                self._gemini_available = True
            except Exception as e:
                logger.error(f"Failed to configure Gemini for ConversationalAgent: {e}")
        
        emotion_list = "، ".join(EMOTION_TAXONOMY.keys())
        
        self.system_prompt = f"""أنت رفيق روحي إسلامي (Investigative Spiritual Assistant). هدفك فهم الحالة النفسية والإيمانية للمستخدم بعمق قبل تقديم التوجيه القرآني النهائي.
لديك وصول لسجل المحادثة الحالي.

الخيارات المتاحة للحالة: ({emotion_list}).

القواعد:
1. لا تستجوب المستخدم بلا داعٍ، اسأل فقط إذا كانت الإجابة ستؤثر فعلياً في فهم الحالة.
2. إذا كان كلام المستخدم الأخير يوضح حالته بشكل كافٍ (أو إذا تراكمت لديك معلومات كافية من السياق السابق)، اتخذ القرار 'guide'.
3. إذا كانت رسالة المستخدم مبهمة جداً ولا تكفي لاختيار حالة دقيقة من القائمة، اتخذ القرار 'ask' واكتب سؤالاً لطيفاً لاستيضاح حالته.
4. يجب أن يكون ردك بصيغة JSON حصراً، يحتوي على:
   - "action": إما "ask" (لطلب توضيح) أو "guide" (لتقديم الإرشاد).
   - "ai_message": رسالتك للمستخدم (سواء كانت سؤالاً توضيحياً أو رسالة مواساة وتوجيه نهائية تمهيداً لعرض الآية).
   - "emotion": القيمة النصية للحالة من القائمة المعتمدة (إذا كان action=ask، ضع أقرب حالة محتملة).
   - "confidence": رقم عشري من 0.0 إلى 1.0.

أمثلة:
- المستخدم: "أشعر بضيق" -> action: ask, ai_message: "أسأل الله أن يشرح صدرك. هل هذا الضيق بسبب موقف معين أم أنه شعور عام بالتعب والإرهاق؟", emotion: حزن, confidence: 0.4
- المستخدم: "أنا مكتئب جداً لفقدان وظيفتي" -> action: guide, ai_message: "أشعر بما تمر به من ألم لفقدان مصدر رزقك، لكن تذكر دائماً أن خزائن الله لا تنفد.", emotion: حزن, confidence: 0.9

لا تكتب أي نص آخر خارج الـ JSON.
"""

    async def analyze(self, text: str, chat_history: list[dict] = None, user_context: dict = None) -> dict:
        try:
            if not self._gemini_available:
                raise ValueError("No API_KEY provided")
            
            prompt = self.system_prompt
            
            if user_context:
                prompt += "\n\n[سياق إضافي عن المستخدم]:\n"
                if user_context.get("age"): prompt += f"- العمر: {user_context['age']} سنة\n"
                if user_context.get("gender"): prompt += f"- الجنس: {'ذكر' if user_context['gender'] == 'male' else 'أنثى'}\n"
                if user_context.get("biometric_stress"): prompt += f"- مؤشرات حيوية: توتر جسدي أو نبض مرتفع\n"
                if user_context.get("facial_emotion"): prompt += f"- ملامح الوجه: {user_context['facial_emotion']}\n"
            
            prompt += "\n[سجل المحادثة الأخير]:\n"
            if chat_history:
                for msg in chat_history:
                    role = "المستخدم" if msg['role'] == 'user' else "المساعد"
                    prompt += f"{role}: {msg['content']}\n"
            else:
                prompt += "(لا يوجد سجل سابق)\n"
                
            prompt += f"\nالرسالة الحالية للمستخدم:\n{text}\n\nأصدر JSON الآن:"
            
            import asyncio
            response = await asyncio.to_thread(
                self.model.generate_content,
                prompt,
                generation_config=genai.GenerationConfig(temperature=0.3)
            )
            raw_text = response.text.strip().replace('```json', '').replace('```', '')
            result = json.loads(raw_text)
            
            if result.get("emotion") not in EMOTION_TAXONOMY:
                result["emotion"] = "طبيعي"
                
            return result
        except Exception as e:
            logger.error(f"ConversationalAgent Fallback due to: {e}")
            return self._local_fallback_analyze(text)

    def _local_fallback_analyze(self, text: str) -> dict:
        text_lower = text.lower()
        keyword_map = [
            (["غاضب", "غضب", "مستفز", "معصب", "ثائر"], "غضب"),
            (["حزين", "ابكي", "اكتئاب", "زعلان", "حزن", "ضيق"], "حزن"),
            (["قلق", "خايف", "متوتر", "خوف", "مرعوب"], "قلق"),
            (["يائس", "يأس", "مستحيل", "استسلم", "فقدت الأمل", "لا فائدة"], "يأس"),
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
                return {
                    "action": "guide",
                    "emotion": emotion,
                    "confidence": 0.75,
                    "ai_message": f"أسمعك، وأشعر بـ {emotion} الذي تمر به. وتذكر دائماً كلام الله في هذا الموقف:"
                }
        return {
            "action": "guide",
            "emotion": "طبيعي",
            "confidence": 0.0,
            "ai_message": "يبدو أن الأمور هادئة بفضل الله. استمر في يومك بذكر الله."
        }
