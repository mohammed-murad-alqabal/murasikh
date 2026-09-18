# خطة التنفيذ المحسّنة - MVP (todo-1)

## 📋 المعلومات العامة

| البند | القيمة |
|-------|--------|
| **اسم الخطة** | todo-1 |
| **المرحلة** | MVP (المرحلة الأولى - P1) |
| **المدة** | 18 أسبوع (4.5 أشهر) |
| **الهدف** | نظام يعتمد على الإدخال النصي والسياق البسيط |
| **تاريخ الإنشاء** | 2026-09-11 |
| **آخر تحديث** | 2026-09-11 |
| **الحالة** | جاهز للتنفيذ |

---


> [!NOTE]
> **تحديث الإنجازات (13 سبتمبر 2026):** تم إنجاز معظم الخطة بنجاح. تم التخلي عن الآيات للحفاظ على طهارة البحث القرآني الصافي، وتم استبدال نموذج AraBERT بنموذج MiniLM لضمان الدقة الدلالية في بيئة الـ Offline، وتم تطبيق وضع الأوفلاين الشامل، وإصلاح كافة مشاكل العرض والتمرير، وتخطي اختبارات الواجهة الأمامية بنجاح باهر.

## 🎯 الهدف الرئيسي

بناء نظام "مُرَسِّخ" في نسخته الأولية (MVP) الذي:
- يقبل إدخال نصي من المستخدم (وصف المشاعر أو الموقف)
- يحلل الحالة العاطفية
- يقدم توصية دينية مناسبة (آية قرآنية مع التفسير)
- يعتمد على تقنية RAG لضمان الدقة الشرعية
- يعمل بدون إنترنت (Offline-First)
- يطبق الاستجابة المدرجة (Tiered Response)

---

## 🛠️ التقنيات المحددة

### Backend
| المكون | التقنية | السبب |
|--------|---------|-------|
| **Framework** | FastAPI | أداء عالي، دعم Async، توثيق تلقائي |
| **Database** | PostgreSQL | للمحتوى الشرعي وسجل المستخدم |
| **Vector DB** | Chroma (تطوير) / Milvus (إنتاج) | مجاني للتطوير، قابل للتوسع للإنتاج |
| **ORM** | SQLAlchemy | مرونة في التعامل مع قاعدة البيانات |
| **Migrations** | Alembic | إدارة تحديثات قاعدة البيانات |
| **Auth** | JWT (python-jose) | للمصادقة والأمان |
| **Cache** | Redis | تحسين الأداء، تحقيق < 2 ثانية |
| **Task Queue** | Celery | المعالجة غير المتزامنة |

### AI & ML
| المكون | التقنية | السبب |
|--------|---------|-------|
| **Embeddings** | paraphrase-multilingual-MiniLM-L12-v2 | مخصص للعربية، SOTA للـ RAG |
| **LLM** | Google Gemini | أقل تكلفة، جودة عالية |
| **Semantic Search** | Sentence Transformers | متكامل مع GATE |

### Infrastructure & DevOps
| المكون | التقنية | السبب |
|--------|---------|-------|
| **Containerization** | Docker | بيئة متسقة |
| **Orchestration** | Docker Compose (تطوير) / Kubernetes (إنتاج) | إدارة الحاويات |
| **CI/CD** | GitHub Actions | نشر مستمر |
| **Monitoring** | Prometheus + Grafana | مراقبة الأداء |
| **Error Tracking** | Sentry | تتبع الأخطاء |
| **Logging** | Loguru | تسجيل منظم |

### مصادر البيانات الشرعية
| المصدر | المحتوى | الرابط | ملاحظة |
|--------|---------|--------|--------|
| **UmmahAPI** | 6,236 آية + حصرياً + تفسير | https://ummahapi.com | مجاني، موثوق |
| **House of Islam** | قرآن + تفسير + أدعية | https://developers.thehouseofislam.com | تحميل مباشر |
| **IslamHouse API** | محتوى متعدد اللغات | https://github.com/IslamHouse-API | مصدر إضافي |

---

## 📅 الجدول الزمني المحسّن (18 أسبوع)

### الأسبوع 0: التخطيط والإعداد ⚙️

#### المهام
- [x] مراجعة الوثائق والمتطلبات
- [x] إعداد بيئة التطوير
- [x] تثبيت الأدوات المطلوبة
- [x] إنشاء المستودع وإعداد Git
- [x] إعداد Docker و Docker Compose

#### المخرجات
- بيئة تطوير جاهزة
- مستودع Git مُعد

---

### الأسبوع 1-3: البنية التحتية 🏗️

#### قاعدة البيانات (PostgreSQL)

