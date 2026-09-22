# تقرير مراجعة Backend وAPI وDatabase وAuthentication

## نطاق المراجعة وحالة المصدر

راجعت المصدر الفعلي لمستودع **Murasikh** عند commit `c915d0b03ff976c731e36cd98f6343bedd56f904`، وهو نفس ناتج الأمر `git rev-parse HEAD`. كان `git status --short` فارغاً، ولم أعدّل أي ملف في المستودع، ولم أنفذ commit أو أغيّر API أو قاعدة البيانات أو الاعتمادات.

يغطي هذا التقرير طبقة FastAPI، عقود المسارات، JWT وArgon2، SQLAlchemy وAlembic، عزل بيانات المستخدم، Redis/Chroma readiness، وسلوك التشغيل الموصوف في Compose والوثائق. أستخدم التصنيفات التالية صراحة:

- **Fact:** ما يظهر مباشرة في الكود أو الوثيقة.
- **Evidence:** مسار الملف ورقم السطر أو نتيجة أمر قابلة لإعادة التتبع.
- **Inference:** الأثر الهندسي المستنتج من الـ Fact، مع بيان حدوده.
- **Recommendation:** الإجراء المقترح، من دون تنفيذه في هذه المراجعة.

## الخلاصة التنفيذية

البنية الأساسية **Implemented** بدرجة جيدة: توجد مسارات FastAPI فعلية للتسجيل والدخول والتحديث والخروج والتاريخ، وتوجد حماية JWT، وتجزئة Argon2، وتدوير ذري لـ refresh JTI، وتهيئة SQLAlchemy، وسلسلة Alembic، وعزل استعلامات التاريخ حسب `user_id`. كما أن Compose الإنتاجي يربط PostgreSQL وRedis وChroma ويشغّل `alembic upgrade head` قبل Uvicorn.

بعض هذه الأجزاء **Integrated** في مسار التشغيل، وخصوصاً JWT مع routers وPostgreSQL مع entrypoint وRedis مع rate limiting. لكن لا يصح إعلان المحور **Tested** أو **Verified** بالكامل من هذه البيئة: أمر `pytest` فشل لأن executable غير موجود، وأمر `alembic` فشل للسبب نفسه، واستيراد إعدادات التطبيق فشل لأن `pydantic_settings` غير مثبتة. يوجد تعريف CI يشغّل الاختبارات والترحيلات، لكنه دليل على إعداد CI وليس نتيجة تشغيل ناجح عند هذا الـ commit.

لا أوصي باعتبار المحور **Production Ready** بلا تحفظ. أعلى مخاطرة وظيفية هي فصل حفظ التفاعل عن حفظ الرد المؤجل في معاملتي قاعدة بيانات مستقلتين؛ فالفشل بينهما يمكن أن يترك تفاعلاً معلّماً `response_delayed=true` بلا سجل رد مؤجل. توجد أيضاً فجوة أمنية في سياسة كلمات المرور، ومحدودية واضحة في إلغاء access tokens عند logout، وهشاشة تشغيلية في readiness بسبب رقم Chroma الثابت.

## حالة التنفيذ حسب البعد

| البعد | الحكم | الدليل | حدود الحكم |
|---|---|---|---|
| Implemented | نعم، جزئياً وبشكل ملموس | `backend/app/main.py:10-34` يسجل routers؛ `backend/app/api/v1/endpoints/auth.py:32-178` ينفذ auth؛ `backend/app/db/database.py:6-17` يهيئ SQLAlchemy؛ `backend/alembic/versions/*.py` تحتوي السلسلة | لا يعني ذلك أن كل تدفق ذري أو كل سياسة أمان مكتملة |
| Integrated | نعم في المسارات الرئيسية | `docker-compose.production.yml:58-75` يمرر الإعدادات ويشغل الترحيلات؛ `backend/app/core/security.py:30-35` يربط Redis بالـ limiter؛ `backend/app/main.py:29-34` يربط routers | لم أتحقق من تشغيل Compose فعلياً في هذه البيئة |
| Tested | جزئياً فقط | توجد اختبارات وCI في `backend/tests` و`.github/workflows/main.yml:77-102` | `pytest` غير مثبت محلياً؛ لذلك لا توجد نتيجة اختبار محلية ناجحة يمكن نسبتها إلى هذا التقرير |
| Verified | جزئياً من قراءة المصدر | اختبارات المصادقة والعزل والتدوير موجودة، ومنها `backend/tests/test_api/test_user_isolation.py:55-121` و`test_refresh_rotation.py:1-25` | وجود الاختبار ليس دليلاً على نجاحه؛ لم يمكن تشغيله محلياً |
| Production Ready | لا | توجد ضوابط جيدة، لكن توجد الملاحظات عالية/متوسطة الأولوية أدناه، كما أن وثيقة النشر نفسها تترك عناصر checklist غير مؤكدة في `docs/05-deployment/دليل-النشر.md:206-215` | الحكم خاص بالمحور وبالمصدر محل المراجعة، وليس حكماً على المنتج كله |

