# تقرير مراجعة Principal Software Engineer
## المحور: History وMemory واستمرارية المحادثة

**المستودع:** `/home/ubuntu/murasikh`  
**النقطة المراجَعة:** `c915d0b03ff976c731e36cd98f6343bedd56f904`  
**نطاق المراجعة:** الشيفرة والاختبارات والوثائق الفعلية المتعلقة بسجل التفاعلات، ذاكرة الوكيل الحواري، تخزين رسائل الدردشة، المزامنة، الحذف، وعزل المستخدمين.  
**تاريخ المراجعة:** 2026-09-23

> لم أعدّل أي ملف في المستودع، ولم أنفذ commit، ولم أغيّر API أو قاعدة البيانات أو dependencies. التقرير يميّز بين **Fact** و**Evidence** و**Inference** و**Recommendation**، وبين **Implemented** و**Integrated** و**Tested** و**Verified** و**Production Ready**.

## 1. الخلاصة التنفيذية

يوجد في commit المراجع تنفيذ حقيقي لطبقتين مختلفتين ينبغي عدم تسميتهما ذاكرة واحدة. الطبقة الخلفية تحفظ تفاعلات المستخدم المصادق عليه في جدول `interactions`، وتسترجع آخر خمس تفاعلات، ثم تمررها إلى `ConversationalAgent` في مسار `/api/v1/analyze`. هذه الطبقة **Implemented** و**Integrated** على مستوى المسار النصي، وتوجد لها اختبارات مصدرية جيدة لعزل المستخدم وحقن السياق. لكن لم يمكن تشغيل الاختبارات في البيئة الحالية لأن `pytest` غير مثبت (`bash: pytest: command not found`). لذلك هي **Tested by code presence** وليست **Verified by execution** في هذه المراجعة.

أما واجهة الدردشة فتنفذ استمرارية عرض محلية عبر Hive في box عالمي اسمه `murassikh_chat_box`. هذه الاستمرارية تحفظ الرسائل وتعيد عرضها بعد إعادة فتح الشاشة/التطبيق، لكنها لا تُمرر الرسائل المحلية إلى الخادم أو الوكيل؛ الوكيل يعتمد على سجل قاعدة البيانات الخلفية فقط. لذلك فالاستمرارية المحلية **Implemented** للعرض، لكنها ليست ذاكرة نموذجية مستقلة ولا ضماناً لاستمرارية المحادثة عبر الحسابات أو دون المصادقة.

النتيجة الأهم: الحالة الحالية ليست **Production Ready** لمحور الذاكرة واستمرارية المحادثة بسبب خطر اختلاط بيانات المستخدمين على الجهاز، وعدم اتساق عمليتي «مسح المحادثة» و«مسح السجل»، وتفاوت مسارات النص والصوت، ووجود اختبارات لا يمكن إثبات تشغيلها من البيئة الحالية. أوصي باعتبارها **Partially integrated / not production-ready for privacy-sensitive multi-account continuity** إلى أن تُعالج النتائج عالية وخطيرة الأثر أدناه.

## 2. خريطة التنفيذ الفعلي وحالة كل طبقة

| المكوّن | Implemented | Integrated | Tested | Verified في هذه المراجعة | Production Ready |
|---|---:|---:|---:|---:|---:|
| حفظ `Interaction` في PostgreSQL للمستخدم المصادق | نعم | نعم في مسار النص والصوت | توجد اختبارات مصدرية | لا؛ `pytest` غير متاح | جزئياً فقط |
| استرجاع آخر 5 تفاعلات وتمريرها للوكيل النصي | نعم | نعم في `/api/v1/analyze` | اختبار تكامل مصدره يمرر تفاعلين | لا؛ لم يُنفذ الاختبار | جزئياً فقط |
| ذاكرة الوكيل داخل prompt | نعم | نعم للمسار النصي | لا يوجد تحقق حي من استدعاء النموذج هنا | لا | لا يمكن اعتمادها إنتاجياً دون اختبار حي/مراقبة |
| تخزين رسائل شاشة الدردشة محلياً | نعم | نعم مع `ChatScreen` | اختبارات Widget مصدرية | لا؛ `flutter` غير مثبت | لا بسبب عدم عزل الحساب |
| تمرير Hive chat history إلى backend | لا | لا | لا | لا | لا |
| مزامنة `HistoryService` المحلي/البعيد | نعم جزئياً | نعم لشاشة السجل | توجد اختبارات خدمة، دون تشغيل | لا | لا بسبب namespace عالمي وسياسة الدمج |
| مسح محادثة الشاشة ومسح history الخلفي كعملية واحدة | لا | لا | لا | لا | لا |
| مسار الصوت مع ذاكرة حوارية مماثلة لمسار النص | لا | لا؛ يستخدم user context فقط | اختبارات الصوت لا تثبت الاستمرارية | لا | لا |