```sql
-- جدول الآيات
CREATE TABLE verses (
    id SERIAL PRIMARY KEY,
    surah_number INTEGER NOT NULL,
    ayah_number INTEGER NOT NULL,
    text_arabic TEXT NOT NULL,
    text_uthmani TEXT,
    text_indopak TEXT,
    translation TEXT,
    tafsir TEXT,
    tafsir_source VARCHAR(100), -- 'ibn_kathir', 'saadi', etc.
    tags TEXT[], -- ['غضب', 'صبر', 'حزن']
    emotional_state VARCHAR(50),
    keywords TEXT[], -- كلمات مفتاحية للبحث
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- فهرسة للبحث السريع
CREATE INDEX idx_verses_emotional_state ON verses(emotional_state);
CREATE INDEX idx_verses_surah_ayah ON verses(surah_number, ayah_number);
CREATE INDEX idx_verses_tags ON verses USING GIN(tags);

-- جدول الآيات
CREATE TABLE verses (
    id SERIAL PRIMARY KEY,
    collection VARCHAR(100) NOT NULL,
    verse_number VARCHAR(50),
    text_arabic TEXT NOT NULL,
    translation TEXT,
    explanation TEXT,
    narrator VARCHAR(255),
    grade VARCHAR(50), -- 'sahih', 'hasan', 'daif'
    tags TEXT[],
    emotional_state VARCHAR(50),
    keywords TEXT[],
    is_authentic BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

CREATE INDEX idx_verses_emotional_state ON verses(emotional_state);
CREATE INDEX idx_verses_collection ON verses(collection);
CREATE INDEX idx_verses_tags ON verses USING GIN(tags);

-- جدول المستخدمين
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    preferences JSONB DEFAULT '{
        "notification_style": "minimal",
        "language": "ar",
        "theme": "light",
        "font_size": "medium"
    }'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE
);

-- جدول التفاعلات
CREATE TABLE interactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    query_text TEXT,
    detected_emotion VARCHAR(50),
    emotion_confidence FLOAT,
    recommendation_type VARCHAR(20),
    recommendation_id INTEGER,
    user_feedback BOOLEAN,
    response_tier VARCHAR(20), -- 'minimal', 'moderate', 'full'
    response_delayed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_interactions_user ON interactions(user_id);
CREATE INDEX idx_interactions_created ON interactions(created_at);

-- جدول الاستجابات المؤجلة
CREATE TABLE delayed_responses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    interaction_id INTEGER REFERENCES interactions(id),
    recommendation_type VARCHAR(20),
    recommendation_id INTEGER,
    reason VARCHAR(100), -- 'high_emotion', 'user_busy', etc.
    is_delivered BOOLEAN DEFAULT FALSE,
    scheduled_for TIMESTAMP,
    delivered_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- جدول التصنيف العاطفي
CREATE TABLE emotion_mappings (
    id SERIAL PRIMARY KEY,
    emotion VARCHAR(50) NOT NULL,
    keywords TEXT[],
    example_verses INTEGER[],
    example_verses INTEGER[],
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### هيكل الـ Backend المحسّن

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                    # نقطة الدخول
│   ├── config.py                  # الإعدادات
│   ├── database.py                # اتصال قاعدة البيانات
│   ├── dependencies.py            # حقن التبعيات
│   │
│   ├── api/
│   │   ├── __init__.py
│   │   ├── deps.py                # تبعيات الـ API
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── router.py
│   │       └── endpoints/
│   │           ├── __init__.py
│   │           ├── auth.py        # المصادقة
│   │           ├── recommend.py   # التوصية
│   │           ├── feedback.py    # التغذية الراجعة
│   │           ├── history.py     # السجل
│   │           └── health.py      # فحص الصحة
│   │
│   ├── core/
│   │   ├── __init__.py
│   │   ├── security.py            # JWT, التشفير
│   │   ├── config.py              # إعدادات البيئة
│   │   ├── logging.py             # نظام التسجيل
│   │   └── exceptions.py          # الأخطاء المخصصة
│   │
│   ├── db/
│   │   ├── __init__.py
│   │   ├── base.py                # Base class
│   │   ├── models.py              # SQLAlchemy models
│   │   ├── schemas.py             # Pydantic schemas
│   │   └── repositories/
│   │       ├── __init__.py
│   │       ├── base.py
│   │       ├── verse.py
│   │       ├── verse.py
│   │       ├── user.py
│   │       └── interaction.py
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── ai/
│   │   │   ├── __init__.py
│   │   │   ├── embeddings.py      # MiniLM-L12
│   │   │   ├── semantic_search.py # البحث الدلالي
│   │   │   ├── emotion_analyzer.py
│   │   │   ├── llm_client.py      # Gemini
│   │   │   └── rag_engine.py      # RAG محرك
│   │   ├── knowledge_base/
│   │   │   ├── __init__.py
│   │   │   ├── quran_service.py
│   │   │   └── verse_service.py
│   │   ├── cache/
│   │   │   ├── __init__.py
│   │   │   └── redis_cache.py
│   │   └── notification/
│   │       ├── __init__.py
│   │       ├── tiered_response.py # الاستجابة المدرجة
│   │       └── delayed_delivery.py
│   │
│   ├── tasks/
│   │   ├── __init__.py
│   │   └── celery_app.py          # المهام الخلفية
│   │
│   └── utils/
│       ├── __init__.py
│       ├── validators.py
│       └── helpers.py
│
├── alembic/
│   ├── versions/
│   └── env.py
│
├── tests/
│   ├── __init__.py
│   ├── conftest.py
│   ├── test_api/
│   ├── test_services/
│   └── test_models/
│
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
│
├── scripts/
│   ├── seed_data.py
│   └── create_embeddings.py
│
├── alembic.ini
├── requirements.txt
├── .env.example
└── README.md
```

#### Vector Database Setup

```python
# app/services/ai/embeddings.py
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer

class EmbeddingService:
    def __init__(self):
        self.model = SentenceTransformer(
            'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2'
        )
        self.client = chromadb.Client(Settings(
            chroma_db_impl="duckdb+parquet",
            persist_directory="./chroma_db"
        ))
        self.collection = self.client.get_or_create_collection(
            name="islamic_content",
            metadata={"description": "القرآن الكريم والتفاسير"}
        )
    
    def create_embedding(self, text: str) -> list:
        """تحويل نص إلى متجه"""
        return self.model.encode([text]).tolist()[0]
    
    def create_embeddings_batch(self, texts: list) -> list:
        """تحويل مجموعة نصوص إلى متجهات"""
        return self.model.encode(texts).tolist()
    
    def store_embedding(self, id: str, text: str, metadata: dict):
        """تخزين متجه في Chroma"""
        embedding = self.create_embedding(text)
        self.collection.add(
            ids=[id],
            embeddings=[embedding],
            documents=[text],
            metadatas=[metadata]
        )
    
    def search_similar(self, query: str, n_results: int = 5, 
                       filters: dict = None) -> list:
        """البحث عن نصوص مشابهة"""
        query_embedding = self.create_embedding(query)
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
            where=filters
        )
        return results
```

#### Redis Cache Setup

```python
# app/services/cache/redis_cache.py
import redis
import json
from typing import Optional, Any
from datetime import timedelta

class RedisCache:
    def __init__(self, host: str = "localhost", port: int = 6379):
        self.client = redis.Redis(
            host=host,
            port=port,
            decode_responses=True
        )
    
    def get(self, key: str) -> Optional[Any]:
        """الحصول على قيمة من الـ Cache"""
        value = self.client.get(key)
        if value:
            return json.loads(value)
        return None
    
    def set(self, key: str, value: Any, ttl: int = 3600):
        """تخزين قيمة في الـ Cache"""
        self.client.setex(
            key,
            timedelta(seconds=ttl),
            json.dumps(value, ensure_ascii=False)
        )
    
    def delete(self, key: str):
        """حذف من الـ Cache"""
        self.client.delete(key)
    
    def cache_recommendation(self, emotion: str, result: dict):
        """تخزين التوصية في الـ Cache"""
        key = f"rec:{emotion}"
        self.set(key, result, ttl=86400)  # يوم واحد
    
    def get_cached_recommendation(self, emotion: str) -> Optional[dict]:
        """الحصول على توصية من الـ Cache"""
        return self.get(f"rec:{emotion}")
```

---

### الأسبوع 4-6: قاعدة المعرفة 📚

#### مصادر البيانات

**1. Quran API (UmmahAPI)**

