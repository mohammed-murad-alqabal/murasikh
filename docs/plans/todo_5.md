# تحويل الشاشة الرئيسية إلى واجهة ديناميكية

> **الحالة:** تم التنفيذ بالكامل ✅ (Completed)

## تشخيص الوضع الحالي

بعد تحليل الكود الكامل، هذه هي المشكلات الجوهرية:

### 1. قسم «آية اليوم وسكينة القلب» — **ثابت بالكامل**
```dart
// home_screen.dart — ثابت منسوخ في الكود
Text('فَاذۡكُرُونِيٓ أَذۡكُرۡكُمۡ...') // آية ثابتة لا تتغير أبدًا
Text('سورة البقرة: ١٥٢')              // مرجع ثابت
Text('من ذكر الله في نفسه...')         // تفسير ثابت
```
الآية **لا تُحضر من الـ API، ولا تتأثر بأي حالة**. هي نص حرفي مضمّن في الكود.

### 2. `_latestEmotionSummary` — محدود ومبتور
يجلب فقط اسم آخر حالة مسجّلة (`آخر حالة مسجلة: غضب`) دون ترجمة ذلك إلى محتوى مرتبط.

### 3. لا يوجد ربط بين المصادر الثلاثة المتاحة فعلاً:
| المصدر | البيانات المتاحة | الاستخدام الحالي |
|--------|-----------------|-----------------|
| `FaceEmotionService` | حالة عاطفية حية (فرح/قلق/إجهاد) | مستقل تمامًا عن قسم الآية |
| `AmbientListeningService` | توصية صوتية + حالة عاطفية | مستقل تمامًا |
| `HistoryService` | آخر 5 تفاعلات + حالات مسجّلة | يُجلب فقط اسم الحالة |

### 4. الهيكل المعماري
الشاشة `StatefulWidget` بسيط — لا يوجد BLoC أو State Management للشاشة الرئيسية نفسها، مما يعني أن التحديثات متفرقة وغير مركزية.

---

## المبادئ التصميمية للحل

> **لا تحديث إلا عند تغيّر حقيقي ذي دلالة.** الهدف: آية مرتبطة بالسياق، لا متغيّرة باستمرار.

**آلية الترشيح (Context Signal Aggregator):**

```
┌─────────────────────────────────────────────────┐
│            مصادر الإشارات (Signals)              │
│                                                   │
│  [1] الوجه: فرح/قلق/إجهاد (FaceEmotionService) │
│  [2] الصوت: حالة صوتية (AmbientListeningService) │
│  [3] السجل: آخر 3 تفاعلات (HistoryService)      │
│  [4] الوقت: صبح/ظهر/عصر/مساء/ليل               │
│  [5] الأيام: الجمعة / الأعياد / العادي          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│         مُحكّم السياق (ContextResolver)           │
│                                                   │
│  • الوزن: الوجه > الصوت > السجل > الوقت         │
│  • يُنتج: ContextSnapshot { emotion, confidence, │
│    source, lastUpdated }                          │
│  • يُقارن مع السابق: هل تغيّر السياق فعلاً؟     │
│  • عتبة التغيّر: confidence ≥ 0.65 أو            │
│    مرور 60 دقيقة على آخر تحديث                   │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│      DailyVerseService (خدمة الآية الديناميكية)  │
│                                                   │
│  • يستدعي /api/v1/analyze بناءً على السياق       │
│  • يُخزّن آخر آية + ContextSnapshot              │
│  • يُوفّر Stream للـ UI                           │
└─────────────────────────────────────────────────┘
```

---

## التغييرات المقترحة

### ─── Backend ───

#### [x] [NEW] `app/api/v1/endpoints/home.py`
**Endpoint جديد:** `POST /api/v1/home/verse`

يقبل سياق خفيفاً (context_signals) ويُعيد آية مرشّحة دون الحاجة لنص مستخدم صريح. يُعيد:
```json
{
  "verse": "...",
  "source": "سورة البقرة: ١٥٦",
  "tafsir": "...",
  "emotion_context": "حزن",
  "signal_used": "history",
  "confidence": 0.78,
  "cached": false
}
```

هذا يُتيح استدعاءً أخف وأسرع من `/analyze` الكامل.

---

### ─── Frontend ───

#### [x] [NEW] `lib/services/home_context_service.dart`
الخدمة المحورية — `ContextResolver`.

- **ChangeNotifier** يستمع لـ `FaceEmotionService` و `AmbientListeningService`
- يحسب `ContextSnapshot` الموزّون
- يُطلق `notifyListeners()` فقط عند تغيّر حقيقي (عتبة الثقة + فارق زمني)
- يحمل قيمة الحالة السابقة لمنع التحديثات المتكررة