## 3. النتائج التفصيلية

### M-01 — خطير: تخزين محادثة Hive في box عالمي غير مرتبط بالمستخدم

**Severity:** Critical  
**Kind:** Privacy / data isolation / conversation continuity

**Fact:** `HiveChatStorage` يفتح box ثابتاً واحداً هو `murassikh_chat_box`، و`ChatScreen` يحمّل كل قيمه ويعرضها. لا يوجد في `ChatMessage` أو مفتاح التخزين `user_id` أو username أو tenant identifier.

**Evidence:**

- `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:14-20` يعرّف `HiveChatStorage` ويفتح `Hive.openBox<String>('murassikh_chat_box')`.
- `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:24-32` يقرأ كل `_chatBox.values` ويحوّلها إلى رسائل.
- `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:36-48` يستخدم `add` و`putAt` دون namespace للمستخدم.
- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:17-55` يحتوي `ChatMessage` على النص والزمن والتقييم والتوصية فقط، دون هوية مالك.
- `frontend/lib/services/auth_service.dart:97-116` يمسح token وusername عند logout، لكنه لا يمسح `murassikh_chat_box` ولا يبدّل مفتاحه بحسب الحساب.

**Inference:** إذا سجّل مستخدم A الخروج ثم سجّل مستخدم B الدخول على الجهاز نفسه، فسيقرأ B محتوى box نفسه. هذا اختلاط بيانات محلي قابل للاختبار، وليس مجرد احتمال نظري؛ يعتمد على مسار تحميل مباشر غير مشروط بهوية المستخدم. كما أن الرسائل المحلية قد تتناقض مع سجل B الخلفي وتخلق سياقاً بصرياً مضللاً.

**Recommendation:** اربط مخزن الدردشة بمُعرّف مستخدم ثابت وآمن (أو box/keys منفصلة لكل account)، وامسح/اعزل البيانات عند logout وتبديل الحساب وفق سياسة خصوصية صريحة. أضف اختباراً بين حسابين على الجهاز نفسه يثبت عدم ظهور رسالة A في B، واختباراً لإعادة الدخول بالحساب نفسه يثبت الاستعادة المقصودة.

**الحالة:** التخزين **Implemented** وواجهة الدردشة **Integrated** معه؛ لا يوجد دليل تنفيذ اختبار في هذه المراجعة، وهو ليس **Production Ready** لعزل متعدد الحسابات.

---

### M-02 — عالٍ: «مسح المحادثة» لا يمسح الذاكرة التي يستخدمها الوكيل

**Fact:** زر مسح المحادثة داخل `ChatScreen` يمسح box المحلي فقط، بينما backend يعيد بناء `chat_history` من `Interaction` المخزن في قاعدة البيانات في كل طلب نصي للمستخدم المصادق عليه.

**Evidence:**

- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:188-214` يعرض تأكيداً ثم ينفذ `_storage.clear()` و`_loadMessages()` فقط.
- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:327-332` يربط زر «مسح المحادثة» بهذه الدالة.
- `backend/app/api/v1/endpoints/recommend.py:55-75` ينشئ `HistoryService`، يجلب آخر 5 تفاعلات ويحوّل كل تفاعل إلى رسالة user ثم ai.
- `backend/app/api/v1/endpoints/recommend.py:83-85` يمرر `chat_history` إلى `agent.analyze(...)`.
- `backend/app/api/v1/endpoints/history.py:34-44` يوضح أن حذف السجل الخلفي عملية API منفصلة (`DELETE /api/v1/history`).

**Inference:** بعد ضغط المستخدم «مسح المحادثة»، تختفي الرسائل من الجهاز، لكن الرسائل الخلفية ما زالت تدخل prompt في الطلب التالي. معنى زر المسح إذن «إخفاء العرض المحلي» لا «بدء محادثة جديدة»؛ وهذا يخالف التوقع الطبيعي للنص المعروض للمستخدم ويضعف قابلية التحكم في الذاكرة.

**Recommendation:** عرّف عقداً واضحاً بين `clear chat` و`clear history`: إما أن يبدأ زر المحادثة الجديدة conversation/session id جديداً ويستبعد السجل السابق من الذاكرة، أو ينفذ حذفاً/تصفيراً صريحاً على الخادم بعد تأكيد منفصل. يجب أن يتطابق النص في الواجهة مع الأثر الفعلي، ويجب اختبار أن الطلب بعد المسح لا يحتوي الرسائل القديمة.

**الحالة:** عمليتا المسح **Implemented** منفصلتين، لكنهما غير **Integrated** كدلالة واحدة، وليستا **Production Ready** من منظور توقع المستخدم والتحكم بالذاكرة.

---

### M-03 — عالٍ: عدم اتساق «مسح السجل»؛ يبقى سجل الدردشة المحلي بعد حذف history الخلفي

**Fact:** شاشة history تستدعي `HistoryService.clearHistory()`، وهذه تمسح box `murassikh_local_history` فقط بعد نجاح الحذف البعيد. لكنها لا تمسح box `murassikh_chat_box` الذي تستخدمه شاشة الدردشة.

**Evidence:**

- `frontend/lib/features/history/history_screen.dart:34-57` ينفذ `_historyService.clearHistory()` ثم يعيد تحميل شاشة السجل.
- `frontend/lib/services/history_service.dart:88-90` يعرّف box منفصلاً باسم `murassikh_local_history`.
- `frontend/lib/services/history_service.dart:202-217` يمسح `_box` الخاص بالسجل المحلي فقط بعد نجاح `DELETE /history`.
- `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:20` يفتح box مختلفاً هو `murassikh_chat_box`.
- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:156-176` سيعيد تحميل الرسائل القديمة من chat box عند فتح الشاشة.