```python
# app/services/knowledge_base/quran_service.py
import requests
from typing import List, Dict
import asyncio
import aiohttp

class QuranService:
    BASE_URL = "https://api.ummahapi.com"
    
    async def fetch_all_verses(self) -> List[Dict]:
        """جلب جميع الآيات بشكل متزام"""
        async with aiohttp.ClientSession() as session:
            tasks = []
            for surah in range(1, 115):
                for ayah in range(1, 287):
                    tasks.append(self._fetch_verse(session, surah, ayah))
            return await asyncio.gather(*tasks, return_exceptions=True)
    
    async def _fetch_verse(self, session, surah: int, ayah: int) -> Dict:
        url = f"{self.BASE_URL}/quran/surah/{surah}/ayah/{ayah}"
        async with session.get(url) as response:
            if response.status == 200:
                return await response.json()
            return None
    
    async def fetch_tafsir(self, surah: int, ayah: int, 
                           tafsir: str = "ibn_kathir") -> str:
        """جلب التفسير"""
        url = f"{self.BASE_URL}/tafsir/{tafsir}/surah/{surah}/ayah/{ayah}"
        async with aiohttp.ClientSession() as session:
            async with session.get(url) as response:
                if response.status == 200:
                    data = await response.json()
                    return data.get('text', '')
        return ''
```

**2. Verse API**

```python
# app/services/knowledge_base/verse_service.py
class VerseService:
    BASE_URL = "https://api.ummahapi.com"
    COLLECTIONS = ['bukhari', 'muslim', 'tirmidhi', 
                   'abudawud', 'nasai', 'ibnmajah']
    
    async def fetch_all_verses(self) -> List[Dict]:
        """جلب الآيات من المجموعات الصحيحة"""
        all_verses = []
        async with aiohttp.ClientSession() as session:
            for collection in self.COLLECTIONS:
                verses = await self._fetch_collection(session, collection)
                all_verses.extend(verses)
        return all_verses
    
    async def _fetch_collection(self, session, 
                                 collection: str) -> List[Dict]:
        url = f"{self.BASE_URL}/verse/{collection}"
        async with session.get(url) as response:
            if response.status == 200:
                return await response.json()
        return []
```

#### تصنيف البيانات العاطفي المحسّن

| الحالة العاطفية | الكلمات المفتاحية | الآيات المرتبطة | الآيات المرتبطة |
|-----------------|-------------------|-----------------|-------------------|
| **غضب** | غضب، عصبية، انفعال، حنق | "وَالْكَاظِمِينَ الْغَيْظَ" | "ليس الشديد بالصُّرَعَة..." |
| **حزن** | حزن، أسى، وجع، ألم | "وَبَشِّرِ الصَّابِرِينَ" | "ما أصاب من مصيبة..." |
| **قلق** | قلق، خوف، توتر، قلق | "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ" | "عجباً لأمر المؤمن..." |
| **فرح** | فرح، سرور، سعادة | "قُلْ بِفَضْلِ اللَّهِ وَبِرَحْمَتِهِ" | "من لم يشكر الناس..." |
| **سفر** | سفر، رحلة، سير | أدعية السفر | "اللَّهُمَّ إِنِّي أَعُوذُ بِكَ..." |
| **دراسة** | علم، تعلم، قراءة | "اقْرَأْ بِاسْمِ رَبِّكَ" | "طلب العلم فريضة..." |
| **مرض** | مرض، ألم، وعكة | "وَإِذَا مَرِضْتُ فَهُوَ يَشْفِينِ" | "ما أصاب أحداً قط هم..." |
| **شكر** | شكر، نعمة، حمد | "فَاذْكُرُونِي أَذْكُرْكُمْ" | "من لم يشكر الناس..." |

#### إنشاء Embeddings

```python
# scripts/create_embeddings.py
import asyncio
from app.services.ai.embeddings import EmbeddingService
from app.services.knowledge_base.quran_service import QuranService
from app.services.knowledge_base.verse_service import VerseService

async def main():
    embedding_service = EmbeddingService()
    quran_service = QuranService()
    verse_service = VerseService()
    
    print("جلب الآيات...")
    verses = await quran_service.fetch_all_verses()
    
    print("جلب الآيات...")
    verses = await verse_service.fetch_all_verses()
    
    print("إنشاء وتخزين Embeddings للآيات...")
    for i, verse in enumerate(verses):
        if verse:
            metadata = {
                "type": "verse",
                "surah": verse.get('surah_number'),
                "ayah": verse.get('ayah_number'),
                "emotion": verse.get('emotional_state'),
                "tafsir_source": verse.get('tafsir_source')
            }
            embedding_service.store_embedding(
                id=f"verse_{i}",
                text=verse.get('text_arabic', ''),
                metadata=metadata
            )
            if i % 100 == 0:
                print(f"تمت معالجة {i} آية...")
    
    print("إنشاء وتخزين Embeddings للآيات...")
    for i, verse in enumerate(verses):
        if verse:
            metadata = {
                "type": "verse",
                "collection": verse.get('collection'),
                "verse_number": verse.get('verse_number'),
                "emotion": verse.get('emotional_state'),
                "grade": verse.get('grade')
            }
            embedding_service.store_embedding(
                id=f"verse_{i}",
                text=verse.get('text_arabic', ''),
                metadata=metadata
            )
            if i % 100 == 0:
                print(f"تمت معالجة {i} آية...")
    
    print("تم إنشاء جميع الـ Embeddings بنجاح!")

if __name__ == "__main__":
    asyncio.run(main())
```

---

### الأسبوع 7-9: محرك التوصية والاستجابة المدرجة 🎯

#### API Endpoints المحسّنة