**منطق التغيير الذي يُعتدّ به:**
```dart
bool _isSignificantChange(ContextSnapshot oldCtx, ContextSnapshot newCtx) {
  if (oldCtx.dominantEmotion != newCtx.dominantEmotion) return true;
  if (newCtx.confidence - oldCtx.confidence > 0.25) return true;
  if (DateTime.now().difference(oldCtx.timestamp) > const Duration(minutes: 60)) return true;
  return false;
}
```

#### [x] [NEW] `lib/services/daily_verse_service.dart`
- يستمع لـ `HomeContextService`
- عند تغيير السياق: يستدعي الـ API الجديد أو يُعيد من الكاش
- يُعيد `Stream<VerseCard>` (نموذج بسيط: آية + مرجع + تفسير + سياق استُخدم)
- **fallback ذكي:** إذا فشل الاتصال، يختار من آخر 5 توصيات محفوظة في Hive بناءً على الحالة الحالية

#### [x] [MODIFY] `lib/features/home/presentation/screens/home_screen.dart`
- استبدال `_buildDailyInspirationCard` الثابت بـ `StreamBuilder<VerseCard?>`
- إضافة `AnimatedSwitcher` للانتقال السلس بين الآيات
- إضافة `LinearProgressIndicator` خفيف أثناء التحميل
- إضافة بادج صغير يشير إلى مصدر السياق («بناءً على حالتك الآن» / «بناءً على تفاعلاتك الأخيرة» / «وقت الفجر»)
- إزالة الآية والمرجع والتفسير الثابتَين

#### [x] [NEW] `lib/features/home/models/verse_card.dart`
نموذج بيانات بسيط:
```dart
class VerseCard {
  final String verse;
  final String source;
  final String? tafsir;
  final String emotionContext;
  final String signalUsed; // 'face' | 'audio' | 'history' | 'time'
  final DateTime fetchedAt;
}
```

#### [x] [MODIFY] `lib/features/home/presentation/screens/home_screen.dart` — قسم الترويسة
- استبدال التحية الثابتة `أهلاً بك في رفيقك الروحي مُرَسِّخ` بتحية مرتبطة بالوقت (صباح الخير / مساء الخير / طاب ليلك)
- إظهار اسم المستخدم من `SettingsService` بدلاً من نص عام

---

## آلية التحديث — تدفق كامل

```
تغيّر FaceEmotionService أو AmbientListeningService
        │
        ▼
HomeContextService._evaluateContext()
  • حساب ContextSnapshot الجديد
  • مقارنة مع السابق
  • إذا لا يوجد تغيير ذو دلالة: تجاهل (لا إشعار)
  • إذا يوجد تغيير: notifyListeners()
        │
        ▼
DailyVerseService._onContextChanged()
  • هل مرّت 3 دقائق على آخر استدعاء API؟ (debounce)
  • إذا نعم: استدعِ POST /api/v1/home/verse مع إشارات السياق في JSON body
  • خزّن النتيجة في Hive
  • أضف VerseCard إلى StreamController
        │
        ▼
HomeScreen (StreamBuilder<VerseCard?>)
  • AnimatedSwitcher: تلاشي ناعم (800ms)
  • عرض الآية + المرجع + التفسير + بادج السياق
```

**ضمانات عدم الإزعاج:**
- Debounce 3 دقائق على مستوى الاستدعاء
- عتبة الثقة: ≥ 0.65 للتغيير بناءً على الوجه
- عتبة الوقت: 60 دقيقة كحد أدنى للتحديث الدوري
- لا تحديث عند نفس الحالة العاطفية

---

## خطة التحقق

### اختبار ذاتي (آلي)
- `flutter analyze` — لا أخطاء ولا تحذيرات
- `flutter test` — اختبار وحدة لـ `HomeContextService._isSignificantChange`

### تحقق يدوي
| السيناريو | السلوك المتوقع |
|-----------|---------------|
| فتح التطبيق لأول مرة، لا سجل | آية افتراضية من الكاش أو fallback ثابت |
| وجه يكتشف قلقًا بثقة > 0.65 | تحديث الآية بعد debounce 3 دقائق |
| تغيير الحالة من قلق → طبيعي | لا تحديث (طبيعي = حياد) |
| استخدام حارس السكينة وجاء تنبيه | تحديث الآية بناءً على حالة التنبيه |
| وقت الفجر (4-6 صباحًا) | آية من مجموعة الفجر والصبح |
| انقطاع الإنترنت | الكاش المحلي من HistoryService |

---

## القرارات المعتمدة

- يعتمد التطبيق endpoint مخصصاً هو `POST /api/v1/home/verse`، وتُرسل إشارات السياق في JSON body.
- عند عدم وجود حالة عاطفية واضحة، يستخدم Backend آية مرتبطة بوقت اليوم كـ fallback.
- يعرض التطبيق بادج مصدر السياق مثل «بناءً على تفاعلاتك الأخيرة» أو «آية المساء».