**Inference:** يمكن للمستخدم حذف «جميع سجلات التوجيه» بنجاح من الخادم وشاشة history، ثم رؤية الرسائل القديمة مجدداً في شاشة الدردشة. هذا يضعف حق الحذف ويجعل حالة العرض والذاكرة غير متزامنتين؛ وإذا كان الهدف حذف البيانات، فالمحادثة المحلية تبقى نسخة إضافية.

**Recommendation:** اربط عملية حذف البيانات بسياسة موحدة تحدد هل الدردشة جزء من history. عند الحذف الشامل، امسح مخزن المحادثة المحلي المرتبط بالحساب أيضاً، أو اعرض بوضوح أن «مسح السجل» لا يمسح نص المحادثة. أضف اختباراً يغطي الحذف من شاشة history ثم إعادة فتح ChatScreen.

**الحالة:** كل مكوّن **Implemented** بمفرده، لكن التكامل الوظيفي **غير مكتمل**؛ لا يمكن اعتباره **Verified** أو **Production Ready** لطلبات حذف البيانات.

---

### M-04 — عالٍ: المسار الصوتي لا يمرر ذاكرة المحادثة إلى وكيل حواري

**Fact:** المسار النصي يستدعي `ConversationalAgent.analyze` مع `chat_history`، بينما المسار الصوتي يحلل النبرة ثم يبني semantic query من `get_user_context` (التفضيلات الناتجة من feedback) ولا يمرر سجل الرسائل السابق إلى `ConversationalAgent`.

**Evidence:**