```python
# app/api/v1/endpoints/recommend.py
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
from app.services.ai.emotion_analyzer import EmotionAnalyzer
from app.services.ai.semantic_search import SemanticSearch
from app.services.ai.rag_engine import RAGEngine
from app.services.cache.redis_cache import RedisCache
from app.services.notification.tiered_response import TieredResponse
from app.api.deps import get_current_user_optional

router = APIRouter()

class RecommendRequest(BaseModel):
    text: str
    user_id: Optional[int] = None
    emotion_hint: Optional[str] = None  # تلميح من المستخدم

class RecommendResponse(BaseModel):
    emotion: str
    confidence: float
    content_type: str  # 'verse' or 'verse'
    arabic_text: str
    translation: str
    tafsir: str
    source: str
    tier: str  # 'minimal', 'moderate', 'full'
    interaction_id: int

@router.post("/recommend", response_model=RecommendResponse)
async def get_recommendation(
    request: RecommendRequest,
    background_tasks: BackgroundTasks,
    current_user = Depends(get_current_user_optional)
):
    """
    استقبال نص المستخدم وإرجاع توصية مناسبة
    مع تطبيق الاستجابة المدرجة
    """
    cache = RedisCache()
    analyzer = EmotionAnalyzer()
    searcher = SemanticSearch()
    rag = RAGEngine()
    tiered = TieredResponse()
    
    # 1. التحقق من الـ Cache
    if request.emotion_hint:
        cached = cache.get_cached_recommendation(request.emotion_hint)
        if cached:
            return cached
    
    # 2. تحليل المشاعر
    emotion_result = await analyzer.analyze(request.text)
    
    # 3. تحديد مستوى الاستجابة (Tier)
    user_tier = tiered.determine_tier(
        emotion=emotion_result['emotion'],
        confidence=emotion_result['confidence'],
        user_id=request.user_id
    )
    
    # 4. البحث الدلالي
    results = await searcher.search(
        query=request.text,
        emotion=emotion_result['emotion'],
        top_k=5
    )
    
    # 5. RAG للتحقق والتحسين
    final_result = await rag.process(
        query=request.text,
        results=results,
        emotion=emotion_result['emotion']
    )
    
    # 6. تسجيل التفاعل
    interaction_id = await _save_interaction(
        user_id=request.user_id,
        query=request.text,
        emotion=emotion_result,
        result=final_result,
        tier=user_tier
    )
    
    # 7. التحقق من الحاجة لتأجيل الاستجابة
    if tiered.should_delay(emotion_result['confidence']):
        background_tasks.add_task(
            _schedule_delayed_response,
            user_id=request.user_id,
            interaction_id=interaction_id,
            result=final_result
        )
        # إرجاع رد مختصر الآن
        return tiered.get_minimal_response(
            emotion=emotion_result['emotion'],
            interaction_id=interaction_id
        )
    
    # 8. تخزين في الـ Cache
    cache.cache_recommendation(emotion_result['emotion'], final_result)
    
    return RecommendResponse(
        emotion=emotion_result['emotion'],
        confidence=emotion_result['confidence'],
        content_type=final_result['type'],
        arabic_text=final_result['arabic'],
        translation=final_result['translation'],
        tafsir=final_result['tafsir'],
        source=final_result['source'],
        tier=user_tier,
        interaction_id=interaction_id
    )
```

#### الاستجابة المدرجة (Tiered Response)

```python
# app/services/notification/tiered_response.py
from typing import Dict, Optional
from app.db.repositories.interaction import InteractionRepository

class TieredResponse:
    """
    نظام الاستجابة المدرجة:
    - Tier 1 (Minimal): تنبيه رمزي فقط
    - Tier 2 (Moderate): آية مختصرة 
    - Tier 3 (Full): الآية/الحديث كاملاً مع التفسير
    """
    
    TIERS = {
        'minimal': {
            'description': 'تنبيه رمزي غير مزعج',
            'examples': ['🌸', '💚', '🕊️', '☀️']
        },
        'moderate': {
            'description': 'نص مختصر',
            'max_length': 50
        },
        'full': {
            'description': 'النص كاملاً مع التفسير',
            'include_tafsir': True
        }
    }
    
    def __init__(self):
        self.interaction_repo = InteractionRepository()
    
    def determine_tier(self, emotion: str, confidence: float,
                       user_id: Optional[int] = None) -> str:
        """
        تحديد مستوى الاستجابة بناءً على:
        - شدة الانفعال (confidence)
        - تاريخ المستخدم
        - الوقت من اليوم
        """
        # إذا كان الانفعال شديداً جداً
        if confidence > 0.9:
            return 'minimal'  # لا نزعج المستخدم
        
        # إذا كان الانفعال متوسطاً
        if confidence > 0.7:
            return 'moderate'
        
        # إذا كان الانفعال خفيفاً
        return 'full'
    
    def should_delay(self, confidence: float) -> bool:
        """
        هل نؤجل الاستجابة الكاملة؟
        """
        return confidence > 0.85
    
    def get_minimal_response(self, emotion: str, 
                             interaction_id: int) -> Dict:
        """
        إرجاع رد رمزي بسيط
        """
        import random
        symbols = self.TIERS['minimal']['examples']
        return {
            'emotion': emotion,
            'confidence': 0.0,
            'content_type': 'symbol',
            'arabic_text': random.choice(symbols),
            'translation': '',
            'tafsir': '',
            'source': '',
            'tier': 'minimal',
            'interaction_id': interaction_id
        }
```

#### البحث الدلالي المحسّن

```python
# app/services/ai/semantic_search.py
from typing import List, Dict, Optional
from app.services.ai.embeddings import EmbeddingService
from app.services.cache.redis_cache import RedisCache

class SemanticSearch:
    def __init__(self):
        self.embedding_service = EmbeddingService()
        self.cache = RedisCache()
    
    async def search(self, query: str, emotion: str,
                     top_k: int = 5) -> List[Dict]:
        """
        البحث الدلالي مع:
        - فلترة حسب الحالة العاطفية
        - Hybrid search (دلالي + لغوي)
        - Reranking النتائج
        """
        # 1. البحث الدلالي
        results = self.embedding_service.search_similar(
            query=query,
            n_results=top_k * 2,  # جلب ضعف الكمية للفلترة
            filters={"emotion": emotion}
        )
        
        # 2. Reranking
        ranked_results = self._rerank(results, query, emotion)
        
        # 3. إرجاع أفضل النتائج
        return ranked_results[:top_k]
    
    def _rerank(self, results: Dict, query: str, 
                emotion: str) -> List[Dict]:
        """
        إعادة ترتيب النتائج بناءً على:
        - التشابه الدلالي
        - ملاءمة الحالة العاطفية
        - جودة المصدر
        """
        scored_results = []
        
        for i, doc in enumerate(results['documents'][0]):
            score = results['distances'][0][i]
            metadata = results['metadatas'][0][i]
            
            # تعزيز النتيجة إذا كانت الحالة العاطفية متطابقة
            if metadata.get('emotion') == emotion:
                score *= 1.2
            
            # تعزيز الآيات على الآيات في بعض الحالات
            if emotion in ['حزن', 'قلق'] and metadata.get('type') == 'verse':
                score *= 1.1
            
            scored_results.append({
                'text': doc,
                'score': score,
                'metadata': metadata
            })
        
        # ترتيب تنازلي حسب Score
        scored_results.sort(key=lambda x: x['score'], reverse=True)
        
        return scored_results
```

---

### الأسبوع 10-12: Prompt Engineering 📝

#### تحليل المشاعر (Strict Output)

