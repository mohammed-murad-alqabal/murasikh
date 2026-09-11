import json
import google.generativeai as genai
from app.core.config import settings

class EmotionAnalyzer:
    def __init__(self):
        # الاعتماد على Gemini للتحليل كما تم الاتفاق (لتقليل تكلفة الهاردوير)
        if settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)
            
        self.model = genai.GenerativeModel('gemini-1.5-flash')
        
        # هندسة الأوامر (Prompt Engineering) لضمان تحليل المشاعر فقط دون تأليف نصوص
        self.system_prompt = """
        أنت خبير في التحليل النفسي. قم بتحليل النص التالي واستخرج الحالة العاطفية الأساسية.
        الخيارات المتاحة للحالة: (غضب, حزن, قلق, فرح, توتر, يأس, طبيعي).
        يجب أن يكون الرد بصيغة JSON فقط، يحتوي على مفتاحين حصراً:
        1. "emotion": القيمة النصية للحالة.
        2. "confidence": رقم عشري من 0.0 إلى 1.0 يعبر عن شدة الانفعال (1.0 تعني انفعال شديد جداً).
        لا تكتب أي نص آخر خارج الـ JSON.
        """

    async def analyze(self, text: str) -> dict:
        try:
            # دمج الأمر مع نص المستخدم
            response = self.model.generate_content(f"{self.system_prompt}\nالنص: {text}")
            
            # تنظيف الرد لضمان كونه JSON صالح (إزالة علامات Markdown إذا أضافها النموذج)
            raw_text = response.text.strip().replace('```json', '').replace('```', '')
            
            return json.loads(raw_text)
        except Exception as e:
            # استجابة احتياطية في حال فشل الـ API لتجنب توقف النظام
            return {"emotion": "طبيعي", "confidence": 0.0}