## النتائج التفصيلية

### F-01 — فصل حفظ التفاعل عن الرد المؤجل يخرق الاتساق الذري

**Severity: High — Database/API integration**

**Fact:** مسار التوصية يحفظ `Interaction` أولاً، ثم يقرر ويحفظ `DelayedResponse` في استدعاء منفصل. يضع المسار `response_delayed=bool(delayed_message and should_delay)` عند إنشاء التفاعل، ثم يستدعي `DelayedResponseService.schedule` لاحقاً.

**Evidence:** في `backend/app/api/v1/endpoints/recommend.py:241-269` يُستدعى `history_service.add_record(...)` ثم بعده `DelayedResponseService(db).schedule(...)`. وفي `backend/app/services/history_manager.py:28-42` تنفذ `add_record` `db.commit()` قبل الرجوع. وفي `backend/app/services/delayed_response_service.py:30-42` تنفذ `schedule` `db.commit()` ثانية.

**Inference:** إذا نجح commit الأول وفشل الثاني بسبب انقطاع قاعدة البيانات أو خطأ في payload أو قيد مستقبلي، تبقى الاستجابة معلّمة بأنها مؤجلة من دون صف مؤجل قابل للتسليم. لا توجد معاملة واحدة أو تعويض واضح يعيد حالة التفاعل.

**Recommendation:** اجعل المسار يستخدم `flush()` بدلاً من commit داخل الخدمتين، وأنشئ التفاعل والرد المؤجل في معاملة واحدة يملكها endpoint أو وحدة خدمة orchestration. عند الفشل نفّذ rollback واحداً، وأضف اختباراً يحاكي فشل إنشاء الرد بعد flush التفاعل ويتحقق من عدم بقاء حالة نصف مكتملة.

### F-02 — logout يبطل refresh token فقط ولا يبطل access token الجاري

**Severity: Medium — Authentication**

**Fact:** logout يستدعي `set_refresh_jti(..., None)` فقط. أما التحقق من access token فيفحص توقيع JWT ونوعه ووجود المستخدم النشط، ولا يفحص حالة إبطال مرتبطة بالـ access token.

**Evidence:** `backend/app/api/v1/endpoints/auth.py:170-178` يصفّر `refresh_jti` عند logout. `backend/app/api/v1/endpoints/auth.py:113-127` يستدعي `verify_token(token)` ثم يبحث عن المستخدم فقط. `backend/app/core/auth.py:52-61` يتحقق من JWT والتاريخ والنوع ولا يحتوي على deny-list أو session version.

**Inference:** access token الذي حصل عليه العميل قبل logout يظل صالحاً حتى انتهاء مدته، وهي افتراضياً 15 دقيقة حسب `backend/app/core/config.py:32-36`. هذا قد يكون مقصوداً إذا كان تعريف logout في العقد هو إبطال refresh فقط؛ لكنه لا يساوي logout فوريّاً من ناحية access-token revocation.

**Recommendation:** وثّق صراحة أن logout يبطل refresh فقط، أو طبّق إبطالاً فورياً باستخدام session/version claim أو deny-list قصيرة العمر في Redis، مع موازنة الكلفة والأداء. أضف اختباراً يثبت السلوك المتعاقد عليه بعد logout بدلاً من الاكتفاء باختبار refresh rotation.

### F-03 — التسجيل لا يفرض سياسة طول أو جودة كلمة المرور ولا تحقق بريد إلكتروني

**Severity: Medium — Authentication/API contract**

**Fact:** نموذج التسجيل يقبل `username` و`password` و`email` كحقول `str` خام، والبريد اختياري وغير مقيد بـ `EmailStr`، ولا يوجد حد أدنى لطول كلمة المرور أو حد أقصى معلن في نموذج الطلب.

**Evidence:** `backend/app/api/v1/endpoints/auth.py:20-24` يعرّف `UserCreate` من دون `Field` أو قيود طول أو `EmailStr`. `backend/app/services/user_manager.py:17-24` يجزّئ كلمة المرور بـ Argon2 ويتحقق منها، لكنه لا يفرض سياسة قبول قبل التجزئة.

