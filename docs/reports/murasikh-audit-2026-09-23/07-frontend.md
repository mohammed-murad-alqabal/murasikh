# مراجعة Principal Software Engineer: Flutter Frontend وHome والرحلة الأساسية وOffline

**المستودع:** `/home/ubuntu/murasikh`  
**Commit المراجع:** `c915d0b03ff976c731e36cd98f6343bedd56f904`  
**النطاق:** واجهة Flutter، شاشة Home، مسار الاستخدام الأساسي، والعمل دون اتصال.  
**تاريخ المراجعة:** 2026-09-23

## الخلاصة التنفيذية

الكود يقدّم **هيكلاً فعلياً ومتكاملاً جزئياً** للواجهة والرحلة الأساسية. يبدأ التطبيق بتهيئة Hive والخدمات ثم يعرض `MainShell` الذي يربط Home والرفيق والسجل والإعدادات عبر `IndexedStack`. شاشة Home تجلب الآية السياقية من واجهة الخادم وتعرض الكاش أو الآية الاحتياطية عند الفشل. كما أن مسار الرفيق يحفظ الرسائل محلياً، ويستعمل التوصيات المخزنة أو توصية ثابتة عند غياب الاتصال، ويؤجل إرسال التقييمات.

لكن الأدلة لا تكفي لاعتبار المحور **Verified** أو **Production Ready**. لم توجد أداة `flutter` أو `dart` في بيئة المراجعة؛ لذلك تعذر تشغيل الاختبارات أو `flutter analyze` أو بناء APK. كذلك لا توجد اختبارات Widget لـ Home أو اختبارات تكامل حقيقية لحالة انقطاع الشبكة، وتوجد فجوات تشغيلية واضحة: وصف الشريط بأن المواساة «تُولّد محلياً» أوسع من التنفيذ الفعلي، وتسريب اشتراك في `OfflineBanner`، واشتراك غير محفوظ في `HomeScreen`، واعتماد الإنتاج على تمرير `API_BASE_URL` يدوياً.

**الحكم:** Implemented = نعم، Integrated = نعم جزئياً، Tested = جزئياً على مستوى اختبارات وحدات موجودة في المستودع، Verified = لا، Production Ready = لا يثبتها هذا commit.

## تصنيف الحالة

| البعد | الحكم | الدليل القابل للتتبع |
|---|---|---|
| Implemented | منفذ | `frontend/lib/main.dart:64-89` يهيئ الخدمات و`frontend/lib/core/navigation/main_shell.dart:22-68` يعرّف الشاشات الأربع. |
| Integrated | متكامل جزئياً | `frontend/lib/main.dart:114-165` يربط Bloc و`ConnectivityWrapper` و`AutoLockGate`، و`frontend/lib/features/home/presentation/screens/home_screen.dart:35-52` يربط Home بالسياق وخدمة الآية. لكن التكامل الشبكي لا يثبت رحلة إنتاجية على جهاز حقيقي. |
| Tested | جزئي | توجد اختبارات لوحدة السياسة والكاش في `frontend/test/services/home_context_policy_test.dart` و`frontend/test/services/offline_service_test.dart`، واختبارات Widget للـChat. لا توجد اختبارات Widget لـHome أو اختبار تكامل للانتقال بين online/offline. |
| Verified | غير مثبت | خرج الأمر `flutter test` بنتيجة `bash: flutter: command not found` ثم `EXIT=127`. لم يمكن تنفيذ `flutter analyze` أو build. |
| Production Ready | غير مثبت / لا أوصي بالاعتماد عليه | `docs/حالة-المنتج-2026-09-22.md:30-32` يحصر الحالة في التطوير والاختبار وstaging المشروط، و`docs/reports/P3_acceptance_report.md:18-26` يبقي اختبارات الأجهزة وبناء الإصدار والتوقيع كعناصر غير مغلقة. |

## ما هو منفذ فعلياً

### التهيئة والمسار الأساسي