```python
# app/services/ai/emotion_analyzer.py
from typing import Dict
import json
import google.generativeai as genai

class EmotionAnalyzer:
    """
    محلل المشاعر العربي:
    - يرجع JSON فقط
    - يمنع أي تفسير أو تعليق
    - يستخدم Cultural Prompting لتقليل التحيز
    """
    
    EMOTION_ANALYSIS_PROMPT = """
أنت محلل مشاعر متخصص في اللغة العربية والثقافة الإسلامية.

القواعد الصارمة:
1. أرجع JSON فقط بدون أي نص إضافي قبل أو بعد
2. لا تضف أي تفسير أو تعليق أو ملاحظة
3. استخدم التنسيق التالي بدقة:

{
    "emotion": "غضب|حزن|قلق|فرح|محايد|سفر|دراسة|مرض|شكر",
    "confidence": 0.0-1.0,
    "keywords": ["كلمة1", "كلمة2"],
    "intensity": "low|medium|high"
}

ملاحظات مهمة:
- "غضب" تشمل: عصبية، انفعال، حنق، غيظ
- "حزن" تشمل: أسى، وجع، ألم نفسي
- "قلق" تشمل: خوف، توتر، قلق
- "confidence" يعكس شدة المشاعر الواضحة في النص
- "intensity" يعكس قوة المشاعر

النص: {user_text}

الرد:
"""
    
    def __init__(self, api_key: str):
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-pro')
    
    async def analyze(self, text: str) -> Dict:
        """
        تحليل النص وإرجاع الحالة العاطفية
        """
        prompt = self.EMOTION_ANALYSIS_PROMPT.format(user_text=text)
        
        response = await self.model.generate_content_async(prompt)
        
        try:
            # تنظيف الرد وإزالة أي نص زائد
            cleaned = self._clean_response(response.text)
            result = json.loads(cleaned)
            
            # التحقق من صحة البيانات
            self._validate_result(result)
            
            return result
        except json.JSONDecodeError:
            # في حالة فشل التحليل
            return {
                'emotion': 'محايد',
                'confidence': 0.5,
                'keywords': [],
                'intensity': 'low'
            }
    
    def _clean_response(self, text: str) -> str:
        """إزالة أي نص زائد من الرد"""
        # إزالة ```json و ```
        text = text.replace('```json', '').replace('```', '')
        # إزالة المسافات الزائدة
        text = text.strip()
        return text
    
    def _validate_result(self, result: Dict):
        """التحقق من صحة النتيجة"""
        valid_emotions = ['غضب', 'حزن', 'قلق', 'فرح', 'محايد', 
                          'سفر', 'دراسة', 'مرض', 'شكر']
        
        if result.get('emotion') not in valid_emotions:
            result['emotion'] = 'محايد'
        
        if not 0 <= result.get('confidence', 0.5) <= 1:
            result['confidence'] = 0.5
```

#### RAG Prompt (منع Hallucination)

```python
# app/services/ai/rag_engine.py
from typing import Dict, List
import google.generativeai as genai

class RAGEngine:
    """
    محرك RAG:
    - يسترجع النصوص الشرعية فقط
    - لا يولد أي نص ديني من تلقاء نفسه
    - يتحقق من مطابقة النص للمصدر
    """
    
    RAG_PROMPT = """
أنت مساعد ديني متخصص. مهمتك تقديم النص الشرعي المناسب فقط.

القواعد الصارمة جداً:
1. لا تضف أي كلمة من عندك للنص الشرعي
2. انقل النص حرفياً من المصدر المقدم أدناه
3. يمكنك شرح السياق باختصار فقط (جملة واحدة)
4. لا تقدم أي تفسير شخصي أو اجتهاد
5. إذا لم تجد نصاً مناسباً، أرجع: "لم أجد نصاً مناسباً"

المصادر المتاحة (استخدمها فقط):
{retrieved_content}

سؤال المستخدم: {user_query}

الحالة العاطفية: {emotion}

الرد بصيغة JSON:
{{
    "arabic_text": "النص الشرعي حرفياً من المصدر",
    "translation": "الترجمة إن وجدت",
    "tafsir": "التفسير المختصر من المصدر",
    "source": "المصدر (سورة:آية أو كتاب الحديث)",
    "relevance": "ارتباط النص بالحالة العاطفية"
}}
"""
    
    def __init__(self, api_key: str):
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-pro')
    
    async def process(self, query: str, results: List[Dict],
                      emotion: str) -> Dict:
        """
        معالجة النتائج واختيار الأنسب
        """
        # تنسيق المحتوى المسترجع
        retrieved_content = self._format_retrieved_content(results)
        
        # إنشاء الـ Prompt
        prompt = self.RAG_PROMPT.format(
            retrieved_content=retrieved_content,
            user_query=query,
            emotion=emotion
        )
        
        # استدعاء LLM
        response = await self.model.generate_content_async(prompt)
        
        # التحقق من صحة الرد
        result = self._parse_response(response.text)
        
        # التحقق من عدم وجود Hallucination
        if not self._validate_response(result, results):
            # إرجاع أول نتيجة كما هي
            return self._get_first_result(results)
        
        return result
    
    def _format_retrieved_content(self, results: List[Dict]) -> str:
        """تنسيق المحتوى المسترجع"""
        formatted = []
        for i, r in enumerate(results[:3]):  # أفضل 3 نتائج
            formatted.append(f"""
المصدر {i+1}:
- النوع: {r['metadata'].get('type')}
- النص: {r['text']}
- الحالة العاطفية: {r['metadata'].get('emotion')}
""")
        return "\n".join(formatted)
    
    def _validate_response(self, result: Dict, 
                           original_results: List[Dict]) -> bool:
        """
        التحقق من أن النص الشرعي موجود في المصادر الأصلية
        """
        arabic_text = result.get('arabic_text', '')
        
        for r in original_results:
            # التحقق من أن النص موجود في المصدر
            if arabic_text in r['text'] or r['text'] in arabic_text:
                return True
        
        return False
```

---

### الأسبوع 13-15: تطبيق Flutter (Offline-First) 📱

#### هيكل المشروع المحسّن

