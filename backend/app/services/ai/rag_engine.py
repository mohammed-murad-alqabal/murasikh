import asyncio
import logging
import random
from typing import ClassVar

from google import genai

from app.core.config import settings

try:
    from transformers import AutoModelForCausalLM, AutoTokenizer

    LOCAL_LLM_AVAILABLE = True
except ImportError:
    LOCAL_LLM_AVAILABLE = False


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

وهذه هي الآية القرآنية المخصصة لمواساته:
النص: {retrieved_text}
المصدر: {source}
التفسير/الفكرة: {tafsir}

مهمتك:
اكتب رسالة مواساة قصيرة جداً (جملتين كحد أقصى) تواسي بها المستخدم بلغة دافئة ومطمئنة، ثم ادمج الآية القرآنية كما هي بدون أي تغيير في كلماتها أو تشكيلها.

القواعد الصارمة:
1. لا تقم بتغيير أي حرف من الآية القرآنية.
2. اجعل الرد متعاطفاً وإنسانياً.
3. لا تكتب مقدمات مثل "بصفتي ذكاء اصطناعي". تحدث كصديق مباشرة.
4. الرد يجب أن يكون باللغة العربية حصراً. لا تستخدم الأحاديث النبوية، التزم بالقرآن فقط.
"""

    def __init__(self):
        self._gemini_available = False
        self._local_llm_loaded = False
        self._local_model = None
        self._local_tokenizer = None
        if settings.GEMINI_API_KEY:
            try:
                self.client = genai.Client(
                    api_key=settings.GEMINI_API_KEY,
                    http_options=genai.types.HttpOptions(timeout=5000),
                )
                self.model_name = "gemini-3.6-flash"
                self._gemini_available = True
            except Exception as e:
                logging.error(f"Failed to initialize Gemini: {e}")

    def _load_local_llm(self):
        if not LOCAL_LLM_AVAILABLE or self._local_llm_loaded:
            return
        try:
            logging.info("Loading local LLM (Qwen2.5-0.5B-Instruct)...")
            model_name = "Qwen/Qwen2.5-0.5B-Instruct"
            self._local_tokenizer = AutoTokenizer.from_pretrained(model_name)
            self._local_model = AutoModelForCausalLM.from_pretrained(
                model_name, torch_dtype="auto", device_map="auto"
            )
            self._local_llm_loaded = True
            logging.info("Local LLM loaded successfully.")
        except Exception as e:
            logging.error(f"Failed to load local LLM: {e}")
            self._local_llm_loaded = False

    # كلمات الوعيد التي يجب تجنبها في الردود المواسية
    AVOID_PATTERNS = [
        "عَذَابٌ",
        "عذاب",
        "نَارٌ",
        "جَهَنَّمَ",
        "وَيْلٌ",
        "لَعَنَهُمُ",
        "يُعَذِّبُ",
        "أَهْلَكْنَا",
        "دَمَّرْنَا",
        "فَأَخَذَهُمُ",
        "سَنُعَذِّبُهُمْ",
        "فَاسِقِينَ",
        "الْكَافِرِينَ",
        "الْمُنَافِقِينَ",
        "حُشِرَ",
        "جُنُودُهُۥ",
    ]

    # كلمات إيجابية مرتبطة بكل حالة للتصفية المحلية
    EMOTION_POSITIVE_KEYWORDS: ClassVar[dict] = {
        "يأس": ["رَحْمَةَ", "رحمة", "فَرَج", "فرج", "يَقْنَطُ", "لَا تَقْنَطُوا", "أَمَلٍ", "يُيَسِّرُ"],
        "حزن": ["صَبَرُوا", "صبر", "يُصِيبُهُم", "اطْمَأَنَّ", "السَّكِينَةَ", "لَا تَحْزَنُوا"],
        "قلق": ["تَوَكَّلَ", "حَسْبُنَا", "يَكْفِي", "يَحْفَظُ", "حَافِظُونَ"],
        "غضب": ["اعْفُ", "يَعْفُو", "تَعْفُو", "حَلِيمٌ", "غَافِرٌ"],
        "إرهاق": ["يُسْرًا", "يُسْرٌ", "لَا يُكَلِّفُ", "طَاقَتَهَا", "رَاحَةٍ"],
        "وحدة": ["قَرِيبٌ", "مَعَكُمْ", "وَهُوَ مَعَكُمْ", "لَسْتُمْ"],
    }

    async def select_best_verse(
        self, user_text: str, emotion: str, verses: list[dict]
    ) -> dict:
        """
        يختار أفضل آية من قائمة الآيات المسترجعة لتكون 'الاستجابة المثالية' لحالة المستخدم الحالية.
        عند توفر Gemini يستخدمه، وعند النفاذ يُطبّق فلتراً محلياً ذكياً.
        """
        if not verses:
            return {"text": "اذكر الله يهدأ قلبك", "source": "", "tafsir": ""}

        # --- فلترة محلية مبدئية: إزالة آيات الوعيد ---
        def score_verse(v: dict) -> int:
            text = v.get("text", "")
            # عقوبة على كلمات الوعيد
            if any(pat in text for pat in self.AVOID_PATTERNS):
                return -100
            # مكافأة على الكلمات الإيجابية المرتبطة بالحالة
            score = 0
            for kw in self.EMOTION_POSITIVE_KEYWORDS.get(emotion, []):
                if kw in text:
                    score += 10
            return score

        # إذا Gemini متاح، استخدمه للاختيار الدقيق
        if self._gemini_available:
            prompt = f"""