- `backend/app/api/v1/endpoints/recommend.py:57-85` يكوّن `chat_history` ويمرره فعلياً إلى الوكيل.
- `backend/app/api/v1/endpoints/audio.py:93-127` يحلل الصوت ويستعمل `history_service.get_user_context(user['id'])` لإضافة تفضيلات إلى الاستعلام، دون إنشاء `chat_history` ودون استدعاء `agent.analyze`.
- `backend/app/api/v1/endpoints/audio.py:210-223` يسجل التفاعل الصوتي في `Interaction`، لكنه لا يجعله جزءاً من prompt حواري صوتي لاحق.
- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:671-689` يرسل `AnalyzeAudioEvent` مع implicit context (ملامح الوجه/النبض)؛ لا يرسل قائمة الرسائل المحلية.

**Inference:** النص والصوت قد يستخدمان تاريخاً مشتركاً في جدول البيانات لأغراض الاستدلال العاطفي/التفضيلات، لكنهما لا يقدمان نفس مفهوم استمرارية المحادثة. الانتقال من نص إلى صوت لا يضمن أن الوكيل يعرف الحوار السابق؛ وهذا اختلاف عقدي يجب أن يكون مقصوداً ومعلناً، لا نتيجة تنفيذية صامتة.

**Recommendation:** قرر صراحة هل الصوت جزء من نفس conversation/session. إن كان كذلك، مرر تاريخاً محدوداً ومطبعاً إلى مسار الصوت أو وحّد طبقة بناء الذاكرة قبل التحليل. إن لم يكن كذلك، وثّق أن الصوت recommendation مستقل، وأضف اختبار عقد يثبت السلوك المختار.

**الحالة:** حفظ الصوت في history **Implemented**، لكن التكامل مع ذاكرة الوكيل **غير Implemented**؛ ليس **Production Ready** إذا كان المنتج يعد باستمرارية متعددة الوسائط.

---

### M-05 — متوسط: السجل الخلفي يحفظ «آخر 5 تفاعلات» لكنه ليس نموذج محادثة/جلسة كامل

**Fact:** `HistoryService.get_history` يعيد تفاعلات المستخدم بحد افتراضي 100، ومسار التوصية يطلب آخر 5 ثم يعكس ترتيبها ويضيف user/ai pairs. لا يوجد `conversation_id` أو `session_id` في `Interaction`، ولا توجد حدود tokens أو تلخيص قبل إدخال النصوص في prompt.

**Evidence:**

- `backend/app/services/history_manager.py:70-97` يرتب حسب `created_at` تنازلياً ويطبق `limit`، ويعيد `input_text` و`recommendation.message`.
- `backend/app/api/v1/endpoints/recommend.py:60-75` يحدد `limit=5` ويضيف رسالتين لكل تفاعل.
- `backend/app/db/models.py:86-106` يبين حقول `Interaction` ولا يحتوي `conversation_id`/`session_id` أو token budget.
- `backend/app/services/ai/conversational_agent.py:75-83` يضم كل عناصر `chat_history` كسلاسل نصية مباشرة ثم يضيف الرسالة الحالية.
- `backend/app/api/v1/endpoints/recommend.py:26-30` يحد نص الطلب الحالي إلى 1000 حرف، لكن لا يضع حداً مماثلاً لمجموع تاريخ الرسائل أو طول الردود السابقة.

**Inference:** التنفيذ يحقق short-term memory على مستوى المستخدم لا conversation memory على مستوى جلسة. يمكن أن تنتقل آخر تفاعلات من موضوع أو جلسة قديمة إلى موضوع جديد، وقد يكبر prompt مع ردود طويلة دون ضمان budget. كما أن اختيار آخر خمسة حسب الزمن لا يميز بين «محادثة جديدة» و«استئناف محادثة».

**Recommendation:** أضف مفهوم session/conversation أو آلية reset صريحة، وحدد ميزانية tokens/characters بعد التطبيع والتلخيص، واحفظ الأدوار والعلاقة الزمنية بوضوح. اختبر الترتيب، truncation، والاستقلال بين جلستين للمستخدم نفسه.

**الحالة:** حل مبسط **Implemented/Integrated**؛ الاختبارات المصدرية تثبت نجاح المسار شكلياً، لكنها لا تثبت حدود prompt أو semantics الجلسة؛ ليس **Production Ready** كذاكرة محادثة طويلة الأمد.

---

### M-06 — متوسط: التخزين المحلي للسجل غير namespaced، ويمتزج مع remote history عند المزامنة

**Fact:** `HistoryService` يخزن التفاعلات المحلية في box ثابت `murassikh_local_history`، ثم يدمج كل المحلي مع remote items دون ربط الحساب الحالي بهوية مالك محلية.

**Evidence:**

- `frontend/lib/services/history_service.dart:83-100` يعرّف singleton وbox ثابتاً باسم `murassikh_local_history`.
- `frontend/lib/services/history_service.dart:103-115` يحفظ التفاعل المحلي بمفتاح timestamp محلي.
- `frontend/lib/services/history_service.dart:137-163` يجلب remote history، ثم يضع remote والمحلي في `merged` ويعيدهما معاً؛ لا يظهر شرط user namespace للمحلي.
- `frontend/lib/services/auth_service.dart:97-116` لا يمسح هذا box في logout.
- `frontend/lib/services/history_service.dart:165-170` يعتمد على المحلي كلياً عند فشل الاتصال.

**Inference:** حتى لو كان backend يعزل `/history` حسب token، قد يعرض العميل سجلات محلية قديمة لحساب آخر أو سجلات offline لمستخدم سابق. وهذا يوسع M-01 من chat box إلى history box ويجعل offline fallback غير آمن في جهاز مشترك.

**Recommendation:** خزّن local history ضمن namespace مشتق من user id غير قابل للتغيير في واجهة المستخدم، أو امسحه عند logout قبل السماح بحساب آخر، مع سياسة واضحة للبيانات offline قبل تسجيل الدخول. لا تخلط local pending records مع remote records إلا بعد تعريف ownership وحالة المزامنة، وأضف اختبار تبديل الحساب/انقطاع الشبكة.

**الحالة:** المزامنة **Implemented** جزئياً و**Integrated** مع شاشة history، لكنها ليست **Verified** في سيناريو تبديل الحساب وليست **Production Ready** للخصوصية.

---

### M-07 — متوسط: `getFeedbackContext()` واجهة ذاكرة فارغة وغير مستخدمة، وتوجد ازدواجية بين chat storage وhistory storage

**Fact:** توجد دالة `getFeedbackContext()` في `HistoryService` تعيد السلسلة الفارغة دائماً، بينما الاستفادة الفعلية من feedback تتم في الخادم عبر `get_user_context`. كما أن التوصية تُحفظ في local history عبر `ApiService` بينما رسائل الدردشة تُحفظ مرة أخرى في chat box.

**Evidence:**

- `frontend/lib/services/history_service.dart:119-121` يعيد `getFeedbackContext()` قيمة `""` بلا تنفيذ.
- `backend/app/services/history_manager.py:99-129` يبني user context فعلياً من `user_feedback`، ويحد liked/disliked إلى ثلاث حالات لكل نوع.
- `frontend/lib/services/api_service.dart:118-133` يستدعي `HistoryService().saveInteraction(...)` في حالات الاتصال، الفشل، والعمل دون اتصال.
- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:261-299` يحفظ user message وAI message في `ChatStorage` منفصل.