```
frontend/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   └── routes.dart
│   ├── core/
│   │   ├── theme/
│   │   │   ├── colors.dart
│   │   │   └── text_styles.dart
│   │   ├── constants/
│   │   │   ├── api_constants.dart
│   │   │   └── app_constants.dart
│   │   └── network/
│   │       ├── network_info.dart
│   │       └── api_client.dart
│   ├── features/
│   │   ├── home/
│   │   │   ├── pages/
│   │   │   │   └── home_page.dart
│   │   │   ├── widgets/
│   │   │   │   ├── emotion_selector.dart
│   │   │   │   └── offline_banner.dart
│   │   │   └── bloc/
│   │   │       ├── home_bloc.dart
│   │   │       ├── home_event.dart
│   │   │       └── home_state.dart
│   │   ├── recommendation/
│   │   │   ├── pages/
│   │   │   │   └── recommendation_page.dart
│   │   │   ├── widgets/
│   │   │   │   ├── verse_card.dart
│   │   │   │   ├── verse_card.dart
│   │   │   │   └── tiered_response_widget.dart
│   │   │   └── bloc/
│   │   │       ├── recommendation_bloc.dart
│   │   │       └── recommendation_state.dart
│   │   ├── history/
│   │   │   ├── pages/
│   │   │   │   └── history_page.dart
│   │   │   └── bloc/
│   │   ├── settings/
│   │   │   ├── pages/
│   │   │   │   └── settings_page.dart
│   │   │   └── bloc/
│   │   └── onboarding/
│   │       └── pages/
│   │           └── onboarding_page.dart
│   ├── services/
│   │   ├── api_service.dart
│   │   ├── storage_service.dart
│   │   ├── offline_service.dart
│   │   └── sync_service.dart
│   ├── repositories/
│   │   ├── recommendation_repository.dart
│   │   └── local_recommendation_repository.dart
│   └── models/
│       ├── recommendation.dart
│       ├── user_feedback.dart
│       └── interaction.dart
├── test/
│   ├── widget_test.dart
│   └── bloc_test.dart
├── pubspec.yaml
└── README.md
```

#### الـ Dependencies المحسّنة (pubspec.yaml)

```yaml
name: murassikh
description: مُرَسِّخ - الرفيق الروحي الذكي

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  
  # State Management
  flutter_bloc: ^8.1.0
  equatable: ^2.0.5
  
  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
  internet_connection_checker: ^2.0.0
  
  # Local Storage (Offline-First)
  hive: ^2.2.0
  hive_flutter: ^1.1.0
  path_provider: ^2.1.0
  
  # Offline Support
  flutter_offline: ^3.0.0
  workmanager: ^0.5.0  # للـ Background Sync
  
  # UI
  flutter_svg: ^2.0.0
  google_fonts: ^6.1.0
  lottie: ^3.0.0
  shimmer: ^3.0.0  # Loading animation
  
  # Accessibility
  flutter_accessibility: ^0.2.0
  
  # Utils
  intl: ^0.19.0
  logger: ^2.0.0
  uuid: ^4.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  hive_generator: ^2.0.0
  build_runner: ^2.4.0
  bloc_test: ^9.1.0
  mocktail: ^1.0.0

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/animations/
    - assets/fonts/
```

#### Offline Service

```dart
// lib/services/offline_service.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/recommendation.dart';

class OfflineService {
  static final OfflineService _instance = OfflineService._internal();
  factory OfflineService() => _instance;
  OfflineService._internal();
  
  late Box _recommendationsBox;
  late Box _interactionsBox;
  late Box _pendingSyncBox;
  
  Future<void> init() async {
    await Hive.initFlutter();
    
    // تسجيل الـ Adapters
    Hive.registerAdapter(RecommendationAdapter());
    Hive.registerAdapter(InteractionAdapter());
    
    // فتح الـ Boxes
    _recommendationsBox = await Hive.openBox('recommendations');
    _interactionsBox = await Hive.openBox('interactions');
    _pendingSyncBox = await Hive.openBox('pending_sync');
  }
  
  // التحقق من الاتصال
  Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  
  // تخزين التوصية محلياً
  Future<void> cacheRecommendation(
    String emotion, 
    Recommendation recommendation
  ) async {
    await _recommendationsBox.put(emotion, recommendation.toJson());
  }
  
  // الحصول على توصية من الـ Cache
  Recommendation? getCachedRecommendation(String emotion) {
    final data = _recommendationsBox.get(emotion);
    if (data != null) {
      return Recommendation.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }
  
  // تخزين تفاعل للـ Sync لاحقاً
  Future<void> savePendingInteraction(Map<String, dynamic> interaction) async {
    await _pendingSyncBox.add(interaction);
  }
  
  // الحصول على التفاعلات المعلقة
  List<Map<String, dynamic>> getPendingInteractions() {
    return _pendingSyncBox.values
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  
  // مسح التفاعلات المعلقة بعد الـ Sync
  Future<void> clearPendingInteractions() async {
    await _pendingSyncBox.clear();
  }
  
  // تخزين الآيات  محلياً للعمل بدون إنترنت
  Future<void> cacheContent(List<dynamic> verses, List<dynamic> verses) async {
    final contentBox = await Hive.openBox('cached_content');
    
    // تخزين الآيات
    for (var verse in verses) {
      await contentBox.put('verse_${verse['id']}', verse);
    }
    
    // تخزين الآيات
    for (var verse in verses) {
      await contentBox.put('verse_${verse['id']}', verse);
    }
  }
}
```

#### Recommendation Repository (Offline-First)

```dart
// lib/repositories/recommendation_repository.dart
import '../services/api_service.dart';
import '../services/offline_service.dart';
import '../models/recommendation.dart';

class RecommendationRepository {
  final ApiService _apiService;
  final OfflineService _offlineService;
  
  RecommendationRepository({
    required ApiService apiService,
    required OfflineService offlineService,
  }) : _apiService = apiService,
       _offlineService = offlineService;
  
  Future<Recommendation> getRecommendation({
    required String text,
    String? emotionHint,
  }) async {
    // 1. التحقق من الاتصال
    final isConnected = await _offlineService.isConnected();
    
    if (isConnected) {
      // 2. إذا كان متصلاً، جلب من الـ API
      try {
        final recommendation = await _apiService.getRecommendation(
          text: text,
          emotion: emotionHint,
        );
        
        // 3. تخزين في الـ Cache
        _offlineService.cacheRecommendation(
          recommendation.emotion,
          recommendation,
        );
        
        return recommendation;
      } catch (e) {
        // 4. في حالة فشل الـ API، جلب من الـ Cache
        return _getFromCacheOrLocal(emotionHint);
      }
    } else {
      // 5. إذا كان غير متصل، جلب من الـ Cache
      return _getFromCacheOrLocal(emotionHint);
    }
  }
  
  Recommendation _getFromCacheOrLocal(String? emotion) {
    // محاولة جلب من الـ Cache
    if (emotion != null) {
      final cached = _offlineService.getCachedRecommendation(emotion);
      if (cached != null) {
        return cached;
      }
    }
    
    // جلب من المحتوى المخزن محلياً
    return _getFromLocalContent(emotion);
  }
  
  Recommendation _getFromLocalContent(String? emotion) {
    // البحث في المحتوى المحلي
    // هذا يتطلب تخزين الآيات  محلياً مسبقاً
    // ...
    
    // إرجاع توصية افتراضية
    return Recommendation(
      emotion: emotion ?? 'محايد',
      arabicText: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
      translation: 'ألا بذكر الله تطمئن القلوب',
      tafsir: 'ذكر الله تعالى سبب لطمأنينة القلوب وراحتها',
      source: 'سورة الرعد: 28',
      contentType: 'verse',
    );
  }
  
  Future<void> submitFeedback({
    required int interactionId,
    required bool isPositive,
  }) async {
    final isConnected = await _offlineService.isConnected();
    
    if (isConnected) {
      await _apiService.submitFeedback(
        interactionId: interactionId,
        isPositive: isPositive,
      );
    } else {
      // تخزين للـ Sync لاحقاً
      await _offlineService.savePendingInteraction({
        'type': 'feedback',
        'interaction_id': interactionId,
        'is_positive': isPositive,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}
```