**Fact:** التهيئة المركزية موجودة في `main`.  
**Evidence:** `frontend/lib/main.dart:64-89` يستدعي `Hive.initFlutter()` ثم يهيئ `SettingsService` و`NotificationService` و`HistoryService` و`OfflineService` و`AmbientListeningService` و`DailyVerseService` قبل `runApp`.  
**Inference:** توجد نقطة بدء موحدة تقلل احتمال استخدام Home قبل فتح مخازن Hive في التشغيل العادي.

**Fact:** الرحلة الرئيسية عبارة عن أربع وجهات داخل `IndexedStack`.  
**Evidence:** `frontend/lib/core/navigation/main_shell.dart:22-28` يعرّف `HomeScreen` و`ChatScreen` و`HistoryScreen` و`SettingsScreen`، و`main_shell.dart:41-68` يعرّف شريط التنقل العربي.  
**Inference:** الانتقال بين التبويبات يحافظ نظرياً على حالة الشاشات بدلاً من إعادة إنشائها في كل ضغطة.

**Fact:** Home تعرض واجهة سياقية وتدعم السحب للتحديث.  
**Evidence:** `frontend/lib/features/home/presentation/screens/home_screen.dart:113-153` يستخدم `SafeArea` و`RefreshIndicator` و`CustomScrollView`، ويستدعي في التحديث `evaluateFromHistory(forceRefresh: true)` ثم `fetchVerseForCurrentContext()`.  
**Inference:** المسار المرئي من فتح Home إلى عرض الآية والتحديث اليدوي موجود في الكود، وليس مجرد تصميم وثائقي.

### Home والسياق

**Fact:** Home تستمع إلى تغير السياق وإلى تدفق الآية، وتبدأ تقييماً بعد أول إطار.  
**Evidence:** `frontend/lib/features/home/presentation/screens/home_screen.dart:34-52` يضيف listeners ويستدعي `evaluateFromHistory()` و`fetchVerseForCurrentContext()`؛ و`home_screen.dart:348-359` يبني `StreamBuilder<VerseCard>` مع `currentVerse` كبيانات أولية.  
**Inference:** الكاش الموجود مسبقاً يمكن أن يظهر فوراً، بينما الطلب الشبكي يحدّث البطاقة لاحقاً.

**Fact:** اختيار السياق يعتمد على تاريخ التفاعلات الحديثة وعلى إشارات الوجه والصوت.  
**Evidence:** `frontend/lib/services/home_context_service.dart:156-171` يتعامل مع الإشارة الصوتية، و`:173-215` يأخذ آخر ثلاث تفاعلات ويختار الانفعال الأكثر تكراراً، و`:219-233` يطبق سياسة الإشعار قبل تغيير السياق.  
**Inference:** يوجد قرار سياقي مركزي مع debounce/threshold، وليس استدعاء عشوائياً من طبقة العرض.

**Fact:** خدمة الآية ترسل عقداً محدداً إلى الخادم وتستعمل كاشاً محلياً وفallback.  
**Evidence:** `frontend/lib/services/daily_verse_service.dart:90-104` يرسل `dominant_emotion` و`confidence` و`signal_source` و`time_of_day` إلى `/home/verse` بمهلة 15 ثانية؛ و`:121-126` و`:146-158` يعيدان الكاش أو `VerseCard.fallback` عند الفشل.  
**Inference:** مسار Home لا ينهار بالكامل بسبب فشل HTTP، لكنه يظل معتمداً على وجود استجابة أو بطاقة احتياطية محلية.

## النتائج والمخاطر

### F-01 — الشريط يعلن توليداً محلياً لا ينفذه الكود فعلياً

**Severity:** متوسطة (P1 للوضوح الوظيفي، P2 للأثر التشغيلي).  
**Kind:** Fact + Inference.

