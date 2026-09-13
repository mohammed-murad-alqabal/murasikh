import google.generativeai as genai
from app.core.config import settings
import random

class RAGEngine:
    """
    محرك الصياغة الدافئة (Empathetic Formatting):
    - عند توفر Gemini: يستخدمه للصياغة الدافئة المخصصة
    - عند نفاذ الحصة أو الخطأ: يستخدم قوالب برمجية دافئة ومتنوعة
    """

    # قوالب مواساة دافئة لكل شعور (تُستخدم عند عدم توفر Gemini)
    WARM_TEMPLATES = {
        "غضب": [
            "أخي الكريم، الغضب طبيعي لكن السيطرة عليه هي قوة الأقوياء. تذكر قول الله:",
            "عندما يأخذ الغضب منك، توقف ونفّس.. وتذكر وصية ربك:",
            "لحظات الغضب تمر، وما يبقى هو ما قدّمته لله. قال تعالى:",
        ],
        "حزن": [
            "أعلم أن قلبك ثقيل الآن، لكن الله لم ينسَك. تذكر:",
            "الحزن لا يدوم إلى الأبد، وربك معك في كل لحظة. قال الله:",
            "دموعك أمانة عند الله، واصبر على هذا الألم. تذكر وعده:",
        ],
        "قلق": [
            "لا تُتعب قلبك بما لم يأتِ، فالغد بيد الله وحده. قال تعالى:",
            "القلق من المستقبل يُثقل، لكن التوكل على الله يُريح. تذكر:",
            "أسلم أمرك لله وارتح.. قال سبحانه:",
        ],
        "يأس": [
            "مهما اشتد الظلام فالفجر آتٍ. لا تيأس من رحمة الله أبداً:",
            "باب الله لا يُغلق في وجه أحد. تذكر وعده الكريم:",
            "رحمة الله أوسع من كل ذنب وكل ألم. قال جل جلاله:",
        ],
        "توتر": [
            "خذ نفساً عميقاً.. الله معك والفرج قريب. تذكر وعده:",
            "بعد كل ضيق يأتي الفرج، هذه سنة الله. قال تعالى:",
            "الصعوبات مؤقتة واليسر آتٍ بإذن الله:",
        ],
        "إرهاق": [
            "أنت بحاجة للراحة، والله رحيم لا يكلف نفساً فوق طاقتها. تذكر:",
            "خفف على نفسك، فربك يعلم طاقتك وحدودك. قال تعالى:",
            "الإرهاق يمر، واللطيف بعباده يعلم حالك:",
        ],
        "خوف": [
            "الله معك، فمن تخاف؟ تذكر وعده لك:",
            "الخوف يزول بتذكر أن الله حافظ وراعٍ. قال جل جلاله:",
            "لست وحدك في مواجهة مخاوفك، فالله سميع بصير:",
        ],
        "ذنب": [
            "رحمة الله أكبر من كل خطيئة، فتُب إليه ولا تقنط. قال تعالى:",
            "الله يفرح بتوبة عبده أكثر منك بتوبتك. تذكر:",
            "كل بني آدم خطاء وخير الخطائين التوابون. قال الله:",
        ],
        "فرح": [
            "الحمد لله على هذه النعمة، واشكر ربك دائماً. تذكر:",
            "الفرح المباح نعمة من الله، فاشكره عليها:",
            "بشّرك الله بالمزيد إن شكرت. تذكر وعده:",
        ],
        "شكر": [
            "شكر الله من أسمى العبادات. تذكر وعده للشاكرين:",
            "لسانك بالشكر يفتح أبواباً من النعم. قال تعالى:",
            "الله يحب الشاكرين ويزيدهم. تذكر:",
        ],
        "حيرة": [
            "عندما تضيق بك الطرق، استعن بالله وتوكل عليه. قال تعالى:",
            "الحل عند الله، فاستشره في صلاتك واسترح:",
            "التوكل على الله يفتح أبواباً لا تراها الآن:",
        ],
        "مرض": [
            "الشفاء بيد الله وحده، وكل ألم يمحو ذنباً. تذكر:",
            "المرض كفارة وابتلاء، والله يأجرك على صبرك. قال تعالى:",
            "دعاؤك واحتسابك دواء. تذكر وعد ربك:",
        ],
        "طبيعي": [
            "الحمد لله على العافية. تذكر شكر ربك:",
            "اليوم الهادئ نعمة، فاغتنمه بذكر الله:",
        ],
    }

    FORMATTING_PROMPT = """
أنت رفيق إسلامي دافئ وحنون تواسي المستخدم بناءً على مشاعره.
لقد شاركك المستخدم مشاعره التالية:
"{user_text}"

وتم تشخيص حالته العاطفية بـ: {emotion}

وهذا هو النص الشرعي (آية أو حديث) المخصص لمواساته:
النص: {retrieved_text}
المصدر: {source}
التفسير/الفكرة: {tafsir}

مهمتك:
اكتب رسالة مواساة قصيرة جداً (جملتين كحد أقصى) تواسي بها المستخدم بلغة دافئة ومطمئنة، ثم ادمج النص الشرعي كما هو بدون أي تغيير في كلماته أو تشكيلاته.

القواعد الصارمة:
1. لا تقم بتغيير أي حرف من النص الشرعي.
2. اجعل الرد متعاطفاً وإنسانياً.
3. لا تكتب مقدمات مثل "بصفتي ذكاء اصطناعي". تحدث كصديق مباشرة.
4. الرد يجب أن يكون باللغة العربية.
"""

    def __init__(self):
        self._gemini_available = False
        if settings.GEMINI_API_KEY:
            try:
                genai.configure(api_key=settings.GEMINI_API_KEY)
                self.model = genai.GenerativeModel('gemini-3.6-flash')
                self._gemini_available = True
            except Exception:
                pass

    async def format_response(self, user_text: str, emotion: str,
                               retrieved_text: str, source: str, tafsir: str) -> str:
        """
        صياغة الرد النهائي الدافئ:
        - يحاول Gemini أولاً
        - عند نفاذ الحصة: يستخدم قوالب دافئة محلية
        """
        if self._gemini_available:
            try:
                result = await self._format_with_gemini(user_text, emotion, retrieved_text, source, tafsir)
                if result:
                    return result
            except Exception as e:
                error_str = str(e).lower()
                if "quota" in error_str or "resource_exhausted" in error_str or "429" in error_str:
                    # تجاوز الحصة — انتقل للقوالب المحلية
                    self._gemini_available = False
                # أي خطأ آخر → استخدم القوالب المحلية

        return self._format_with_template(emotion, retrieved_text, source)

    async def _format_with_gemini(self, user_text, emotion, retrieved_text, source, tafsir) -> str:
        prompt = self.FORMATTING_PROMPT.format(
            user_text=user_text, emotion=emotion,
            retrieved_text=retrieved_text,
            source=source or "غير معروف",
            tafsir=tafsir or "نص شرعي مبارك"
        )
        response = await self.model.generate_content_async(prompt)
        return response.text.strip()

    def _format_with_template(self, emotion: str, retrieved_text: str, source: str) -> str:
        """
        صياغة دافئة محلية باستخدام قوالب مُعدّة مسبقاً
        """
        templates = self.WARM_TEMPLATES.get(emotion)
        if not templates:
            # قالب مرن للحالات الجديدة
            intro = f"أسمعك، وأشعر بـ {emotion} الذي تمر به. وتذكر دائماً كلام الله في هذا الموقف:"
        else:
            intro = random.choice(templates)
            
        source_line = f"\n\n📖 {source}" if source else ""
        return f"{intro}\n\n{retrieved_text}{source_line}"

