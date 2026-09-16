import logging
from datetime import datetime

from fastapi import APIRouter, Depends, Request
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.v1.endpoints.auth import get_current_user_optional
from app.core.security import limiter
from app.core.taxonomy import EMOTION_SEMANTIC_QUERIES
from app.db.database import get_db
from app.services.ai.embeddings import EmbeddingService
from app.services.ai.rag_engine import RAGEngine
from app.services.history_manager import HistoryService
from app.services.ai.time_context import get_time_context

router = APIRouter()
embedder = EmbeddingService()
rag_engine = RAGEngine()
logger = logging.getLogger(__name__)

# ────────────────────────────────────────────────────────────────────────────
# نماذج البيانات
# ────────────────────────────────────────────────────────────────────────────

class ContextSignalsRequest(BaseModel):
    """إشارات السياق الواردة من العميل (الجهاز)."""
    dominant_emotion: str | None = None          # «قلق» / «حزن» / «فرح» …
    confidence: float = 0.0                       # ثقة المستشعر: 0.0 – 1.0
    signal_source: str = "history"               # «face» | «audio» | «history» | «time»
    time_of_day: str | None = None               # «فجر» | «صباح» | «ظهر» | «عصر» | «مساء» | «ليل»


class VerseResponse(BaseModel):
    """ردّ الآية الديناميكية."""
    verse: str
    source: str
    tafsir: str | None = None
    emotion_context: str
    signal_used: str
    cached: bool = False


# ────────────────────────────────────────────────────────────────────────────
# دوال مساعدة
# ────────────────────────────────────────────────────────────────────────────

# آيات افتراضية مرتبطة بأوقات اليوم — تُستخدم عند «طبيعي» أو غياب السياق
_TIME_OF_DAY_VERSES: dict[str, dict] = {
    "فجر": {
        "verse": "أَقِمِ الصَّلَاةَ لِدُلُوكِ الشَّمْسِ إِلَى غَسَقِ اللَّيْلِ وَقُرْآنَ الْفَجْرِ إِنَّ قُرْآنَ الْفَجْرِ كَانَ مَشْهُودًا",
        "source": "سورة الإسراء: ٧٨",
        "tafsir": "قرآن الفجر تشهده ملائكة الليل والنهار، فابدأ يومك بذكر الله لتنال هذا الفضل العظيم.",
    },
    "صباح": {
        "verse": "وَسَبِّحْ بِحَمْدِ رَبِّكَ قَبْلَ طُلُوعِ الشَّمْسِ وَقَبْلَ الْغُرُوبِ",
        "source": "سورة ق: ٣٩",
        "tafsir": "ابدأ صباحك بتسبيح الله وحمده، فذلك يُطمئن القلب ويُبارك في يومك.",
    },
    "ظهر": {
        "verse": "فَاذۡكُرُونِيٓ أَذۡكُرۡكُمۡ وَاشۡكُرُواْ لِي وَلَا تَكۡفُرُونِ",
        "source": "سورة البقرة: ١٥٢",
        "tafsir": "في وسط يومك المشغول، توقف لحظة واذكر الله؛ فمن ذكر الله في نفسه ذكره الله في ملأ خير منه.",
    },
    "عصر": {
        "verse": "وَالْعَصْرِ ۝ إِنَّ الْإِنسَانَ لَفِي خُسْرٍ ۝ إِلَّا الَّذِينَ آمَنُوا وَعَمِلُوا الصَّالِحَاتِ وَتَوَاصَوْا بِالْحَقِّ وَتَوَاصَوْا بِالصَّبْرِ",
        "source": "سورة العصر: ١–٣",
        "tafsir": "وقت العصر تذكير بقيمة الوقت — أيّ خير عملتَ اليوم؟ وأيّ حق نصحتَ به؟",
    },
    "مساء": {
        "verse": "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
        "source": "سورة الرعد: ٢٨",
        "tafsir": "مع اقتراب المساء، دع ذكر الله يُهدئ ما تراكم من ضغوط اليوم وينير قلبك.",
    },
    "ليل": {
        "verse": "وَمِن رَّحْمَتِهِ جَعَلَ لَكُمُ اللَّيْلَ وَالنَّهَارَ لِتَسْكُنُوا فِيهِ وَلِتَبْتَغُوا مِن فَضْلِهِ وَلَعَلَّكُمْ تَشْكُرُونَ",
        "source": "سورة القصص: ٧٣",
        "tafsir": "الليل نعمة من الله للراحة والسكن. أنهِ يومك بالحمد والشكر واستسلم لرحمة الله.",
    },
}


def _get_time_of_day() -> str:
    """تحديد وقت اليوم الحالي بالعربية."""
    hour = datetime.now().hour
    if 4 <= hour < 6:
        return "فجر"
    elif 6 <= hour < 11:
        return "صباح"
    elif 11 <= hour < 14:
        return "ظهر"
    elif 14 <= hour < 17:
        return "عصر"
    elif 17 <= hour < 21:
        return "مساء"
    else:
        return "ليل"