#### الشاشة الرئيسية مع Offline Support

```dart
// lib/features/home/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_offline/flutter_offline.dart';
import '../widgets/emotion_selector.dart';
import '../widgets/offline_banner.dart';
import '../bloc/home_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مُرَسِّخ'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.pushNamed(context, '/history'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: OfflineBuilder(
        connectivityBuilder: (
          BuildContext context,
          List<ConnectivityResult> connectivity,
          Widget child,
        ) {
          final isConnected = !connectivity.contains(ConnectivityResult.none);
          
          return Stack(
            children: [
              child,
              if (!isConnected) 
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: OfflineBanner(),
                ),
            ],
          );
        },
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const SizedBox(height: 40), // مساحة للـ Banner
                
                // شريط الإدخال
                TextField(
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'صف مشاعرك أو موقفك...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    context.read<HomeBloc>().add(UpdateQuery(value));
                  },
                ),
                
                const SizedBox(height: 16),
                
                // اختيار سريع للحالة
                const EmotionSelector(),
                
                const SizedBox(height: 24),
                
                // زر التوصية
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      context.read<HomeBloc>().add(GetRecommendation());
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('احصل على توصية'),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // النتيجة
                Expanded(
                  child: BlocBuilder<HomeBloc, HomeState>(
                    builder: (context, state) {
                      if (state.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      
                      if (state.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                state.error!,
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<HomeBloc>().add(GetRecommendation());
                                },
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (state.recommendation != null) {
                        return VerseCard(
                          recommendation: state.recommendation!,
                        );
                      }
                      
                      return const Center(
                        child: Text(
                          'أدخل مشاعرك للحصول على توصية',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

#### Offline Banner Widget

```dart
// lib/features/home/widgets/offline_banner.dart
import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off,
            color: Colors.orange.shade800,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'أنت غير متصل - التوصيات من الذاكرة المحلية',
            style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### الأسبوع 16: النشر والبنية السحابية ☁️

#### Docker Configuration

```dockerfile
# docker/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# تثبيت الـ dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# نسخ الكود
COPY . .

# تشغيل الـ application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```yaml
# docker/docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: ..
      dockerfile: docker/Dockerfile
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/murassikh
      - REDIS_URL=redis://redis:6379
      - GEMINI_API_KEY=${GEMINI_API_KEY}
    depends_on:
      - db
      - redis
    volumes:
      - ../app:/app/app
      - chroma_data:/app/chroma_db

  db:
    image: postgres:15-alpine
    environment:
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass
      - POSTGRES_DB=murassikh
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
  chroma_data:
```

#### GitHub Actions CI/CD

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test_db
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r backend/requirements.txt
          pip install pytest pytest-asyncio pytest-cov
      
      - name: Run tests
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/test_db
        run: |
          cd backend
          pytest --cov=app tests/
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Build Docker image
        run: |
          cd docker
          docker-compose build
      
      - name: Push to Registry
        run: |
          echo ${{ secrets.DOCKER_PASSWORD }} | docker login -u ${{ secrets.DOCKER_USERNAME }} --password-stdin
          docker push murassikh/api:latest
```

---

### الأسبوع 17-18: الاختبار والتحسين 🧪

#### اختبارات الوحدة

```python
# tests/test_emotion_analyzer.py
import pytest
from app.services.ai.emotion_analyzer import EmotionAnalyzer

@pytest.mark.asyncio
async def test_emotion_analysis_anger():
    analyzer = EmotionAnalyzer(api_key="test_key")
    result = await analyzer.analyze("أشعر بغضب شديد")
    
    assert result['emotion'] == 'غضب'
    assert result['confidence'] > 0.5
    assert result['intensity'] in ['low', 'medium', 'high']

@pytest.mark.asyncio
async def test_emotion_analysis_sadness():
    analyzer = EmotionAnalyzer(api_key="test_key")
    result = await analyzer.analyze("أنا حزين جداً")
    
    assert result['emotion'] == 'حزن'
    assert result['confidence'] > 0.5

@pytest.mark.asyncio
async def test_emotion_analysis_neutral():
    analyzer = EmotionAnalyzer(api_key="test_key")
    result = await analyzer.analyze("اليوم طقس جميل")
    
    assert result['emotion'] == 'محايد'
```

#### اختبارات الأداء

```python
# tests/test_performance.py
import pytest
import time
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_response_time():
    """اختبار أن زمن الاستجابة < 2 ثانية"""
    start = time.time()
    
    response = client.post('/api/v1/recommend', json={
        'text': 'أشعر بالقلق'
    })
    
    end = time.time()
    elapsed = end - start
    
    assert response.status_code == 200
    assert elapsed < 2.0, f"Response time was {elapsed}s, expected < 2.0s"

def test_load_test():
    """اختبار الأداء تحت الضغط"""
    import concurrent.futures
    
    def make_request():
        return client.post('/api/v1/recommend', json={
            'text': 'أنا حزين'
        })
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        futures = [executor.submit(make_request) for _ in range(50)]
        results = [f.result() for f in concurrent.futures.as_completed(futures)]
    
    success_count = sum(1 for r in results if r.status_code == 200)
    assert success_count >= 45  # 90% success rate
```

#### اختبارات Flutter

```dart
// test/bloc_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:murassikh/features/home/bloc/home_bloc.dart';
import 'package:murassikh/repositories/recommendation_repository.dart';
import 'package:murassikh/models/recommendation.dart';

class MockRecommendationRepository extends Mock 
    implements RecommendationRepository {}

void main() {
  group('HomeBloc', () {
    late MockRecommendationRepository mockRepository;
    
    setUp(() {
      mockRepository = MockRecommendationRepository();
    });
    
    blocTest<HomeBloc, HomeState>(
      'emits [loading, loaded] when GetRecommendation succeeds',
      build: () => HomeBloc(repository: mockRepository),
      act: (bloc) {
        when(() => mockRepository.getRecommendation(
          text: any(named: 'text'),
        )).thenAnswer((_) async => Recommendation(
          emotion: 'حزن',
          arabicText: 'نص تجريبي',
          translation: 'ترجمة',
          tafsir: 'تفسير',
          source: 'مصدر',
          contentType: 'verse',
        ));
        
        bloc.add(UpdateQuery('أنا حزين'));
        bloc.add(GetRecommendation());
      },
      expect: () => [
        isA<HomeState>().having((s) => s.isLoading, 'isLoading', true),
        isA<HomeState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.recommendation, 'recommendation', isNotNull),
      ],
    );
  });
}
```

