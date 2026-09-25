import json
import logging
import re

from google import genai

from app.core.config import settings
from app.core.taxonomy import EMOTION_TAXONOMY

logger = logging.getLogger(__name__)


class ConversationalAgent:
    def __init__(self):
        self._gemini_available = False
        if settings.GEMINI_API_KEY:
            try:
                self.client = genai.Client(
                    api_key=settings.GEMINI_API_KEY,
                    http_options=genai.types.HttpOptions(timeout=5000),
                )
                self.model_name = "gemini-3.6-flash"
                self._gemini_available = True
            except Exception as e:
                logger.error(f"Failed to configure Gemini for ConversationalAgent: {e}")

        emotion_list = "، ".join(EMOTION_TAXONOMY.keys())

        self.system_prompt = f"""أنت رفيق روحي إسلامي (Investigative Spiritual Assistant). هدفك فهم الحالة النفسية والإيمانية للمستخدم بعمق قبل تقديم التوجيه القرآني النهائي.
لديك وصول لسجل المحادثة الحالي.

الخيارات المتاحة للحالة: ({emotion_list}).

القواعد:
1. لا تستجوب المستخدم بلا داعٍ، اسأل فقط إذا كانت الإجابة ستؤثر فعلياً في فهم الحالة.
2. إذا كان كلام المستخدم الأخير يوضح حالته بشكل كافٍ (أو تراكمت معلومات كافية من السياق)، اتخذ القرار 'guide'.
3. إذا كانت رسالة المستخدم مبهمة جداً ولا تكفي لاختيار حالة دقيقة من القائمة، اتخذ القرار 'ask' واكتب سؤالاً لطيفاً لاستيضاح حالته.
4. يجب أن يكون ردك بصيغة JSON حصراً. لا تضف أي نص خارج كائن الـ JSON.

هيكل الـ JSON المطلوب:
{{
   "action": "ask | guide",
   "ai_message": "رسالتك للمستخدم (سواء سؤال أو رسالة مواساة تمهيداً للآية)",
   "emotion": "قيمة من القائمة المعتمدة",
   "confidence": 0.0 to 1.0
}}

أمثلة:
- المستخدم: "أشعر بضيق" -> {{"action": "ask", "ai_message": "أسأل الله أن يشرح صدرك. هل هذا الضيق بسبب موقف معين أم شعور عام؟", "emotion": "حزن", "confidence": 0.4}}
- المستخدم: "أنا مكتئب جداً لفقدان وظيفتي" -> {{"action": "guide", "ai_message": "أشعر بما تمر به من ألم لفقدان مصدر رزقك، لكن تذكر دائماً أن خزائن الله لا تنفد.", "emotion": "حزن", "confidence": 0.9}}
"""

    async def analyze(
        self,
        text: str,
        chat_history: list[dict] | None = None,
        user_context: dict | None = None,
    ) -> dict:
        def _redact(s: str) -> str:
            # Redact emails and phone numbers for privacy before sending to LLM
            s = re.sub(r'[\w\.-]+@[\w\.-]+', '[EMAIL_REDACTED]', s)
            s = re.sub(r'\b(?:\+?\d{1,3}[-\s]?)?\(?\d{3}\)?[-\s]?\d{3}[-\s]?\d{4}\b', '[PHONE_REDACTED]', s)
            return s

        try:
            if not self._gemini_available:
                raise ValueError("No API_KEY provided")

            prompt = self.system_prompt

            if user_context:
                prompt += "\n\n[سياق إضافي عن المستخدم]:\n"
                if user_context.get("age"):
                    prompt += f"- العمر: {user_context['age']} سنة\n"
                if user_context.get("gender"):
                    prompt += f"- الجنس: {'ذكر' if user_context['gender'] == 'male' else 'أنثى'}\n"
                if user_context.get("biometric_stress"):
                    prompt += "- مؤشرات حيوية: توتر جسدي أو نبض مرتفع\n"
                if user_context.get("facial_emotion"):
                    prompt += f"- ملامح الوجه: {user_context['facial_emotion']}\n"

            prompt += "\n[سجل المحادثة الأخير]:\n"
            if chat_history:
                for msg in chat_history:
                    role = "المستخدم" if msg["role"] == "user" else "المساعد"
                    prompt += f"{role}: {_redact(msg['content'])}\n"
            else:
                prompt += "(لا يوجد سجل سابق)\n"

            prompt += f"\nالرسالة الحالية للمستخدم:\n{_redact(text)}"

            import asyncio
            from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception_type

            @retry(
                stop=stop_after_attempt(3),
                wait=wait_exponential(multiplier=1, min=2, max=10),
                retry=retry_if_exception_type(Exception),
                reraise=True
            )
            def _call_gemini():
                return self.client.models.generate_content(
                    model=self.model_name,
                    contents=prompt,
                    config=genai.types.GenerateContentConfig(temperature=0.3),
                )

            # Phase 4: Timeouts & Retries
            async with asyncio.timeout(10.0):
                response = await asyncio.to_thread(_call_gemini)
                
            raw_text = response.text.strip()
            # fallback cleanup just in case
            if raw_text.startswith("```json"):
                raw_text = raw_text.replace("```json", "", 1)
            raw_text = raw_text.removesuffix("```")

            result = json.loads(raw_text.strip(), strict=False)

            if result.get("emotion") not in EMOTION_TAXONOMY:
                result["emotion"] = "طبيعي"

            return result
        except Exception as e:
            logger.error(f"ConversationalAgent Fallback due to: {e}")
            return self._local_fallback_analyze(text)

    def _local_fallback_analyze(self, text: str) -> dict:
        text_lower = text.lower()

        # كلمات غامضة تستدعي سؤالاً استقصائياً
        ambiguous_keywords = [
            "متعب",
            "تعب",
            "مش كويس",
            "مو كيفي",
            "مو زين",
            "ضيق",
            "مش تمام",
            "مو ماشي",
            "مو عارف",
            "ما أعرف",
            "تعبت",
            "خايس",
            "مو مرتاح",
            "محتاج مساعدة",
        ]
        for kw in ambiguous_keywords:
            if kw in text_lower:
                return {
                    "action": "ask",
                    "emotion": "إرهاق",
                    "confidence": 0.4,
                    "ai_message": "أسمعك.. هل هذا التعب جسدي من كثرة العمل، أم أنه إرهاق نفسي وضيق في القلب؟ تحدث معي أكثر لأتمكن من مساعدتك.",
                }

        keyword_map = [
            (["غاضب", "غضب", "مستفز", "معصب", "ثائر", "زعلان جداً"], "غضب"),
            (["حزين", "ابكي", "بكى", "اكتئاب", "زعلان", "حزن", "كآبة"], "حزن"),
            (["قلق", "خايف", "متوتر", "خوف", "مرعوب", "توتر"], "قلق"),
            (
                [
                    "يائس",
                    "يأس",
                    "مستحيل",
                    "استسلم",
                    "فقدت الأمل",
                    "لا فائدة",
                    "ما في أمل",
                ],
                "يأس",
            ),
            (["تعبان", "مرهق", "ارهاق", "مجهد", "منهك"], "إرهاق"),
            (["فرحان", "سعيد", "مبسوط", "بهجة", "مسرور"], "فرح"),
            (["شاكر", "الحمد لله", "ممتن", "شكر"], "شكر"),
            (["وحيد", "عزلة", "لا أحد", "وحده", "وحدتي"], "وحدة"),
            (["مريض", "مرض", "علة", "آلام", "ألم"], "مرض"),
            (["ذنب", "خطأت", "تبت", "ندمان", "أندم"], "ذنب"),
            (["ظلم", "ظلمني", "مظلوم", "حق"], "ظلم"),
            (["توكلت", "توكل على الله", "الله يعلم"], "توكل"),
            (["استغفر", "أستغفر", "اللهم اغفر", "استغفار"], "استغفار"),
        ]
        for keywords, emotion in keyword_map:
            if any(w in text_lower for w in keywords):
                return {
                    "action": "guide",
                    "emotion": emotion,
                    "confidence": 0.75,
                    "ai_message": f"أسمعك، وأشعر بـ {emotion} الذي تمر به. وتذكر دائماً كلام الله في هذا الموقف:",
                }
        # لا توجد كلمات مفتاحية واضحة → اسأل
        return {
            "action": "ask",
            "emotion": "طبيعي",
            "confidence": 0.3,
            "ai_message": "يسعدني أن أكون بجانبك. هل تودّ مشاركتي ما يدور في خاطرك أو يشغل تفكيرك؟",
        }