def _time_verse_response(time_of_day: str | None) -> VerseResponse:
    """إرجاع آية مرتبطة بوقت اليوم كاحتياط."""
    tod = time_of_day or _get_time_of_day()
    data = _TIME_OF_DAY_VERSES.get(tod, _TIME_OF_DAY_VERSES["مساء"])
    return VerseResponse(
        verse=data["verse"],
        source=data["source"],
        tafsir=data["tafsir"],
        emotion_context="طبيعي",
        signal_used="time",
        cached=True,
    )


# ────────────────────────────────────────────────────────────────────────────
# Endpoint الرئيسي
# ────────────────────────────────────────────────────────────────────────────

@router.post("", response_model=VerseResponse)
@limiter.limit("20/minute")
async def get_home_verse(
    request: Request,
    signals: ContextSignalsRequest,
    user: dict | None = Depends(get_current_user_optional),
    db: Session = Depends(get_db),
) -> VerseResponse:
    """
    يُعيد آية قرآنية مرشّحة بناءً على إشارات السياق المرسَلة من الجهاز.

    منطق الترشيح (أولوية تنازلية):
    1. حالة عاطفية واضحة (confidence ≥ 0.55) من الوجه أو الصوت أو السجل
    2. سياق المستخدم من سجل التفاعلات (إن كان مسجّلاً)
    3. احتياط: آية مرتبطة بوقت اليوم
    """
    try:
        dominant_emotion = signals.dominant_emotion
        confidence = signals.confidence
        time_of_day = signals.time_of_day or _get_time_of_day()

        # ── 1. تحديد ما إذا كنا سنستخدم حالة عاطفية أم آية الوقت ──
        use_emotion = (
            dominant_emotion is not None
            and dominant_emotion not in ("طبيعي", "")
            and confidence >= 0.55
        )

        # ── 2. إذا لا توجد حالة واضحة: آية الوقت فوراً ──
        if not use_emotion:
            # محاولة استخدام سجل المستخدم لتحديد حالة ملائمة
            if user:
                try:
                    history_service = HistoryService(db)
                    recent = history_service.get_history(user["id"])[:3]
                    if recent:
                        # أكثر حالة متكررة في آخر 3 تفاعلات
                        emotions = [
                            r["recommendation"]["emotion"]
                            for r in recent
                            if r["recommendation"].get("emotion") not in ("طبيعي", None)
                        ]
                        if emotions:
                            from collections import Counter
                            dominant_emotion = Counter(emotions).most_common(1)[0][0]
                            confidence = 0.55  # ثقة معتدلة من السجل
                            use_emotion = True
                except Exception:
                    pass

            if not use_emotion:
                return _time_verse_response(time_of_day)

        # ── 3. بناء الاستعلام الدلالي المحسّن ──
        semantic_query = EMOTION_SEMANTIC_QUERIES.get(
            dominant_emotion,
            f"الصبر والطمأنينة والتوكل على الله",
        )

        # إضافة سياق المستخدم إن كان مسجّلاً
        if user:
            try:
                history_service = HistoryService(db)
                user_ctx = history_service.get_user_context(user["id"])
                if user_ctx:
                    semantic_query = f"{semantic_query} {user_ctx}"
            except Exception:
                pass

        # ── 4. البحث في قاعدة المعرفة ──
        verse_results = embedder.search_similar(
            query=semantic_query,
            n_results=3,
            filters={"type": "verse"},
            emotion=dominant_emotion,
        )

        if (
            not verse_results
            or not verse_results.get("documents")
            or not verse_results["documents"][0]
        ):
            return _time_verse_response(time_of_day)

        # ── 5. اختيار الآية الأكثر ملاءمة ──
        verses_list = [
            {
                "text": verse_results["documents"][0][i],
                "source": verse_results["metadatas"][0][i].get("source", ""),
                "tafsir": verse_results["metadatas"][0][i].get("tafsir", ""),
            }
            for i in range(len(verse_results["documents"][0]))
        ]

        # نص السياق المختصر لاختيار الآية
        context_text = f"المستخدم يشعر بـ{dominant_emotion}"
        best = await rag_engine.select_best_verse(
            user_text=context_text,
            emotion=dominant_emotion,
            verses=verses_list,
        )

        verse_text = best.get("text", "")
        source = best.get("source", "")
        tafsir = best.get("tafsir", "")

        if not verse_text:
            return _time_verse_response(time_of_day)

        return VerseResponse(
            verse=verse_text,
            source=source,
            tafsir=tafsir,
            emotion_context=dominant_emotion,
            signal_used=signals.signal_source,
            cached=False,
        )

    except Exception as e:
        logger.error(f"Error in get_home_verse: {e}", exc_info=True)
        return _time_verse_response(signals.time_of_day)