**Inference:** Argon2 يحمي كلمة مرور مقبولة بعد تخزينها، لكنه لا يمنع كلمات مرور فارغة أو ضعيفة. بذلك يبقى الحساب عرضة لتخمين كلمات المرور، ولا يقدم API عقداً واضحاً لرفض المدخلات الضعيفة.

**Recommendation:** أضف قيوداً صريحة في schema على الطول والفراغ، وتحققاً مناسباً للبريد إذا كان مطلوباً وظيفياً، مع rate limiting الحالي كطبقة مساعدة لا كبديل للسياسة. وثّق status code وشكل خطأ validation وأضف اختبارات للحدود الدنيا والقصوى.

### F-04 — readiness يعتمد على حجم Chroma ثابتاً ومشفراً في الكود

**Severity: Medium — Operational/API**

**Fact:** readiness يفحص قاعدة البيانات وRedis وChroma، لكنه يعتبر Chroma سليماً فقط إذا كان عدد عناصر collection مساوياً بالضبط لـ `6236`.

**Evidence:** `backend/app/api/v1/endpoints/health.py:37-41` ينشئ `PersistentClient` ثم يستدعي `collection.count()` ويرفض أي قيمة غير `6236`. `backend/app/api/v1/endpoints/health.py:49-67` يعيد 503 عندما يفشل أي فحص.

**Inference:** أي إعادة بناء صحيحة للفهارس بحجم مختلف، أو إضافة محتوى موثوق، أو اختلاف متعمد بين بيئة staging وproduction، سيجعل الخدمة غير جاهزة رغم أن Chroma متاح. الرقم الثابت لا يثبت سلامة المحتوى، بل يخلط اكتمال dataset الحالي بعقد readiness.

**Recommendation:** انقل expected fingerprint/version/count إلى artifact أو configuration مُدار بالإصدار، وافحص schema/version وبصمة dataset بدلاً من رقم وحيد. اجعل اختلاف staging المقصود واضحاً، واختبر حالات collection الناقصة والزائدة والتالفـة.

### F-05 — مخطط الترحيل يسمح بـ NULL في حقول يعتمد عليها منطق المصادقة

**Severity: Medium — Database/Auth**

**Fact:** migration الأول ينشئ `users.is_active` و`users.is_deleted` كحقول nullable، بينما lookup المستخدم لا يقبل إلا القيمة True صراحةً لكلا الحقلين.

**Evidence:** `backend/alembic/versions/86bf4aff3d18_initial_migration.py:57-71` يعرّف `is_active` و`is_deleted` بـ `nullable=True`. `backend/app/services/user_manager.py:48-56` يطبق `User.is_active.is_(True)` و`User.is_deleted.is_(False)`. نموذج ORM يضع defaults في `backend/app/db/models.py:38-42` لكنه لا يحول الأعمدة القائمة إلى NOT NULL.

**Inference:** أي صف legacy أو import يحمل NULL يصبح غير قابل لتسجيل الدخول أو التحقق، مع أن NULL ليس موثقاً كحالة حساب محذوف/غير نشط. هذا يخلق سلوكاً صامتاً ويصعّب reconciliation بين البيانات والمصادقة.

**Recommendation:** حدّد معنى NULL، ثم نفّذ data migration آمنة إلى قيم صريحة وأضف قيود NOT NULL وserver defaults إذا كان ذلك متوافقاً مع البيانات. افحص الحالة الفعلية للقاعدة في بيئة staging قبل جعل القيد إلزامياً، وأضف اختبار migration upgrade من بيانات قديمة.

### F-06 — اختبار المحور غير قابل لإعادة الإنتاج من بيئة المراجعة الحالية

**Severity: Medium — Verification**

**Fact:** المستودع يحتوي على اختبارات auth والعزل والصحة والتدوير، ويحتوي CI على خطوات لتثبيت dependencies وتشغيل Alembic وpytest. لكن الأدوات المطلوبة غير متاحة في بيئة التنفيذ الحالية.

**Evidence:** أمر `pytest -q backend/tests/test_api/test_auth.py backend/tests/test_api/test_refresh_rotation.py backend/tests/test_api/test_user_isolation.py backend/tests/test_api/test_health.py backend/tests/test_api/test_security_contract.py backend/tests/test_api/test_route_contract.py` أعاد `bash: pytest: command not found` وexit code 127. أمر `cd backend && alembic heads` أعاد `bash: alembic: command not found`. كما أعاد استيراد الإعدادات عبر Python `ModuleNotFoundError: No module named 'pydantic_settings'`. في المقابل، `.github/workflows/main.yml:37-41` يثبت الاعتمادات، و`:51-62` يشغل migrations، و`:77-89` يشغل pytest.