لديك مستخدم يعاني من: {emotion}
وقد قال: "{user_text}"

استخرجنا {len(verses)} آيات قرآنية محتملة. بعضها قد يكون مجرد تطابق لفظي ولا يخدم هدف المواساة والتهدئة، وبعضها قد يكون مثالياً.

"""
            for i, v in enumerate(verses):
                prompt += f"الآية {i + 1}: {v.get('text')}\nالمصدر {i + 1}: {v.get('source')}\n\n"

            prompt += """
مهمتك:
اختر الرقم للآية التي تعتبر "الاستجابة المثالية والأنسب والأكثر إلهاماً وطمأنينة" لحالة المستخدم.
إذا كانت آية تحتوي على وعيد أو تخص المنافقين أو الكافرين، تجنبها تماماً.

أرجع الرقم فقط (مثال: 1).
"""
            try:
                response = await asyncio.to_thread(
                    self.client.models.generate_content,
                    model=self.model_name,
                    contents=prompt,
                    config=genai.types.GenerateContentConfig(temperature=0.1),
                )
                text = response.text.strip()
                for i in range(len(verses), 0, -1):
                    if str(i) in text:
                        candidate = verses[i - 1]
                        # تحقق أخير: إذا كانت الآية تحتوي وعيداً رغم الطلب، استخدم الفلتر المحلي
                        if score_verse(candidate) >= 0:
                            return candidate
                        break
            except Exception as e:
                error_str = str(e).lower()
                logging.error(f"Error selecting best verse via Gemini: {e}")
                if (
                    "quota" in error_str
                    or "429" in error_str
                    or "resource_exhausted" in error_str
                ):
                    self._gemini_available = False

        # --- Fallback محلي ذكي: اختيار الآية الأعلى درجة ---
        scored = sorted(verses, key=score_verse, reverse=True)
        best = scored[0]
        # إذا أعلى درجة سلبية (كل الآيات وعيد)، أعد الأولى على أي حال
        return best

    async def format_response(
        self,
        user_text: str,
        emotion: str,
        retrieved_text: str,
        source: str,
        tafsir: str,
    ) -> str:
        """
        صياغة الرد النهائي الدافئ:
        - يحاول Gemini أولاً
        - عند نفاذ الحصة: يستخدم LLM محلي (Qwen)
        - إذا فشل: يستخدم قوالب دافئة محلية
        """
        if self._gemini_available:
            try:
                result = await self._format_with_gemini(
                    user_text, emotion, retrieved_text, source, tafsir
                )
                if result:
                    return result
            except Exception as e:
                error_str = str(e).lower()
                if (
                    "quota" in error_str
                    or "resource_exhausted" in error_str
                    or "429" in error_str
                    or "no api_key" in error_str
                ):
                    self._gemini_available = False

        # Local LLM Fallback
        if LOCAL_LLM_AVAILABLE:
            try:
                if not self._local_llm_loaded:
                    # Load asynchronously so it doesn't block entirely if possible,
                    # but here we just load synchronously for the first time.
                    self._load_local_llm()

                if self._local_llm_loaded:
                    result = await asyncio.to_thread(
                        self._format_with_local_llm,
                        user_text,
                        emotion,
                        retrieved_text,
                        source,
                    )
                    if result:
                        return result
            except Exception as e:
                logging.error(f"Local LLM formatting failed: {e}")

        return self._format_with_template(emotion, retrieved_text, source)

    async def _format_with_gemini(
        self,
        user_text: str,
        emotion: str,
        retrieved_text: str,
        source: str,
        tafsir: str,
    ) -> str:
        prompt = f"""
