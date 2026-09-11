# 🗃️ مخطط ER لقاعدة البيانات (Entity-Relationship Diagram)

مخطط تفصيلي لهيكل قاعدة البيانات وعلاقاتها في نظام مُرَسِّخ.

---

## 📊 المخطط العام (ER Diagram)

### Diagram Legend:
```
┌─────────────┐        ┌─────────────┐
│    Entity   │        │  Attribute  │
│   (Table)   │        │   (Column)  │
└─────────────┘        └─────────────┘

Relationships:
    ────  One-to-One
    ────  One-to-Many (1:N)
    ────  Many-to-Many (M:N)
    ────  Optional
```

### المخطط الكامل:

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                قاعدة بيانات مُرَسِّخ                                     │
└────────────────────────────┬─────────────────────┬──────────────────────────────────────┘
                             │                     │
                             ▼                     ▼
                     ┌──────────────┐     ┌──────────────┐
                     │    users     │     │  verses      │
                     ├──────────────┤     ├──────────────┤
                     │PK id         │     │PK id         │
                     │  username    │     │  surah_number│
                     │  email       │     │  ayah_number │
                     │  password_hash│    │  text_arabic │
                     │  preferences │     │  translation │
                     │  is_active   │     │  tafsir      │
                     │  created_at  │     │  emotional_  │
                     │  updated_at  │     │    state     │
                     │  is_deleted  │     │  tags[]      │
                     └──────┬───────┘     │  created_at  │
                            │              │  updated_at  │
                            │              │  is_deleted  │
                            │              └──────────────┘
                            │                        │
                            │                        │
                            │              ┌─────────▼─────────┐
                    ┌───────┴──────┐      │    hadiths       │
                    │ interactions ├──────┤├──────────────┤   │
                    ├──────────────┤      │PK id         │   │
                    │PK id         │      │  collection  │   │
                    │FK user_id    │      │  hadith_number│   │
                    │ query_text   │      │  text_arabic │   │
                    │ detected_    │      │  explanation │   │
                    │   emotion    │      │  grade       │   │
                    │ emotion_     │      │  emotional_  │   │
                    │   confidence │      │    state     │   │
                    │ response_tier│      │  tags[]      │   │
                    │ response_    │      │  created_at  │   │
                    │   delayed    │      │  updated_at  │   │
                    │ created_at   │      │  is_deleted  │   │
                    └──────┬───────┘      └──────────────┘   │
                           │                                  │
                           │                                  │
                    ┌──────▼──────┐                   ┌───────▼───────┐
                    │   delayed_  │                   │   emotion_    │
                    │  responses  │                   │   mappings    │
                    ├─────────────┤                   ├───────────────┤
                    │PK id        │                   │PK id         │
                    │FK user_id   │                   │ emotion      │
                    │FK interaction_id│                │ keywords[]   │
                    │ recommendation_│                │ example_verses│
                    │   type       │                │   []          │
                    │ recommendation_│                │ example_      │
                    │   id         │                │   hadiths[]   │
                    │ reason       │                │ description   │
                    │ is_delivered │                │ created_at    │
                    │ scheduled_for│                └───────────────┘
                    │ delivered_at │
                    │ created_at   │
                    └──────────────┘
```

---

## 📋 تفاصيل الجداول والعلاقات

### 1. جدول المستخدمين (users)

**الغرض:** تخزين بيانات المستخدمين المسجلين والمجهولين.

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    preferences JSONB DEFAULT '{
        "notification_style": "minimal",
        "language": "ar",
        "theme": "light",
        "font_size": "medium",
        "daily_reminders": true,
        "sound_enabled": false
    }'::jsonb,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);
```

**الفهارس:**
```sql
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_is_active ON users(is_active) WHERE is_active = TRUE;
```

### 2. جدول التفاعلات (interactions)

**الغرض:** تسجيل كل تفاعل بين المستخدم والنظام.