**Inference:** يمكن إثبات أن الاختبارات والترحيلات **مُعرّفة** في CI، لكن لا يمكن من هذه الجلسة إثبات أنها نجحت عند commit المحدد. لذلك فصلت في هذا التقرير بين Implemented وTested وVerified ولم أرفع الحكم إلى Production Ready.

**Recommendation:** شغّل pipeline نظيفاً أو بيئة reproducible مثبتة الإصدارات، واحفظ نتيجة job وcommit SHA ونسخة Python/PostgreSQL. أضف gate يمنع إعلان الجاهزية إذا فشلت migrations أو اختبارات auth/isolation/refresh rotation.

### F-07 — بعض سياسات قاعدة البيانات موثقة أو مساعدة تشغيلية وليست مدمجة في التطبيق

**Severity: Low/Medium — Database/Operations**

**Fact:** توجد سكربتات backup/restore فعلية، لكن سياسات RLS والأرشفة إلى S3 الواردة في وثائق مخطط قاعدة البيانات ليست موجودة في ملفات migration أو التطبيق بحسب البحث في الملفات غير Markdown.

**Evidence:** `docs/06-knowledge-base/مخطط-ER-قاعدة-البيانات.md:451-456` يعرض SQL لـ RLS، و`:400-419` يعرض دالة archiving وجدولة cron، لكن البحث في الملفات غير Markdown لم يجد `ENABLE ROW LEVEL`, `CREATE POLICY`, أو `archive_old`. في المقابل `deploy/backup.sh:19-34` ينفذ `pg_dump` واحتفاظاً محلياً، و`:28-30` ينسخ Chroma اختيارياً؛ و`deploy/restore.sh:25-30` ينفذ restore.

**Inference:** backup/restore **Implemented كأدوات تشغيلية**، لكن RLS والأرشفة الموصوفين لا يمكن اعتبارهما Integrated في schema الفعلية. الاعتماد على عزل التطبيق وحده يعني أن أي مسار SQL أو bug في query قد لا يملك طبقة RLS احتياطية.

**Recommendation:** إما تطبيق RLS والأرشفة عبر migrations/jobs قابلة للمراقبة، أو وسم الوثيقة بوضوح كتصميم مستقبلي لا كضابط قائم. اختبر backup/restore دورياً في بيئة معزولة، وتحقق من checksum ونتيجة restore ومن وجود Chroma backup عند الحاجة.

## نقاط القوة المثبتة

**المصادقة الأساسية منفذة جيداً نسبياً.** `backend/app/core/auth.py:14-49` يضيف `exp` و`type` وJTI للرموز، و`backend/app/core/config.py:32-60` يفرض في production وجود SECRET_KEY غير قصير وعدم استخدام كلمة مرور PostgreSQL الافتراضية. `backend/app/services/user_manager.py:10-14` يستخدم Argon2id بتكلفة production أعلى من الاختبار.

**تدوير refresh token مصمم مع تحديث مشروط ذري.** `backend/app/api/v1/endpoints/auth.py:85-104` يتحقق من النوع والـ JTI ثم يستدعي التدوير، و`backend/app/services/user_manager.py:74-84` ينفذ `UPDATE ... WHERE username AND refresh_jti == old_jti` ويشترط `rowcount == 1`. يوجد اختبار stale-token في `backend/tests/test_api/test_refresh_rotation.py:1-25`، لكن نتيجته لم تُشغّل محلياً.

**عزل التاريخ حسب المستخدم حاضر في الكود والاختبارات.** `backend/app/api/v1/endpoints/history.py:25-31` يمرر هوية المستخدم إلى الخدمة، و`backend/app/services/history_manager.py:70-78` يرشح بـ `Interaction.user_id == user_id`. كما أن اختبار العزل يتحقق من القراءة والتعديل بين مستخدمين مختلفين في `backend/tests/test_api/test_user_isolation.py:72-97`.

**هناك readiness حقيقي بدلاً من liveness شكلي فقط.** `backend/app/api/v1/endpoints/health.py:19-41` يفحص PostgreSQL وRedis وChroma، و`:49-67` يعيد 503 عند عدم الجاهزية. وCompose الإنتاجي يربط healthcheck الخاص بالـ backend بهذا المسار في `docker-compose.production.yml:90-95`.