**Claim:** تجربة Offline في الواجهة توحي بأن المواساة تُولّد محلياً، بينما التنفيذ الفعلي للرفيق يعتمد على كاش توصيات سابق أو توصية ثابتة؛ لا يوجد محرك تحليل نص محلي في هذا المسار.

**Evidence:** `frontend/lib/core/widgets/connectivity_wrapper.dart:66-78` يعرض: «يتم توليد المواساة محلياً». في المقابل، `frontend/lib/services/api_service.dart:219-232` يطابق كلمات انفعالية محددة ثم يبحث في `getCachedRecommendation`، وإلا يعيد `getLatestCachedRecommendation` أو `fallbackRecommendation`. كما أن `frontend/lib/services/api_service.dart:114-134` يقرر offline من الاتصال ثم يستعمل هذا المسار الاحتياطي.

**Impact:** قد يتوقع المستخدم توصية جديدة مخصصة لنصه دون شبكة، بينما قد يحصل على توصية قديمة أو آية ثابتة. هذا يخلق فجوة ثقة بين الرسالة المرئية وعقد المنتج، ويصعب إثبات صحة التوصية في حالات لم توجد لها بيانات مخزنة.

**Recommendation:** غيّر النص إلى «التوصيات من الذاكرة المحلية أو رسالة احتياطية» ما لم يُبنَ محرك محلي فعلي. اعرض للمستخدم حالة المصدر بوضوح (`cached` أو `fallback`) وأضف اختباراً يثبت سلوك النص الجديد في كل حالة.

**Status:** Implemented = نعم، Integrated = نعم، Tested = جزئياً، Verified = لا، Production Ready = لا بسبب تضارب الوعد.

### F-02 — `OfflineBanner` يسرّب اشتراك الاتصال

**Severity:** متوسطة.

**Claim:** `OfflineBanner` ينشئ subscription جديداً ولا يحتفظ به لإلغائه في `dispose`.

**Evidence:** `frontend/lib/widgets/offline_banner.dart:37-48` يستدعي `Connectivity().onConnectivityChanged.listen(...)` مباشرة، بينما `frontend/lib/widgets/offline_banner.dart:60-64` لا يلغي إلا `AnimationController`. بالمقابل، التنفيذ الآخر في `frontend/lib/core/widgets/connectivity_wrapper.dart:14-16` يحفظ الاشتراك في `_subscription`، و`:40-43` يلغي الاشتراك.

**Impact:** إذا أعيد إنشاء `OfflineBanner` بسبب إعادة بناء شجرة التطبيق أو تغيّر lifecycle، تبقى listeners القديمة حية وقد تستدعي `setState` على Widgets disposed أو تكرر العمل وتزيد استهلاك الموارد. الخطر قد لا يظهر في جلسة قصيرة لكنه قابل للتراكم.

**Recommendation:** أضف `late StreamSubscription<List<ConnectivityResult>>` إلى `OfflineBanner` وألغها في `dispose`، مع حراسة `mounted` داخل callback. أضف اختبار lifecycle ينشئ ويدمر الWidget ويتحقق من عدم وجود callback بعد التدمير.

**Status:** Implemented = نعم، Integrated = نعم، Tested = لا يوجد اختبار لهذا lifecycle، Verified = لا، Production Ready = لا لهذا المسار.

### F-03 — Home لا يلغي اشتراك `verseStream`

**Severity:** منخفضة إلى متوسطة.

**Claim:** `HomeScreen` يستمع إلى `verseStream` دون تخزين `StreamSubscription` أو إلغائه.

**Evidence:** `frontend/lib/features/home/presentation/screens/home_screen.dart:40-42` يستدعي `_verseService.verseStream.listen((_) { if (mounted) setState(() {}); })`. وفي `home_screen.dart:55-61` لا يوجد إلغاء لهذا الاشتراك؛ الإلغاء الموجود يخص listeners أخرى و`AnimationController` فقط.