**Inference:** توجد صورتان للذاكرة على العميل: سجل تفاعل منظم وسجل رسائل حر. لا توجد طبقة reconciliation أو عقد يحدد المصدر المرجعي. كما أن وجود API فارغ باسم feedback context يوحي باستمرارية محلية غير موجودة فعلياً، وقد يربك المطورين أو الاختبارات المستقبلية.

**Recommendation:** اختر source of truth واضحاً، واحذف الواجهة الميتة أو نفذها بعقد موثق، وعرّف حالة كل سجل (local-only/pending/synced). اربط `interaction_id` remote بالمحلي بدلاً من مفاتيح timestamp فقط، وأضف اختبارات تمنع التكرار أو الانفصال بين العرض وسجل API.

**الحالة:** أجزاء متعددة **Implemented**، لكن التكامل المعماري **غير محسوم**؛ لا تصح عبارة ذاكرة موحدة **Production Ready**.

---

### M-08 — منخفض/متوسط: تقييم رسالة الدردشة قد لا يحدّث السجل المحلي بسبب اختلاف المفتاح

**Fact:** رسالة الدردشة المحلية تخزنها `HiveChatStorage` بمؤشر box، بينما `HistoryService.saveInteraction` يستخدم timestamp string كمفتاح. عند تقييم رسالة الدردشة يستدعي الكود `HistoryService.updateFeedback` بمعرّف التفاعل الخلفي، وتحاول الدالة تحديث `_box.get(id)` في history box.

**Evidence:**