المستخدم يشعر بـ: {emotion}
وقد قال: "{user_text}"

الآية المختارة لمواساته: {retrieved_text}
التفسير: {tafsir}

اكتب رسالة مواساة وتعاطف دافئة وقصيرة جداً (سطر واحد)، ثم اذكر الآية. لا تقم بشرح التفسير، فقط استخدمه لفهم السياق.
الرسالة يجب أن تنتهي بالآية مباشرة.
"""
        response = await asyncio.to_thread(
            self.client.models.generate_content,
            model=self.model_name,
            contents=prompt,
            config=genai.types.GenerateContentConfig(temperature=0.7),
        )
        return response.text.strip() + f"\n\n📖 {source}"

    def _format_with_template(
        self,
        emotion: str,
        retrieved_text: str,
        source: str | None,
    ) -> str:
        templates = self.WARM_TEMPLATES.get(emotion)
        intro = (
            random.choice(templates)
            if templates
            else ("أسمعك، وأشعر بما تمر به. وتذكر دائماً كلام الله في هذا الموقف:")
        )
        source_line = f"\n\n📖 {source}" if source else ""
        return f"{intro}\n\n{retrieved_text}{source_line}"

    def _format_with_local_llm(
        self, user_text: str, emotion: str, retrieved_text: str, source: str
    ) -> str:
        messages = [
            {
                "role": "system",
                "content": "أنت رفيق إسلامي دافئ وحنون تواسي المستخدم. اكتب رسالة مواساة وتعاطف قصيرة جداً (جملة واحدة فقط) للمستخدم، بدون كتابة آيات.",
            },
            {
                "role": "user",
                "content": f"أنا أشعر بـ {emotion}. وهذا ما قلته: {user_text}",
            },
        ]

        text = self._local_tokenizer.apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        model_inputs = self._local_tokenizer([text], return_tensors="pt").to(
            self._local_model.device
        )

        generated_ids = self._local_model.generate(
            **model_inputs, max_new_tokens=40, temperature=0.7
        )
        generated_ids = [
            output_ids[len(input_ids) :]
            for input_ids, output_ids in zip(model_inputs.input_ids, generated_ids)
        ]

        intro = self._local_tokenizer.batch_decode(
            generated_ids, skip_special_tokens=True
        )[0].strip()

        templates = self.WARM_TEMPLATES.get(emotion)
        if not templates:
            # قالب مرن للحالات الجديدة
            intro = f"أسمعك، وأشعر بـ {emotion} الذي تمر به. وتذكر دائماً كلام الله في هذا الموقف:"
        else:
            intro = random.choice(templates)

        source_line = f"\n\n📖 {source}" if source else ""
        return f"{intro}\n\n{retrieved_text}{source_line}"

        # Clean up output
        intro = intro.replace('"', "").replace("بصفتي ذكاء اصطناعي", "")
        source_line = f"\n\n📖 {source}" if source else ""
        return f"{intro}\n\n{retrieved_text}{source_line}"