**Impact:** يبقى الاشتراك مرتبطاً بالخدمة singleton بعد مغادرة Home. شرط `mounted` يمنع `setState` بعد التدمير، لكنه لا يمنع بقاء الاشتراك أو عمل callback لكل بطاقة جديدة. مع التنقل المتكرر قد تتراكم listeners وتزداد عمليات إعادة البناء.

**Recommendation:** خزّن الاشتراك في `StreamSubscription<VerseCard>` وألغِه في `dispose`. أضف اختباراً يبدّل الوجهة ثم يصدر بطاقة ويتحقق من عدم وجود listener قديم.

**Status:** Implemented = نعم، Integrated = نعم، Tested = لا، Verified = لا، Production Ready = لا لهذا lifecycle.

### F-04 — يوجد مساران متوازيان لشريط Offline برسائل وسلوك مختلفين

**Severity:** متوسطة.

**Claim:** التطبيق يركب `ConnectivityWrapper` على مستوى `MaterialApp`، وفي الوقت نفسه يركب `OfflineBanner` داخل `MainShell`؛ كلاهما يستمع إلى connectivity ويعرض رسالة مستقلة.

**Evidence:** `frontend/lib/main.dart:128-132` يضع `ConnectivityWrapper` في `MaterialApp.builder`. و`frontend/lib/core/navigation/main_shell.dart:36-40` يضع `OfflineBanner` حول `IndexedStack`. الرسالتان مختلفتان في `connectivity_wrapper.dart:75-77` و`offline_banner.dart:100-106`.

**Impact:** عند الانقطاع قد تظهر طبقتان متداخلتان أو رسالتان متنافستان. كما أن `ConnectivityWrapper` يستخدم `Stack` وموضعاً أعلى الشاشة، بينما `OfflineBanner` يستخدم `Column` ويعيد توزيع مساحة جسم التطبيق. هذا يجعل layout والسلوك معتمدين على التوقيت وحجم الشاشة.

**Recommendation:** اجعل هناك مالكاً واحداً لحالة الاتصال والعرض. افصل signal detection عن presentation عبر provider/service واحد، ثم اختبر screenshot/Widget لحالات الاتصال في Home والرفيق.

**Status:** Implemented = نعم، Integrated = جزئياً، Tested = لا يوجد اختبار للتركيب المزدوج، Verified = لا، Production Ready = لا.

### F-05 — اكتشاف الاتصال لا يساوي إثبات الوصول إلى الـAPI

**Severity:** متوسطة.

**Claim:** `connectivity_plus` يتحقق من وجود واجهة شبكة، لا من نجاح الوصول إلى الخادم؛ بعض المسارات تعالج ذلك بالفشل الاحتياطي، لكن الرسالة العامة لا تميز بين «واجهة متصلة» و«خادم غير متاح».

**Evidence:** `frontend/lib/services/offline_service.dart:38-47` يعيد true إذا وجدت أي نتيجة غير `ConnectivityResult.none`. ثم `api_service.dart:118-128` لا يثبت الوصول إلا بعد طلب الخادم ويمرر الاستثناء إلى fallback. وفي Home، `daily_verse_service.dart:102-126` يرسل الطلب مباشرة ثم يعيد fallback عند exception.

**Impact:** قد لا يظهر شريط offline مع وجود Wi-Fi بلا إنترنت أو DNS/Backend غير متاح، بينما يتصرف المنتج داخلياً كأنه offline. تجربة المستخدم والتشخيص لا يتطابقان، وقد تُفهم التوصية الاحتياطية على أنها نتيجة خدمة سليمة.

**Recommendation:** ميّز في الحالة بين `noNetwork` و`serverUnavailable` و`cached/fallback`. لا تجعل connectivity indicator مصدراً وحيداً للحكم؛ استخدم نتيجة الطلب أو health probe محدوداً عند الحاجة، مع عدم تنفيذ probes متكررة في الخلفية.

**Status:** Implemented = جزئياً، Integrated = جزئياً، Tested = لا يوجد اختبار network fault حقيقي، Verified = لا، Production Ready = لا.