- `frontend/lib/features/chat/presentation/screens/chat_screen.dart:367-397` يحفظ تقييم الرسالة ثم يستخرج `msg.recommendation?.interactionId` ويرسله إلى `HistoryService.updateFeedback`.
- `frontend/lib/services/history_service.dart:103-113` يحفظ سجل التفاعل المحلي بالمفتاح `item.id` المولّد من milliseconds.
- `frontend/lib/services/history_service.dart:173-185` يبحث عن `_box.get(id)` حيث `id` هو المعرف الرقمي البعيد؛ لا يثبت الكود أن هذا يساوي المفتاح المحلي timestamp.
- `frontend/lib/services/history_service.dart:189-199` يرسل feedback للخادم بشكل منفصل، وقد ينجح تحديث الخادم حتى لو لم يتحدث المحلي.

**Inference:** تقييم UI قد يبدو ناجحاً داخل الرسالة لأن `ChatMessage.feedback` يتغير، لكن سجل history المحلي قد يبقى بتقييم قديم، خصوصاً offline أو قبل المزامنة. هذا يسبب divergence بين العرض، local history، وremote Interaction.

**Recommendation:** خزّن remote interaction id كحقل مستقل في `HistoryItem`/المفتاح، أو استخدم mapping صريحاً بين ChatMessage وHistoryItem، مع queue موحدة للتقييم والمزامنة. أضف اختباراً يتحقق من تحديث نفس السجل في chat وhistory وserver.

**الحالة:** الوظيفة الأساسية **Implemented**، لكن الاتساق المحلي **غير مثبت** وغير **Production Ready** في offline mode.

## 4. ما تم إثباته وما لم يتم إثباته

### 4.1 Implemented وIntegrated — مثبت من الشيفرة

1. **حفظ التفاعل الخلفي:** `HistoryService.add_record` يبني `Interaction` ويحفظه مع `user_id`, `query_text`, emotion, message, source, tafsir, confidence وfeedback في `backend/app/services/history_manager.py:16-43`؛ نموذج الحقول في `backend/app/db/models.py:86-106`.
2. **قراءة history بعزل المستخدم:** `get_history` يفلتر `Interaction.user_id` في `backend/app/services/history_manager.py:70-78`، وواجهة API محمية بـ`get_current_user` في `backend/app/api/v1/endpoints/history.py:21-31`.
3. **ذاكرة نصية قصيرة:** `/api/v1/analyze` يجلب آخر خمسة ويحوّلها إلى أدوار مرتبة زمنياً في `backend/app/api/v1/endpoints/recommend.py:55-85`.
4. **إدخال الذاكرة في prompt:** `ConversationalAgent` يضيف `[سجل المحادثة الأخير]` ثم الرسالة الحالية في `backend/app/services/ai/conversational_agent.py:75-83`.
5. **تخزين رسائل UI محلياً:** `ChatMessage.toMap/fromMap` وHive storage في `frontend/lib/features/chat/presentation/screens/chat_screen.dart:17-55` و`frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:14-48`.
6. **حفظ feedback على الخادم بعزل user:** `HistoryService.update_feedback` يرشح بالـ`record_id` و`user_id` في `backend/app/services/history_manager.py:45-55`.

### 4.2 Tested — دليل اختبارات موجود في المستودع

- `backend/tests/test_api/test_user_isolation.py:55-98` يختبر أن مستخدماً لا يقرأ أو يغيّر history مستخدم آخر.
- `backend/tests/test_api/test_recommend_integration.py:145-172` يختبر عدم حفظ history للمستخدم غير المصادق.
- `backend/tests/test_api/test_recommend_integration.py:175-209` ينشئ تفاعلاً، يرسل feedback، ثم يرسل تفاعلاً ثانياً مع user context.
- `frontend/test/features/chat/presentation/screens/chat_screen_test.dart:107-234` يغطي رسم ChatScreen، إرسال النص، عرض recommendation، error، وإلغاء timer. الاختبار يستخدم `FakeChatStorage` في السطور 16-40، ولذلك لا يثبت سلوك Hive الحقيقي أو عزل الحسابات.
- `frontend/test/services/history_service_test.dart` موجود ويغطي parsing لـ`DelayedResponseItem` وفق نتائج البحث عن الملف، لكن لا يوجد في الدليل المتاح اختبار تبديل الحساب أو اتساق clear بين boxين.

### 4.3 Verified — نتيجة التنفيذ في هذه المراجعة

لم أستطع تحويل الأدلة المصدرية إلى **Verified by execution**:

- تشغيل `pytest -q backend/tests/test_api/test_recommend_integration.py backend/tests/test_api/test_user_context.py backend/tests/test_api/test_user_isolation.py` فشل قبل بدء الاختبارات بالخرج: `bash: pytest: command not found`، exit code `127`.
- محاولة تشغيل اختبارات Flutter أعطت: `flutter-not-installed`.
- لم أنشئ بيئة بديلة ولم أعدّل dependencies، التزاماً بنطاق المهمة.

لذلك لا يجوز نقل عبارات الوثيقة `docs/plans/todo_4.md:30-32` («اختبارات الاستقرار» و«التأكد من نجاح الاختبارات») إلى حكم Verified لهذا commit من دون سجل CI أو تنفيذ مستقل قابل للتتبع.

## 5. مراجعة الوثائق مقابل التنفيذ

الوثيقة `docs/plans/todo_4.md:1-3` تصف التحول إلى «مساعد حواري ذكي» و«ذاكرة داخل الجلسة». وفي `:14-19` توثق جلب آخر خمسة تفاعلات وتمريرها للوكيل. هذا الوصف مدعوم فعلاً للمسار النصي بواسطة `recommend.py` و`conversational_agent.py` المشار إليهما أعلاه.

لكن الوثيقة لا تذكر القيود التي ظهرت في التنفيذ: عدم وجود session/conversation id، اعتماد الذاكرة على المستخدم لا على الجلسة، اختلاف مسار الصوت، وعدم ارتباط Hive بالحساب. كما أن دليل المستخدم `docs/04-user-guide/البدء-السريع.md:81-94` يقول إن سجل التفاعلات يحفظ محلياً ويستعاد دون اتصال، بينما الكود يطبق ذلك على `murassikh_local_history` فقط، ولا يوضح أن chat box منفصل ولا يذكر حدود الخصوصية أو أثر logout. يجب تحديث التوثيق ليصف contract الفعلي لا الوعد العام.

## 6. حكم الجاهزية

**الحكم العام لمحور History/Memory:** **Partially Implemented, partially integrated, source-tested but not execution-verified, and not Production Ready.**

الجزء الخلفي للنص قابل للبناء عليه: توجد ملكية `user_id`، مسارات محمية، history قصيرة، وحقن فعلي في prompt. لكن الجاهزية الإنتاجية تتطلب أولاً معالجة M-01 إلى M-04، لأنها تمس الخصوصية ودلالة المسح واتساق التجربة واستمرارية الوسائط. ثم معالجة M-05 إلى M-08 لضبط نموذج الجلسة، المزامنة، والتقييم. لا أوصي بإعلان «ذاكرة محادثة مستمرة» كميزة مكتملة قبل وجود اختبارات تنفيذية في CI تشمل تبديل الحساب، logout/login، clear chat، clear history، offline/online، النص/الصوت، وحدود طول السياق.

## 7. خطة تحقق آمنة مقترحة (لا تنفذها هذه المراجعة)

1. شغّل backend test suite في CI ببيئة dependencies المعتمدة، وسجّل commit ونتيجة كل اختبار؛ لا تعتبر وجود ملفات الاختبار دليلاً على التنفيذ.
2. نفّذ اختبار حسابين على جهاز واحد: رسالة A، logout، login B، ثم تحقق من عدم ظهورها في ChatScreen وHistoryScreen وoffline fallback.
3. نفّذ اختبار `clear chat` ثم طلب نصي جديد وتحقق من عدم إرسال أي Interaction قديم إلى `ConversationalAgent`، أو وثّق بوضوح أن المسح بصري فقط.
4. نفّذ اختبار `clear history` ثم افتح الدردشة وتحقق من سياسة الحذف المعتمدة، مع فحص server rows وHive boxes.
5. نفّذ اختباراً انتقالياً نص→صوت→نص، وسجّل exact prompt/context للتأكد من العقد المقصود.
6. اختبر prompt budget مع خمسة ردود طويلة ورسالة بطول الحد، وتحقق من truncation/summary وعدم تجاوز حدود مزود النموذج.
7. اختبر feedback online/offline وتطابق `interaction_id` بين `ChatMessage`, `HistoryItem`, و`Interaction`.

**نهاية التقرير.**
