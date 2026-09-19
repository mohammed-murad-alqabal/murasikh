# 🕌 مُرَسِّخ - الرفيق الروحي الذكي

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Flutter](https://img.shields.io/badge/flutter-3.16+-blue.svg)](https://flutter.dev)
[![Status](https://img.shields.io/badge/status-development-green.svg)]()

**نظام ذكاء اصطناعي متقدم لتقديم توجيه ديني وروحي لحظي أو مؤجل**

[الوثائق](./docs/README.md) • [البدء السريع](#-البدء-السريع) • [المساهمة](#-المساهمة) • [الترخيص](#-الترخيص)

</div>

---

## 📖 عن المشروع

**مُرَسِّخ** هو رفيقك الروحي الذكي، نظام ذكاء اصطناعي متقدم يرافق المستخدم في حياته اليومية، يعمل على تحليل السياق والمشاعر لتقديم توجيه ديني وروحي يعتمد على القرآن الكريم والسنة النبوية.

### 🎯 الأهداف

- **ترسيخ القيم الإسلامية** - تعزيز مكارم الأخلاق والسلوك الإيجابي
- **الدعم النفسي** - توفير الدعم الروحي والمعنوي في الأوقات الصعبة
- **التوجيه اللحظي** - تقديم نصائح مناسبة في الوقت المناسب
- **السهولة واليسر** - واجهة بسيطة وسهلة الاستخدام

### ✨ الميزات الرئيسية

| الميزة | الوصف |
|--------|-------|
| 🎯 **تحليل المشاعر** | فهم الحالة العاطفية للمستخدم من النص |
| 📚 **قاعدة معرفة شرعية** | 6,236 آية مع التفاسير |
| 🔍 **البحث الدلالي** | RAG للدقة الشرعية بدون Hallucination |
| 📱 **العمل بدون إنترنت** | Offline-First Architecture |
| 🎚️ **الاستجابة المدرجة** | مراعاة الحالة النفسية للمستخدم |
| 🔒 **الخصوصية الكاملة** | معالجة محلية وتشفير البيانات |

---

## 🚀 البدء السريع

### المتطلبات

| البرنامج | الإصدار |
|----------|---------|
| Python | 3.11+ |
| Flutter | 3.16+ |
| Docker | 24+ |
| PostgreSQL | 15+ |

### التثبيت

```bash
# 1. استنساخ المستودع
git clone https://github.com/mohammed-murad-alqabal/murasikh.git
cd murasikh

# 2. إعداد Backend
cd backend
python -m venv venv
source venv/bin/activate  # Linux/macOS
pip install -r requirements.txt

# 3. إعداد قاعدة البيانات
docker-compose up -d db redis
alembic upgrade head

# 4. تشغيل الخادم
uvicorn app.main:app --reload
```

### التحقق

```bash
curl http://localhost:8000/health
# {"status": "healthy", "version": "0.1.0"}
```

📖 **للتفاصيل:** [دليل البدء السريع](./docs/02-development/البدء-السريع.md)

---

## 📂 هيكل المشروع

```
murassikh/
├── backend/              # Backend API (FastAPI)
│   ├── app/
│   │   ├── api/         # API endpoints
│   │   ├── core/        # الإعدادات والأمان
│   │   ├── db/          # قاعدة البيانات
│   │   ├── services/    # الخدمات (AI, RAG, etc.)
│   │   └── models/      # النماذج
│   └── tests/           # الاختبارات
│
├── frontend/             # Flutter App
│   ├── lib/
│   │   ├── features/    # الميزات
│   │   ├── services/    # الخدمات
│   │   └── models/      # النماذج
│   └── test/            # الاختبارات
│
├── docs/                 # التوثيق الشامل
│   ├── 01-pre-development/
│   ├── 02-development/
│   ├── 03-api/
│   ├── 04-user-guide/
│   ├── 05-deployment/
│   ├── 06-knowledge-base/
│   └── plans/
│
└── scripts/              # سكربتات مساعدة
```

---

## 🗺️ خارطة الطريق

| المرحلة | المدة | الحالة | الوصف |
|---------|-------|--------|-------|
| **P1: MVP** | 18 أسبوع | 🟢 مكتمل | إدخال نصي + توصيات أساسية + دعم محلي بالكامل |
| **P2: الوسائط** | 6 أشهر | 🟢 مكتمل | تحليل الصوت والمشاعر + التفاعل اللمسي |
| **P3: الترابط** | 4 أشهر | 🟢 مكتمل | الربط مع Apple Health و Google Fit لقراءة النبض |
| **P4: الأمان** | 3 أشهر | 🟢 مكتمل | إضافة نظام مصادقة سحابي اختياري (JWT) وتصدير البيانات |
| **P5: الإطلاق** | شهرين | 🔵 جاري | النشر على المتاجر (Google Play / App Store) |

📖 **للتفاصيل:** [خطة التنفيذ](./docs/plans/todo_3.md)

---

## 📚 الوثائق

| القسم | الوصف | الرابط |
|-------|-------|--------|
| **ما قبل التطوير** | الرؤية، المتطلبات، المعمارية | [عرض](./docs/01-pre-development/) |
| **التطوير** | أدلة المطورين، معايير الكود | [عرض](./docs/02-development/) |
| **API** | توثيق واجهات البرمجة | [عرض](./docs/03-api/) |
| **دليل المستخدم** | أدلة الاستخدام والأسئلة الشائعة | [عرض](./docs/04-user-guide/) |
| **النشر والتشغيل** | البنية التحتية، المراقبة، الأمان | [عرض](./docs/05-deployment/) |
| **قاعدة المعرفة** | ADRs، القاموس، المحتوى الشرعي | [عرض](./docs/06-knowledge-base/) |

🔗 **[فهرس الوثائق الكامل](./docs/README.md)**

---

## 🛠️ التقنيات المستخدمة

### Backend

| التقنية | الاستخدام |
|---------|----------|
| **FastAPI** | إطار العمل الرئيسي |
| **PostgreSQL** | قاعدة البيانات العلائقية |
| **Chroma** | قاعدة البيانات المتجهية |
| **Redis** | التخزين المؤقت والجلسات |
| **SQLAlchemy** | ORM |
| **Alembic** | تهجير قاعدة البيانات |

### AI & ML

| التقنية | الاستخدام |
|---------|----------|
| **paraphrase-multilingual-MiniLM-L12-v2** | Embeddings للعربية |
| **Google Gemini** | تحليل المشاعر والتوليد |
| **Sentence Transformers** | البحث الدلالي |

### Frontend

| التقنية | الاستخدام |
|---------|----------|
| **Flutter** | إطار العمل الرئيسي |
| **Hive** | قاعدة البيانات المحلية |
| **BLoC** | إدارة الحالة |
| **package:http** | طلبات HTTP |

---

## 🤝 المساهمة

نرحب بمساهماتكم! 

### كيفية المساهمة

1. Fork المشروع
2. إنشاء فرع للميزة (`git checkout -b feature/amazing-feature`)
3. Commit التغييرات (`git commit -m 'Add amazing feature'`)
4. Push إلى الفرع (`git push origin feature/amazing-feature`)
5. فتح Pull Request

📖 **للتفاصيل:** [دليل المساهمة](./docs/02-development/دليل-المساهمة.md)

### قواعد المساهمة

- اتبع [معايير الكود](./docs/02-development/معايير-الكود.md)
- اكتب اختبارات للكود الجديد
- حدّث التوثيق عند الحاجة

---

## 📞 التواصل

| الطريقة | الرابط |
|---------|--------|
| **البريد الإلكتروني** | team@murassikh.com |
| **GitHub Issues** | [رابط](https://github.com/mohammed-murad-alqabal/murasikh/issues) |
| **الموقع** | https://murassikh.com |

---

## 📜 الترخيص

هذا المشروع مرخص تحت رخصة MIT - راجع ملف [LICENSE](LICENSE) للتفاصيل.

---

## 🙏 شكر وتقدير

- [UmmahAPI](https://ummahapi.com) - لتوفير البيانات الشرعية
- [House of Islam](https://developers.thehouseofislam.com) - للمحتوى الإسلامي
- جميع المساهمين في المشروع

---

<div align="center">

**صنع بـ ❤️ لخدمة الإسلام والمسلمين**

</div>