### F-06 — Offline للرفيق محدود بمطابقة كلمات وانفعال سابق

**Severity:** متوسطة وظيفياً.

**Claim:** التوصية دون اتصال ليست تحليلاً محلياً عاماً للنص؛ هي بحث عن ست كلمات انفعالية ثم آخر توصية مخزنة أو fallback.

**Evidence:** `frontend/lib/services/api_service.dart:219-232` يحدد القائمة `['غضب', 'حزن', 'قلق', 'فرح', 'يأس', 'توتر']` ويستدعي `getCachedRecommendation`، ثم latest/fallback. و`frontend/lib/services/offline_service.dart:60-79` يخزن بحد أقصى 20 توصية، بينما `offline_service.dart:121-129` يعرّف fallback ثابتاً.

**Impact:** نص عربي لا يحتوي إحدى الكلمات قد يحصل على آخر توصية لا علاقة لها بالمدخل، كما أن الكاش محدود ويُستبدل. هذا مقبول كـ graceful degradation إذا كان معلناً، لكنه لا يحقق دلالة «تحليل محلي» أو تخصيصاً مستقلاً.

**Recommendation:** وثّق العقد كـ cached fallback، أو نفّذ تصنيفاً محلياً قابلاً للقياس. في كلا الحالين، أعد metadata للمصدر والحداثة، ولا تعرض التوصية القديمة كأنها تحليل للنص الحالي.

**Status:** Implemented = نعم، Integrated = نعم، Tested = نعم جزئياً عبر اختبارات الكاش، Verified = لا، Production Ready = مشروط بوضوح العقد.

### F-07 — تغطية الاختبار لا تثبت رحلة Home/Offline الكاملة

**Severity:** عالية بالنسبة لقرار الإطلاق، متوسطة بالنسبة للكود الحالي.

**Claim:** توجد اختبارات وحدات مفيدة، لكن لا يوجد دليل اختبار قابل للتنفيذ هنا يثبت رحلة فتح Home، ظهور الكاش، الانتقال offline، إرسال نص، fallback، ثم عودة الاتصال ومزامنة التقييم.

**Evidence:** `frontend/test/services/offline_service_test.dart:43-121` يغطي fallback والكاش وحده وتقييمات pending والمسح. `frontend/test/services/home_context_policy_test.dart:64-196` يغطي عتبات وسياسة السياق و`VerseCard`. قائمة الملفات (`find frontend/test -type f`) لا تحتوي اختبار Home أو DailyVerseService أو ConnectivityWrapper. محاولة التشغيل الفعلية في بيئة المراجعة: `cd frontend && flutter test` أعادت `flutter: command not found` و`EXIT=127`.

**Impact:** لا يمكن معرفة ما إذا كانت dependencies الحالية تُترجم، أو إذا كان lifecycle وlayout يعملان على Android/iOS، أو إذا كان سلوك الانقطاع المتزامن مع Stream ينجح. أي ادعاء Verified أو release confidence سيكون غير مدعوم.

**Recommendation:** أضف اختبارات Widget لـHome و`MainShell`، واختبارات خدمة لـ`DailyVerseService` بحقن HTTP client، واختبارات offline/online بمعزل عن plugin الحقيقي. شغّل `flutter analyze`, `flutter test`, وبناء debug/release في CI مع Flutter مقفل الإصدار، ثم احتفظ بسجلات النتائج كأدلة مرتبطة بالـcommit.

**Status:** Implemented = جزئياً، Integrated = غير مثبت، Tested = جزئياً، Verified = لا، Production Ready = لا.

### F-08 — عقد الإنتاج يعتمد على `API_BASE_URL` خارجياً ولا توجد قرينة build

**Severity:** عالية للإصدار.

**Claim:** تشغيل الإنتاج يتطلب تمرير عنوان API في build؛ القيمة الافتراضية ليست عنواناً إنتاجياً.