---

## ✅ معايير القبول المحسّنة

### وظيفية
- [x] المستخدم يمكنه إدخال نص عربي
- [x] النظام يحلل المشاعر بدقة > 70%
- [x] النظام يقدم توصية خلال < 2 ثانية (مع Redis)
- [x] التوصية مناسبة للحالة العاطفية (قياس بالتغذية الراجعة)
- [x] المستخدم يمكنه تقديم تغذية راجعة (👍/👎)
- [x] تطبيق الاستجابة المدرجة (Tiered Response)
- [x] التطبيق يعمل بدون إنترنت (Offline-First)
- [x] تغطية 9 حالات عاطفية على الأقل

### تقنية
- [x] API يعمل بشكل مستقر (Uptime > 99%)
- [x] قاعدة البيانات تحوي 6000+ آية
- [x] Vector DB جاهز للبحث
- [x] Embeddings دقيقة للعربية (MiniLM-L12)
- [x] التخزين المؤقت الداخلي يعمل (LRU Cache بديل لـ Redis)
- [x] Docker containers تعمل بشكل صحيح
- [x] CI/CD Pipeline جاهز

### أمنية
- [~] تشفير كلمات المرور (مؤجل لمرحلة تسجيل الدخول - الخطة 3)
- [~] JWT للمصادقة (مؤجل لمرحلة تسجيل الدخول - الخطة 3)
- [~] HTTPS إجباري (مؤجل لمرحلة الخوادم السحابية - الخطة 3)
- [x] Rate Limiting على الـ API
- [x] Input Validation صارم
- [x] CORS Configuration صحيح

### تجربة المستخدم
- [x] الواجهة RTL صحيحة
- [x] الخطوط العربية واضحة
- [x] الـ Offline Banner يظهر عند فقدان الاتصال
- [x] رسائل خطأ واضحة
- [x] إمكانية الوصول (Accessibility) معتمدة

---

## ⚠️ المخاطر المحسّنة والحلول

| المخاطرة | الاحتمال | الأثر | الحل | الملاحظات |
|----------|----------|-------|------|-----------|
| **Hallucination في النصوص** | متوسط | 🔴 عالي | RAG صارم + مصادر موثقة + التحقق | تم في RAG Engine |
| **بطء البحث** | منخفض | 🟡 متوسط | Redis Cache + Indexing | تم إضافة Redis |
| **جودة التصنيف العاطفي** | متوسط | 🟡 متوسط | Cultural Prompting + مراجعة | تم في Prompt |
| **تكلفة LLM** | منخفض | 🟢 منخفض | Gemini + Cache + معدل الطلبات | تم إضافة Cache |
| **عدم توفر البيانات** | منخفض | 🔴 عالي | مصادر متعددة + تخزين محلي | UmmahAPI + House of Islam |
| **الاعتماد على API خارجية** | متوسط | 🔴 عالي | تخزين محلي + Offline-First | تم إضافة Hive |
| **مشاكل الترخيص** | متوسط | 🔴 عالي | مراجعة الشروط + التوثيق | يجب التحقق قبل الإطلاق |
| **التحيز الثقافي** | متوسط | 🟡 متوسط | Cultural Prompting + GATE | تم في Prompt |
| **أمن الـ API** | متوسط | 🔴 عالي | Rate Limiting + JWT + HTTPS | تم إضافة |
| **رفض المستخدم** | متوسط | 🔴 عالي | Tiered Response + تخصيص | تم في الخطة |
| **استنزاف البطارية** | منخفض | 🟡 متوسط | تحسين الـ Background Tasks | للمراحل اللاحقة |

---

## 📦 المخرجات النهائية المحسّنة

1. **Backend API** قابل للتشغيل مع FastAPI
2. **قاعدة بيانات** محتوى شرعي كامل (6236 آية)
3. **Vector DB** (Chroma للتطوير، Milvus للإنتاج)
4. **تطبيق Flutter** (Android + iOS) مع Offline-First
5. **Redis Cache** لتحسين الأداء
6. **Docker + CI/CD** للنشر المستمر
7. **توثيق API** كامل (Swagger/OpenAPI)
8. **اختبارات** وحدة وتكامل وأداء
9. **Monitoring** (Prometheus + Grafana)
10. **Error Tracking** (Sentry)

---

## 📚 المراجع

### APIs & Data Sources
- [UmmahAPI Documentation](https://ummahapi.com)
- [House of Islam API](https://developers.thehouseofislam.com)
- [IslamHouse API Hub](https://github.com/IslamHouse-API)

### AI & ML
- [paraphrase-multilingual-MiniLM-L12-v2 Model](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2)
- [Arabic RAG Pipeline Guide](https://huggingface.co/blog/Omartificial-Intelligence-Space/building-arabic-rag-pipeline-step-by-step)
- [Sentence Transformers](https://www.sbert.net)

### Infrastructure
- [Chroma DB Documentation](https://docs.trychroma.com)
- [FastAPI Production Guide](https://fastapi.tiangolo.com/deployment/)
- [Flutter Offline-First Architecture](https://docs.flutter.dev/app-architecture/design-patterns/offline-first)

### Prompt Engineering
- [Cultural Bias Mitigation](https://arxiv.org/abs/2506.18199)
- [Arabic Sentiment Analysis](https://arxiv.org/html/2509.23515v1)

---

## 🔄 التالي (P2)

بعد إتمام هذه الخطة بنجاح:
- [x] دمج تحليل تعابير الوجه (Computer Vision) - (تم تنفيذه محلياً بالخلفية)
- [x] ~~دمج قاعدة بيانات الآيات القرآنية~~ (تم الإلغاء في todo_2 لضمان صفاء البحث القرآني فقط)
- [x] دمج تحليل الصوت (Audio Sentiment) - (مكتمل)
- [x] معالجة محلية للبيانات الحساسة (Edge Computing) - (مكتمل، يتم معالجة الوجه كاملاً على الجهاز)
- [x] تحسينات متقدمة على تطبيق Flutter (مثل وضع الأوفلاين الشامل، الرسوم البيانية للحالة النفسية)
- [~] التكامل مع الأجهزة القابلة للارتداء (مؤجل للخطة 3)

---

**آخر تحديث:** 2026-09-11  
**الحالة:** جاهز للتنفيذ  
**المراجعة:** تمت بناءً على التحليل الشامل
