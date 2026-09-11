# ADR-006: تصميم API لمرحلة MVP - إدخال نصي فقط

## الحالة
مقبول ✅

## التاريخ
2026-09-11

## السياق

وفقاً لخارطة الطريق، المرحلة الأولى (P1) تركز على **الإدخال النصي فقط**. يجب تحديد الـ Endpoints المطلوبة وتصميمها بشكل يحقق:
1. بساطة الاستخدام للمستخدم النهائي
2. قابلية التوسع للمراحل القادمة
3. التوافق مع ADRs السابقة (RAG, Tiered Response)
4. تحقيق متطلبات الأداء (< 2 ثانية)

### التحديات

1. **تجربة المستخدم:** يجب أن يكون الـ API بسيطاً للـ Flutter App
2. **الأداء:** يجب تحقيق < 2 ثانية للرد الكامل
3. **الاستجابة المدرجة:** يجب دعم الثلاثة مستويات
4. **التغذية الراجعة:** يجب تسجيل تقييم المستخدم للتحسين

## القرار

تصميم API بـ **4 Endpoints أساسية** للـ MVP:

### 1. Endpoint التوصية (Primary)

```
POST /api/v1/recommend
```

**الطلب:**
```json
{
  "text": "أشعر بالقلق والتوتر من المستقبل",
  "emotion_hint": "قلق",  // اختياري - تلميح من المستخدم
  "user_id": 123          // اختياري - للمستخدمين المسجلين
}
```

**الرد (Full Tier):**
```json
{
  "success": true,
  "data": {
    "emotion": {
      "detected": "قلق",
      "confidence": 0.82,
      "intensity": "medium"
    },
    "recommendation": {
      "type": "verse",
      "arabic_text": "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ",
      "translation": "ألا بذكر الله تطمئن القلوب",
      "tafsir": "ذكر الله تعالى سبب لطمأنينة القلوب وراحتها...",
      "source": "سورة الرعد: 28",
      "tier": "full"
    },
    "interaction_id": 12345
  },
  "meta": {
    "response_time_ms": 1850,
    "from_cache": false
  }
}
```

**الرد (Minimal Tier - للمستخدم الغاضب):**
```json
{
  "success": true,
  "data": {
    "emotion": {
      "detected": "غضب",
      "confidence": 0.95,
      "intensity": "high"
    },
    "recommendation": {
      "type": "symbol",
      "arabic_text": "💚",
      "translation": "",
      "tafsir": "",
      "source": "",
      "tier": "minimal"
    },
    "delayed_content_id": 67890,  // معرف المحتوى المؤجل
    "interaction_id": 12346
  },
  "meta": {
    "response_time_ms": 320,
    "message": "تم تأجيل المحتوى المفصل لحين هدوئك"
  }
}
```

### 2. Endpoint التغذية الراجعة

```
POST /api/v1/feedback
```

**الطلب:**
```json
{
  "interaction_id": 12345,
  "user_id": 123,           // اختياري
  "rating": "positive",     // positive | negative | neutral
  "comment": "الآية مناسبة جداً"  // اختياري
}
```

**الرد:**
```json
{
  "success": true,
  "message": "شكراً لتغذيتك الراجعة"
}
```

### 3. Endpoint استرجاع المحتوى المؤجل

```
GET /api/v1/delayed/{delayed_content_id}
```

**الرد:**
```json
{
  "success": true,
  "data": {
    "type": "verse",
    "arabic_text": "وَالْكَاظِمِينَ الْغَيْظَ",
    "translation": "والكاظمين الغيظ",
    "tafsir": "كظم الغيظ من أعظم الأخلاق...",
    "source": "سورة آل عمران: 134",
    "tier": "full",
    "original_interaction_id": 12346,
    "delayed_for_minutes": 30
  }
}
```

### 4. Endpoint الصحة

```
GET /api/v1/health
```

**الرد:**
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "services": {
    "database": "up",
    "redis": "up",
    "chromadb": "up",
    "gemini_api": "up"
  }
}
```

## التبرير

### 1. بساطة التصميم

```
┌─────────────┐
│ Flutter App │
└──────┬──────┘
       │
       │ POST /recommend
       │ {"text": "..."}
       ▼