**Evidence:** `frontend/README.md:5-12` يطلب `--dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1` للتطوير ويشرح أن هذا خاص بمحاكي Android. و`frontend/README.md:14-25` يطلب عنواناً إنتاجياً في build ويحذر من أن القيمة الافتراضية `http://127.0.0.1:8000/api/v1`. كما أن `frontend/lib/services/daily_verse_service.dart:17-20` و`frontend/lib/services/api_service.dart` يستخدمان base URL المعرّف وقت البناء. لم يسجل commit دليلاً على APK مبني أو مثبت.

**Impact:** أي build بلا define أو مع define خاطئ يصل إلى loopback/عنوان محاكي، فتفشل الرحلة الأساسية وتتحول بعض الشاشات إلى fallback. هذا خطر release configuration وليس مجرد خطأ واجهة.

**Recommendation:** اجعل pipeline يمرر قيمة بيئة إلزامية ويفشل مبكراً عند غيابها في release، أو استخدم configuration files آمنة لكل بيئة مع تحقق آلي من scheme/host. أرفق artifact ونتيجة smoke test للـAPK المبني.

**Status:** Implemented = نعم، Integrated = مشروط، Tested = لا يوجد build evidence، Verified = لا، Production Ready = لا.

### F-09 — عدم اتساق قيود Flutter بين manifests والتوثيق

**Severity:** متوسطة لقابلية البناء.

**Claim:** `pubspec.lock` يفرض Flutter `>=3.44.0`، بينما `pubspec.yaml` يعلن Dart `>=3.11.0` فقط، ووثائق المشروع العامة تشير إلى Flutter 3.16+؛ هذا يجعل الحد الأدنى المعلن غير قابل لإعادة الإنتاج من الدليل وحده.

**Evidence:** `frontend/pubspec.yaml:21-23` يعلن Dart `>=3.11.0 <4.0.0`. نهاية `frontend/pubspec.lock` تعلن `dart: >=3.12.0` و`flutter: >=3.44.0`. كذلك `README.md:49` يذكر Flutter `3.16+` للمشروع. لم توجد Flutter CLI في بيئة المراجعة للتحقق من resolver أو build.

**Impact:** بيئة تتبع README قد تفشل في `pub get` أو البناء، بينما البيئة التي أنشأت lockfile تحتاج إصداراً أحدث. هذا يعرقل CI ويخفي اختلافات plugin، خصوصاً مع ترقية `record` في هذا commit (`frontend/pubspec.yaml:49` وdiff commit).

**Recommendation:** ثبّت إصدار Flutter/Dart في وثيقة واحدة وCI (مثل FVM أو container)، حدّث README إلى القيد الفعلي، وأضف خطوة تحقق من `flutter pub get`, `flutter analyze`, والاختبارات قبل قبول تغيير dependencies.

**Status:** Implemented = نعم، Integrated = غير مثبت، Tested = لا، Verified = لا، Production Ready = لا قبل توحيد toolchain.

## الرحلة الأساسية كما يثبتها الكود

1. **بدء التطبيق:** `main.dart:64-89` يهيئ Hive والخدمات ثم يبني `MurassikhApp`.
2. **الدخول إلى الواجهة:** `main.dart:164` يضع `AutoLockGate(child: MainShell())` كصفحة البداية.
3. **Home:** `MainShell:23-28` يضع Home في الوجهة الأولى، و`HomeScreen:49-52` يبدأ تقييم التاريخ وجلب الآية.
4. **عرض الآية:** `HomeScreen:348-359` يقرأ `currentVerse` أو stream، مع shimmer إن لم تصل بطاقة.
5. **تحديث يدوي:** `HomeScreen:118-122` يعيد تقييم التاريخ وطلب الآية.
6. **الرفيق:** `chat_screen.dart` يضيف رسالة المستخدم ويطلق `GetRecommendationEvent`، و`recommendation_bloc.dart:60-72` يستدعي `ApiService.getRecommendation`.
7. **عند offline:** `api_service.dart:114-134` يختار cache/fallback، و`offline_service_test.dart:43-121` يثبت سلوك مخزن Hive على مستوى الوحدة.
8. **العودة online:** `api_service.dart:247-263` يحاول إرسال pending feedback ثم يمسحها عند نجاح الحلقة؛ لا يوجد اختبار تكامل يثبت هذه الرحلة عبر تبديل الشبكة الحقيقي.