```sql
CREATE TABLE interactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    query_text TEXT NOT NULL,
    detected_emotion VARCHAR(50),
    emotion_confidence FLOAT CHECK (emotion_confidence >= 0 AND emotion_confidence <= 1),
    recommendation_type VARCHAR(20),  -- 'verse', 'hadith', 'symbol'
    recommendation_id INTEGER,
    user_feedback BOOLEAN,
    response_tier VARCHAR(20) CHECK (response_tier IN ('minimal', 'moderate', 'full')),
    response_delayed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**الفهارس:**
```sql
CREATE INDEX idx_interactions_user_id ON interactions(user_id);
CREATE INDEX idx_interactions_created_at ON interactions(created_at);
CREATE INDEX idx_interactions_detected_emotion ON interactions(detected_emotion);
CREATE INDEX idx_interactions_response_tier ON interactions(response_tier);
CREATE INDEX idx_interactions_user_feedback ON interactions(user_feedback);
```

**العلاقات:**
- `user_id` → `users.id` (Many-to-One)
- أحدث 1000 تفاعل لكل مستخدم مخزنة
- سجل التفاعلات يحتفظ بـ 30 يوماً للبيانات الكاملة

### 3. جدول الاستجابات المؤجلة (delayed_responses)

**الغرض:** تتبع المحتوى الذي تم تأجيل عرضه للمستخدم.

```sql
CREATE TABLE delayed_responses (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    interaction_id INTEGER REFERENCES interactions(id) ON DELETE CASCADE,
    recommendation_type VARCHAR(20),
    recommendation_id INTEGER,
    reason VARCHAR(100) CHECK (reason IN ('high_emotion', 'user_busy', 'technical_issue')),
    is_delivered BOOLEAN DEFAULT FALSE,
    scheduled_for TIMESTAMP WITH TIME ZONE NOT NULL,
    delivered_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**الفهارس:**
```sql
CREATE INDEX idx_delayed_responses_user_id ON delayed_responses(user_id);
CREATE INDEX idx_delayed_responses_interaction_id ON delayed_responses(interaction_id);
CREATE INDEX idx_delayed_responses_scheduled_for ON delayed_responses(scheduled_for);
CREATE INDEX idx_delayed_responses_is_delivered ON delayed_responses(is_delivered);
CREATE INDEX idx_delayed_responses_created_at ON delayed_responses(created_at);
```

**العلاقات:**
- `user_id` → `users.id` (Many-to-One)
- `interaction_id` → `interactions.id` (One-to-One)

### 4. جدول الآيات (verses)

**الغرض:** تخزين النصوص القرآنية والتفاسير المرتبطة.

```sql
CREATE TABLE verses (
    id SERIAL PRIMARY KEY,
    surah_number INTEGER NOT NULL CHECK (surah_number >= 1 AND surah_number <= 114),
    ayah_number INTEGER NOT NULL CHECK (ayah_number >= 1 AND ayah_number <= 286),
    text_arabic TEXT NOT NULL,
    text_uthmani TEXT,
    text_indopak TEXT,
    translation TEXT,
    tafsir TEXT,
    tafsir_source VARCHAR(100) CHECK (tafsir_source IN ('ibn_kathir', 'saadi', 'muyassar')),
    tags TEXT[] DEFAULT '{}',
    emotional_state VARCHAR(50),
    keywords TEXT[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);
```

**الفهارس:**
```sql
CREATE INDEX idx_verses_surah_ayah ON verses(surah_number, ayah_number);
CREATE INDEX idx_verses_emotional_state ON verses(emotional_state);
CREATE INDEX idx_verses_tags ON verses USING GIN(tags);
CREATE INDEX idx_verses_keywords ON verses USING GIN(keywords);
CREATE INDEX idx_verses_tafsir_source ON verses(tafsir_source);
```

**البيانات:**
- إجمالي 6,236 آية
- 3 نسخ نصية (العثماني، الإندونيسي، المشكل)
- 3 مصادر تفسيرية (ابن كثير، السعدي، الميسر)
- متوسط طول النص: 12 كلمة

### 5. جدول الأحاديث (hadiths)

**الغرض:** تخزين النصوص الحديثية والشرح.

```sql
CREATE TABLE hadiths (
    id SERIAL PRIMARY KEY,
    collection VARCHAR(100) NOT NULL CHECK (
        collection IN ('bukhari', 'muslim', 'tirmidhi', 'abudawud', 'nasai', 'ibnmajah')
    ),
    hadith_number VARCHAR(50),
    text_arabic TEXT NOT NULL,
    translation TEXT,
    explanation TEXT,
    narrator VARCHAR(255),
    grade VARCHAR(50) CHECK (grade IN ('sahih', 'hasan', 'daif')),
    tags TEXT[] DEFAULT '{}',
    emotional_state VARCHAR(50),
    keywords TEXT[] DEFAULT '{}',
    is_authentic BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_deleted BOOLEAN DEFAULT FALSE
);
```

**الفهارس:**
```sql
CREATE INDEX idx_hadiths_collection ON hadiths(collection);
CREATE INDEX idx_hadiths_emotional_state ON hadiths(emotional_state);
CREATE INDEX idx_hadiths_tags ON hadiths USING GIN(tags);
CREATE INDEX idx_hadiths_keywords ON hadiths USING GIN(keywords);
CREATE INDEX idx_hadiths_grade ON hadiths(grade);
CREATE INDEX idx_hadiths_is_authentic ON hadiths(is_authentic);
```

**البيانات:**
- إجمالي 36,000+ حديث
- 6 مجموعات حديثية رئيسية
- تصنيف الصحة: صحيح، حسن، ضعيف
- متوسط طول النص: 25 كلمة

### 6. جدول التصنيف العاطفي (emotion_mappings)

**الغرض:** ربط الحالات العاطفية بالنصوص الشرعية المناسبة.

```sql
CREATE TABLE emotion_mappings (
    id SERIAL PRIMARY KEY,
    emotion VARCHAR(50) NOT NULL UNIQUE CHECK (
        emotion IN ('غضب', 'حزن', 'قلق', 'فرح', 'طبيعي', 'سفر', 'دراسة', 'مرض', 'شكر')
    ),
    keywords TEXT[] DEFAULT '{}',
    example_verses INTEGER[] DEFAULT '{}',
    example_hadiths INTEGER[] DEFAULT '{}',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

**الفهارس:**
```sql
CREATE INDEX idx_emotion_mappings_emotion ON emotion_mappings(emotion);
CREATE INDEX idx_emotion_mappings_keywords ON emotion_mappings USING GIN(keywords);
```

**البيانات:**
```
┌────────────┬──────────────────────────────┬─────────────┬─────────────┐
│  Emotion   │          Keywords            │  Verses     │  Hadiths    │
├────────────┼──────────────────────────────┼─────────────┼─────────────┤
│ غضب        │ غضب، عصبية، انفعال، حنق     │ [134, 199]  │ [123, 456]  │
│ حزن        │ حزن، أسى، وجع، ألم          │ [155, 156]  │ [789, 012]  │
│ قلق        │ قلق، خوف، توتر، قلق         │ [28, 30]    │ [345, 678]  │
│ فرح        │ فرح، سرور، سعادة            │ [58, 59]    │ [901, 234]  │
└────────────┴──────────────────────────────┴─────────────┴─────────────┘
```

---

## 🔗 العلاقات بين الجداول

### 1. علاقة المستخدمين ↔ التفاعلات

```
users (1) ─────── (N) interactions
    │                    │
    │ PK: id             │ FK: user_id
    └────────────────────┘
```

**Cardinality:** One-to-Many  
**شرح:** يمكن للمستخدم إجراء العديد من التفاعلات، ولكن كل تفاعل ينتمي لمستخدم واحد فقط.

### 2. علاقة التفاعلات ↔ الاستجابات المؤجلة

```
interactions (1) ────── (1) delayed_responses
    │                          │
    │ PK: id                   │ FK: interaction_id
    └──────────────────────────┘
```

**Cardinality:** One-to-One  
**شرح:** كل تفاعل قد يكون له استجابة مؤجلة واحدة، وكل استجابة مؤجلة مرتبطة بتفاعل واحد.

### 3. علاقة الآيات ↔ التصنيف العاطفي

```
verses (N) ─────── (M) emotion_mappings
    │                    │
    │                    │ 
    └────────────────────┘ عبر example_verses array
```

**Cardinality:** Many-to-Many  
**شرح:** آية واحدة قد تكون مناسبة لحالات عاطفية متعددة، وحالة عاطفية واحدة قد ترتبط بالعديد من الآيات.

### 4. علاقة الأحاديث ↔ التصنيف العاطفي

```
hadiths (N) ─────── (M) emotion_mappings
    │                     │
    │                     │
    └─────────────────────┘ عبر example_hadiths array
```

**Cardinality:** Many-to-Many  
**شرح:** نفس علاقة الآيات ولكن للأحاديث.

---

## 📊 إحصائيات قاعدة البيانات

### حجم البيانات المتوقع:

| الجدول | عدد الصفوف | حجم التخزين | نمو/شهر |
|--------|------------|-------------|----------|
| users | 10,000 | 50 MB | 500 |
| interactions | 1,000,000 | 2 GB | 100,000 |
| delayed_responses | 100,000 | 100 MB | 10,000 |
| verses | 6,236 | 50 MB | ثابت |
| hadiths | 36,000 | 200 MB | ثابت |
| emotion_mappings | 9 | 100 KB | ثابت |
| **المجموع** | **1,152,245** | **2.4 GB** | **110,500** |

### أداء الاستعلامات:

| الاستعلام | الجدول | الفهرس | متوسط الزمن |
|-----------|--------|--------|-------------|
| SELECT user interactions | interactions | idx_interactions_user_id | 5ms |
| SELECT verse by surah/ayah | verses | idx_verses_surah_ayah | 2ms |
| SELECT hadiths by emotion | hadiths | idx_hadiths_emotional_state | 3ms |
| INSERT interaction | interactions | PK auto-increment | 10ms |
| UPDATE delayed response | delayed_responses | idx_delayed_responses_scheduled_for | 8ms |
| SELECT recent interactions | interactions | idx_interactions_created_at | 15ms |

---

## 🔄 سياسات الاحتفاظ والحذف

### Retention Policies:

| الجدول | فترة الاحتفاظ | الإجراء |
|--------|---------------|---------|
| interactions | 30 يوم | Archive to S3 |
| delayed_responses | 7 أيام بعد التسليم | Soft Delete |
| users | غير محدود | Soft Delete |
| verses/hadiths | غير محدود | لا حذف |

### Archiving Strategy:

```sql
-- Archive interactions older than 30 days
CREATE OR REPLACE FUNCTION archive_old_interactions()
RETURNS void AS $$
BEGIN
    -- Copy to archive table
    INSERT INTO interactions_archive
    SELECT * FROM interactions 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    -- Delete from main table
    DELETE FROM interactions 
    WHERE created_at < NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Schedule daily archiving
SELECT cron.schedule('archive-interactions', '0 2 * * *', 
    'SELECT archive_old_interactions()');
```

### Soft Delete Pattern:

```sql
-- Instead of DELETE FROM users WHERE id = 123
UPDATE users 
SET is_deleted = TRUE, 
    updated_at = NOW() 
WHERE id = 123;

-- Query only active users
SELECT * FROM users 
WHERE is_deleted = FALSE;
```

---

## 🛡️ الأمان والصلاحيات

### مستويات الوصول:

```sql
-- Create different roles
CREATE ROLE murassikh_app LOGIN PASSWORD 'secure_password';
CREATE ROLE murassikh_readonly;

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON interactions TO murassikh_app;
GRANT SELECT ON verses, hadiths TO murassikh_app;
GRANT SELECT ON ALL TABLES TO murassikh_readonly;

-- Row Level Security (RLS)
ALTER TABLE interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_interactions_policy ON interactions
    USING (user_id = current_setting('app.user_id')::integer);
```

### Encryption:

```sql
-- Encrypt sensitive data
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Encrypt password hash
INSERT INTO users (email, password_hash) 
VALUES ('user@example.com', crypt('password123', gen_salt('bf', 12)));

-- Verify password
SELECT id FROM users 
WHERE email = 'user@example.com' 
AND password_hash = crypt('password123', password_hash);
```

---

## 📈 مخطط النمو المستقبلي

### المرحلة 1 (MVP):
```sql
-- الجداول الحالية (6 جداول)
```

### المرحلة 2 (Multi-modal):
```sql
-- إضافة جداول جديدة
CREATE TABLE audio_analysis (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    tone_analysis JSONB,
    speech_to_text TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE image_analysis (
    id SERIAL PRIMARY KEY,
    interaction_id INTEGER REFERENCES interactions(id),
    facial_expressions JSONB,
    emotion_detected VARCHAR(50),
    confidence FLOAT,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### المرحلة 3 (Personalization):
```sql
-- جداول التخصيص
CREATE TABLE user_preferences (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    preferred_scholars TEXT[],
    favorite_verses INTEGER[],
    blocked_content INTEGER[],
    learning_style VARCHAR(50)
);

CREATE TABLE learning_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    emotion_handled VARCHAR(50),
    improvement_score FLOAT,
    last_practiced TIMESTAMP
);
```

---

**آخر تحديث:** 2026-09-11