┌─────────────────────────────────────────┐
│           Backend API                    │
│  ┌─────────────────────────────────┐    │
│  │ 1. تحليل المشاعر (Gemini)       │    │
│  │ 2. تحديد Tier                   │    │
│  │ 3. بحث دلالي (ChromaDB)         │    │
│  │ 4. التحقق (RAG)                 │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
       │
       │ Response (< 2s)
       ▼
┌─────────────┐
│   المستخدم   │
└─────────────┘
```

### 2. قابلية التوسع

```python
# التصميم الحالي (MVP)
POST /recommend
  ├── text: str          # إدخال نصي
  └── emotion_hint: str  # تلميح اختياري

# المرحلة القادمة (P2)
POST /recommend
  ├── text: str          # إدخال نصي
  ├── audio: file        # ✨ إضافة: صوت
  ├── image: file        # ✨ إضافة: صورة
  └── emotion_hint: str
```

### 3. الأداء المطلوب

| المكون | الوقت المسموح | الوقت الفعلي (متوقع) |
|--------|---------------|---------------------|
| تحليل المشاعر | 300ms | 250ms (Gemini Flash) |
| تحديد Tier | 10ms | 5ms |
| البحث الدلالي | 200ms | 150ms (ChromaDB) |
| RAG Verification | 400ms | 300ms |
| Cache Check | 50ms | 30ms (Redis) |
| Database Insert | 100ms | 80ms |
| **المجموع** | **1060ms** | **815ms** ✅ |

## التنفيذ

### FastAPI Router

```python
# app/api/v1/endpoints/recommend.py
from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel, Field
from typing import Optional
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.ai.semantic_search import SemanticSearch
from app.services.ai.rag_engine import RAGEngine
from app.services.cache.redis_cache import RedisCache
from app.services.notification.tiered_response import TieredResponse
from app.db.repositories.interaction import interaction_repo

router = APIRouter()

# --- Request/Response Models ---

class RecommendRequest(BaseModel):
    text: str = Field(..., min_length=3, max_length=2000)
    emotion_hint: Optional[str] = None
    user_id: Optional[int] = None

class EmotionResponse(BaseModel):
    detected: str
    confidence: float
    intensity: str

class RecommendationResponse(BaseModel):
    type: str  # verse | hadith | symbol
    arabic_text: str
    translation: str
    tafsir: str
    source: str
    tier: str  # minimal | moderate | full

class RecommendResponseModel(BaseModel):
    success: bool
    data: dict
    meta: dict

# --- Endpoint ---

@router.post("/recommend", response_model=RecommendResponseModel)
async def get_recommendation(
    request: RecommendRequest,
    background_tasks: BackgroundTasks
):
    """
    الحصول على توصية دينية مناسبة بناءً على نص المستخدم.
    
    المراحل:
    1. تحليل المشاعر
    2. تحديد مستوى التدخل (Tier)
    3. البحث الدلالي
    4. التحقق عبر RAG
    5. تسجيل التفاعل
    """
    import time
    start_time = time.time()
    
    # التحقق من Cache
    cache = RedisCache()
    if request.emotion_hint:
        cached = cache.get_cached_recommendation(request.emotion_hint)
        if cached:
            cached["meta"]["from_cache"] = True
            return cached
    
    # 1. تحليل المشاعر
    analyzer = EmotionAnalyzer()
    emotion_result = await analyzer.analyze(request.text)
    
    # 2. تحديد Tier
    tiered = TieredResponse()
    tier = tiered.determine_tier(
        emotion=emotion_result["emotion"],
        confidence=emotion_result["confidence"]
    )
    
    # 3. Minimal Tier - رد فوري
    if tier == "minimal":
        interaction_id = await _save_interaction(
            user_id=request.user_id,
            query=request.text,
            emotion=emotion_result,
            tier=tier
        )
        
        delayed_id = await _schedule_delayed(
            user_id=request.user_id,
            interaction_id=interaction_id,
            emotion=emotion_result["emotion"]
        )
        
        response = {
            "success": True,
            "data": {
                "emotion": {
                    "detected": emotion_result["emotion"],
                    "confidence": emotion_result["confidence"],
                    "intensity": "high"
                },
                "recommendation": tiered.get_minimal_response(emotion_result["emotion"]),
                "delayed_content_id": delayed_id,
                "interaction_id": interaction_id
            },
            "meta": {
                "response_time_ms": int((time.time() - start_time) * 1000),
                "from_cache": False,
                "message": "تم تأجيل المحتوى المفصل لحين هدوئك"
            }
        }
        return response
    
    # 4. البحث الدلالي
    searcher = SemanticSearch()
    results = await searcher.search(
        query=request.text,
        emotion=emotion_result["emotion"],
        top_k=5
    )
    
    # 5. RAG للتحقق والاختيار
    rag = RAGEngine()
    final_result = await rag.process(
        query=request.text,
        results=results,
        emotion=emotion_result["emotion"]
    )
    
    # 6. تسجيل التفاعل
    interaction_id = await _save_interaction(
        user_id=request.user_id,
        query=request.text,
        emotion=emotion_result,
        tier=tier,
        result=final_result
    )
    
    # 7. بناء الرد
    response = {
        "success": True,
        "data": {
            "emotion": {
                "detected": emotion_result["emotion"],
                "confidence": emotion_result["confidence"],
                "intensity": "medium" if tier == "moderate" else "low"
            },
            "recommendation": {
                "type": final_result["type"],
                "arabic_text": final_result["arabic_text"],
                "translation": final_result["translation"],
                "tafsir": final_result["tafsir"] if tier == "full" else "",
                "source": final_result["source"],
                "tier": tier
            },
            "interaction_id": interaction_id
        },
        "meta": {
            "response_time_ms": int((time.time() - start_time) * 1000),
            "from_cache": False
        }
    }
    
    # 8. تخزين في Cache
    cache.cache_recommendation(emotion_result["emotion"], response)
    
    return response