**توجد حماية من proxy spoofing في rate limiting.** `backend/app/core/security.py:10-27` لا يثق بـ `X-Forwarded-For` إلا إذا كان peer ضمن `TRUSTED_PROXY_NETWORKS`، وCompose يمرر الشبكة الموثوقة ويقيد `--forwarded-allow-ips` في `docker-compose.production.yml:64-75`.

## مصفوفة الأولويات المقترحة

| الأولوية | الإجراء | معيار الإغلاق المقترح |
|---|---|---|
| P0 | دمج حفظ Interaction وDelayedResponse في معاملة واحدة | اختبار فشل منتصف العملية لا يترك صفاً نصف مكتمل، مع rollback مؤكد |
| P1 | تحديد عقد logout وإبطال access token أو توثيق الإبطال المؤجل | اختبار بعد logout يطابق العقد، مع قياس أثر Redis/session version |
| P1 | فرض password policy وschema validation | رفض كلمة مرور فارغة/ضعيفة واختبارات 422 موثقة |
| P1 | إزالة رقم Chroma الثابت من readiness | فحص fingerprint/version مُدار بالإصدار، مع اختبارات staging وproduction |
| P2 | معالجة NULL في حقول حالة المستخدم وترقية المخطط | data migration وNOT NULL أو سياسة NULL موثقة ومختبرة |
| P2 | إدماج RLS/الأرشفة أو تصحيح الوثائق | migration/job فعلي مع اختبار restore/retention أو وسمها كخطة مستقبلية |
| P2 | تشغيل CI وحفظ artifacts | نتيجة ناجحة مرتبطة بـ SHA نفسه وتشمل migrations وauth/isolation/performance |

## الحكم النهائي

**الحكم: يحتاج إصلاحات قبل إعلان Production Ready للمحور.** توجد قاعدة تنفيذ قوية ومتكاملة في المسار الاعتيادي، وليست الحالة مجرد وثائق أو stubs. لكن الاتساق الذري بين API وقاعدة البيانات غير مضمون في الردود المؤجلة، وإلغاء الجلسة ليس فورياً للـ access token، وسياسة كلمة المرور غير محددة، وreadiness مقيد برقم dataset ثابت. كما أن نتائج الاختبارات لم تُثبت من هذه البيئة بسبب غياب أدوات Python المطلوبة؛ لذلك يجب إبقاء الفرق بين **Implemented** و**Integrated** و**Tested** و**Verified** و**Production Ready** صريحاً عند اعتماد الإصدار.

## References

[1]: ../../../backend/app/main.py "FastAPI application and router registration"
[2]: ../../../backend/app/api/v1/endpoints/auth.py "Authentication endpoints and current-user dependencies"
[3]: ../../../backend/app/core/auth.py "JWT creation and verification"
[4]: ../../../backend/app/core/config.py "Runtime and production settings validation"
[5]: ../../../backend/app/services/user_manager.py "Argon2 password handling and refresh-JTI rotation"
[6]: ../../../backend/app/db/database.py "SQLAlchemy engine and session dependency"
[7]: ../../../backend/app/db/models.py "ORM models for users, interactions, delayed responses, and ratings"
[8]: ../../../backend/app/services/history_manager.py "Interaction persistence and user-scoped history queries"
[9]: ../../../backend/app/services/delayed_response_service.py "Delayed response persistence and delivery"
[10]: ../../../backend/app/api/v1/endpoints/health.py "Liveness and readiness checks"
[11]: ../../../backend/alembic/versions/86bf4aff3d18_initial_migration.py "Initial database migration"
[12]: ../../../backend/alembic/versions/6e29af63fcb2_add_message_source_tafsir_to_.py "Interaction schema update migration"
[13]: ../../../backend/tests/test_api/test_user_isolation.py "User-isolation API tests"
[14]: ../../../backend/tests/test_api/test_refresh_rotation.py "Refresh-token rotation tests"
[15]: ../../../.github/workflows/main.yml "CI installation, migration, and test commands"
[16]: ../../../docker-compose.production.yml "Production service integration and healthcheck"
[17]: ../../../deploy/backup.sh "PostgreSQL and Chroma backup script"
[18]: ../../../deploy/restore.sh "Database restore script"
[19]: ../../06-knowledge-base/مخطط-ER-قاعدة-البيانات.md "Documented database design and proposed policies"
[20]: ../../05-deployment/دليل-النشر.md "Deployment procedure and readiness checklist"

**تاريخ المراجعة:** 2026-09-23
**المراجع:** Principal Software Engineer review
**Commit:** `c915d0b03ff976c731e36cd98f6343bedd56f904`