## حدود الأدلة

تمت قراءة الملفات الفعلية عند commit `c915d0b`، وتأكدت حالة المستودع دون وجود تغييرات محلية قبل إنشاء هذا التقرير. لم أعدل كود التطبيق أو dependencies أو database ولم أنفذ commit. لم يمكن تشغيل Dart/Flutter لأن الأمرين غير موجودين في بيئة التنفيذ؛ لذلك كل حكم متعلق بالترجمة أو السلوك على جهاز Android/iOS أو APK موقّع يبقى **Inference غير متحقق**، حتى لو كان مسار الكود يبدو متسقاً.

## خطة الإغلاق ذات الأولوية

أولاً، صحّح contract تجربة offline ووحّد مصدر عرض حالة الاتصال، ثم أصلح إلغاء اشتراكات `OfflineBanner` و`HomeScreen`. ثانياً، أضف اختبارات Widget وخدمة مع HTTP وconnectivity fakes تغطي Home والكاش والفشل والعودة online. ثالثاً، وحّد Flutter/Dart toolchain وثبّت `API_BASE_URL` في CI مع build قابل للتتبع. رابعاً، شغّل الاختبارات والتحليل والبناء على Android فعلي أو محاكي، ثم نفذ smoke test واحتفظ بالنتيجة قبل رفع تصنيف المحور إلى Verified أو Production Ready.

## المراجع

[1]: ../../../frontend/lib/main.dart "Flutter application bootstrap"
[2]: ../../../frontend/lib/features/home/presentation/screens/home_screen.dart "Home screen implementation"
[3]: ../../../frontend/lib/services/daily_verse_service.dart "Daily verse service"
[4]: ../../../frontend/lib/services/api_service.dart "API and offline recommendation service"
[5]: ../../../frontend/lib/services/offline_service.dart "Offline storage service"
[6]: ../../../frontend/lib/widgets/offline_banner.dart "Offline banner widget"
[7]: ../../../frontend/test/services/offline_service_test.dart "Offline service tests"
[8]: ../../حالة-المنتج-2026-09-22.md "Product status and release decision"
[9]: ../P3_acceptance_report.md "P3 acceptance checklist"
[10]: ../../../frontend/README.md "Frontend run and build instructions"
[11]: ../../../frontend/pubspec.lock "Resolved Flutter/Dart constraints"

## مصطلحات الحالة

**Fact:** ما يظهر مباشرة في الملف أو مخرجات الأمر. **Evidence:** المسار ورقم السطر أو نتيجة الأمر التي يمكن إعادة فحصها. **Inference:** استنتاج هندسي محدود من الأدلة، وليس إثبات تشغيل. **Recommendation:** الإجراء المقترح للإغلاق. **Implemented:** كود موجود. **Integrated:** موصول ضمن التطبيق. **Tested:** له اختبار موجود أو نتيجة اختبار. **Verified:** تحقق تنفيذي في بيئة محددة. **Production Ready:** اجتاز أدلة البناء والتشغيل والأجهزة والاعتمادية المطلوبة؛ لا يكفي وجود الكود وحده.

[1] [2] [3] [4] [5] [6] [7] [8] [9] [10] [11]

---

**القرار النهائي:** الواجهة والرحلة الأساسية وطبقة Offline موجودة ومترابطة جزئياً، لكن لا يوجد دليل تنفيذي كافٍ لتصنيفها Verified أو Production Ready عند هذا الـcommit.