# --- Helper Functions ---

async def _save_interaction(
    user_id: Optional[int],
    query: str,
    emotion: dict,
    tier: str,
    result: dict = None
) -> int:
    """حفظ التفاعل في قاعدة البيانات"""
    # Implementation here
    pass

async def _schedule_delayed(
    user_id: Optional[int],
    interaction_id: int,
    emotion: str
) -> int:
    """جدولة المحتوى المؤجل"""
    # Implementation here
    pass
```

### Error Handling

```python
# app/core/exceptions.py
from fastapi import HTTPException

class EmptyTextError(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=400,
            detail={
                "success": False,
                "error": {
                    "code": "EMPTY_TEXT",
                    "message": "النص المدخل فارغ"
                }
            }
        )

class TextTooShortError(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=400,
            detail={
                "success": False,
                "error": {
                    "code": "TEXT_TOO_SHORT",
                    "message": "النص يجب أن يكون على الأقل 3 أحرف"
                }
            }
        )

class AIServiceError(HTTPException):
    def __init__(self):
        super().__init__(
            status_code=503,
            detail={
                "success": False,
                "error": {
                    "code": "AI_SERVICE_UNAVAILABLE",
                    "message": "خدمة الذكاء الاصطناعي غير متاحة حالياً"
                }
            }
        )
```

## العواقب

### إيجابية ✅

1. **بساطة** - Endpoint واحد للوظيفة الأساسية
2. **أداء** - تحقيق < 2 ثانية بسهولة
3. **توسع** - جاهز لإضافة الصوت والصورة لاحقاً
4. **تجربة مستخدم** - تجربة سلسة مع الاستجابة المدرجة

### سلبية ⚠️

1. **عدم المصادقة** - لا يوجد Authentication في MVP
2. **تتبع محدود** - لا يمكن ربط التفاعلات بالمستخدمين المجهولين

### محايدة

- يجب إضافة Authentication في المرحلة القادمة

## المقارنة مع البدائل

### بديل 1: API متعدد الـ Endpoints

```
POST /analyze-emotion
POST /search-content
POST /create-recommendation
POST /save-feedback
```

**عيوب:**
- تعقيد للـ Frontend
- زيادة الطلبات الشبكية
- صعوبة التوسع

### بديل 2: GraphQL API

```graphql
mutation {
  recommend(input: {text: "..."}) {
    emotion { detected confidence }
    recommendation { arabicText source }
  }
}
```

**عيوب:**
- تعقيد في التنفيذ
- حاجة لتعلم GraphQL
- لا ميزة واضحة في MVP

## التاريخ

- 2026-09-11: القرار الأولي
- -: أول مراجعة (قادمة)

---

**المؤلف:** فريق مُرَسِّخ  
**المراجعون:** قيد التعيين
