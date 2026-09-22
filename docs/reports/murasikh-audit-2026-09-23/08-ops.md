# تقرير تدقيق المحور 08: Reliability والأداء والأمن والاختبارات والنشر

**المستودع:** Murasikh  
**الالتزام المراجع:** `c915d0b03ff976c731e36cd98f6343bedd56f904` (`c915d0b`)  
**نطاق المراجعة:** الكود والوثائق الفعلية الموجودة في الالتزام، مع فحوص ساكنة ومحاولات تشغيل آمنة لا تغيّر الملفات.  
**تاريخ المراجعة:** 2026-09-23

## الحكم التنفيذي

الالتزام يضيف أساساً تشغيلياً مهماً: Compose إنتاجي بعزل شبكات، فحوص صحة، Redis موزع للـ rate limiting عند تهيئته، سكربتات نسخ واستعادة، اختبار دخان، واختبارات Backend وFlutter. لكن الأدلة المتاحة لا تثبت أن هذه العناصر متكاملة في بيئة قابلة للتشغيل أو مختبرة خارجياً. توجد كذلك بوابة حرجة محتملة في تهيئة إعدادات الإنتاج، وفجوة مؤكدة في TLS في Compose الخاص بـ staging، وفجوات في النسخ الاحتياطي والاستعادة والمراقبة.

**النتيجة:** المشروع **ليس Production Ready** لهذا المحور عند الالتزام `c915d0b`. التصنيف الأدق هو **Implemented جزئياً / Integrated غير مثبت / Tested جزئياً / Verified غير مثبت / Production Ready: لا**. وجود ملف أو اختبار أو تعليمات تشغيل لا يساوي دليلاً على تشغيل الخدمة فعلياً أو نجاح الاستعادة.

## مصطلحات الحكم وحالة كل طبقة

أستخدم الحالات الآتية بصورة منفصلة:

- **Implemented:** يوجد كود أو إعداد أو وثيقة تؤدي الوظيفة المقصودة.
- **Integrated:** رُبطت القطعة فعلياً ببقية النظام ومسار النشر، وليس فقط أُنشئت منفردة.
- **Tested:** يوجد اختبار منفذ بنتيجة قابلة للتتبع.
- **Verified:** يوجد دليل تشغيل أو فحص مستقل يثبت السلوك في البيئة المقصودة.
- **Production Ready:** اجتازت القطعة بوابات الاعتمادية والأمن والاستعادة والمراقبة والتشغيل، مع أدلة مناسبة.

| المجال | Implemented | Integrated | Tested | Verified | Production Ready |
|---|---|---|---|---|---|
| فحوص الصحة | نعم، `live` و`ready` | جزئياً في Compose الإنتاجي | اختبار عقدي موجود | لا يوجد تشغيل ناجح موثق | لا |
| النشر عبر Compose | نعم، ملفان مختلفان | جزئياً؛ staging غير مكتمل TLS | فحص YAML المطلوب في CI فقط | لم يُنفذ محلياً لغياب Docker | لا |
| TLS وواجهة Nginx | جزئياً | لا في staging؛ الشهادات غير مركبة | لا يوجد اختبار TLS فعلي | لا | لا |
| النسخ والاستعادة | سكربتات موجودة | جدولة cron موصى بها لا مدمجة | syntax فقط | لا توجد restore drill | لا |
| الأداء | اختبارات p95 اصطناعية محلية | لا تثبت أداء النشر أو مزود AI | موجودة نظرياً؛ لم تنفذ محلياً | لا توجد نتائج CI مرفقة | لا |
| الأمن | ضوابط JWT وCORS ورفع الملفات وrate limit | جزئياً | اختبارات عقود موجودة | لا يوجد فحص إنتاجي أو SAST/DAST شامل | لا |
| CI واختبارات التطبيق | Workflow واحد | Backend وFlutter مرتبطان في CI | لم يمكن تشغيله محلياً | لا توجد نتيجة CI لهذا الالتزام في المستودع | لا |

## النتائج الرئيسية مرتبة حسب الخطورة

### OPS-01 — حرج: تهيئة `Settings` قد تمنع إقلاع الإنتاج عند تمرير السر عبر البيئة

**النوع:** Reliability / Deployment / Security boundary  
**الشدّة:** Critical، مع كون النتيجة التشغيلية استدلالاً يحتاج تأكيداً في بيئة Python المطابقة.

**Fact:** في وضع الإنتاج يشترط الكود وجود `SECRET_KEY` داخل الوسائط الصريحة (`kwargs`) وليس فقط وجوده بعد تحميله من متغيرات البيئة.

**Evidence:** `backend/app/core/config.py:38-47` يستدعي `super().__init__(**kwargs)` ثم يرفض الحالة إذا كان `"SECRET_KEY" not in kwargs`. وفي الوقت نفسه يمرر Compose الإنتاجي السر المعتاد من البيئة في `docker-compose.production.yml:56-65` عبر `SECRET_KEY: ${SECRET_KEY:?SECRET_KEY is required}`، ثم ينشئ التطبيق الإعدادات عند الاستيراد في `backend/app/core/config.py:81`.

**Inference:** عند تشغيل الحاوية بالطريقة الموثقة، يكون `SECRET_KEY` محملاً من البيئة لا من `kwargs`؛ لذلك يُحتمل أن يرمي الإعداد `ValueError` قبل بدء Uvicorn، رغم أن Compose يمرر السر. لم يوجد في بيئة المراجعة Python/pytest أو تشغيل حاوية يثبت أو ينفي ذلك عملياً، لذا هذا استدلال ساكن عالي الخطورة وليس نتيجة تشغيل.

**Impact:** قد يفشل backend في الإقلاع في الإنتاج، فتفشل readiness وNginx وتصبح الخدمة غير متاحة. كما أن بوابة CI الحالية لا تختبر إنشاء `Settings` من متغيرات البيئة في وضع production.

**Recommendation:** غيّر التحقق ليختبر القيمة النهائية التي حمّلها `BaseSettings` مع تمييز القيم الافتراضية غير الآمنة، ثم أضف اختباراً subprocess أو اختباراً يعيد تحميل الوحدة مع `ENVIRONMENT=production` و`SECRET_KEY` و`POSTGRES_PASSWORD` في البيئة فقط. لا تعتبر الإصلاح منجزاً قبل نجاحه داخل صورة Docker نفسها.

### OPS-02 — عالي: staging يعلن HTTPS لكنه لا يركب الشهادات ولا يملك إعداد TLS فعالاً

**النوع:** Deployment / Security  
**الشدّة:** High.

**Fact:** ملف Nginx في staging يستمع على 443 مع `ssl`، لكن مساري الشهادة والمفتاح معلقان، كما أن volume الشهادات معلق في Compose.

**Evidence:** `deployment/staging/nginx.conf:11-17` يحتوي `listen 443 ssl`، بينما `ssl_certificate` و`ssl_certificate_key` مسبوقان بتعليق. و`deployment/staging/docker-compose.yml:37-40` يركب ملف الإعداد فقط ولا يركب مجلد SSL. الوثيقة نفسها تقول في `deployment/README.md:29-35` إن على المشغل تنفيذ Certbot ثم إزالة التعليق يدوياً.

**Inference:** ملف staging الملتزم به ليس نشر HTTPS مكتفياً ذاتياً، وقد يفشل Nginx في التحقق من الإعداد بسبب غياب الشهادة، أو يبقى المسار غير قابل للاستخدام حتى تدخل عملية خارجية غير ممثلة في المستودع.

**Impact:** فشل الإقلاع أو سقوط HTTPS أو تشغيل واجهة يفترض حماية TLS دون دليل. هذا يعرّض الأسرار والرموز أثناء النقل إذا استُخدم مسار بديل غير مضبوط.

**Recommendation:** اجعل الشهادة secret/volume مطلوباً ومتحققاً منه قبل التشغيل، أو افصل إصدار الشهادة عن Compose بمرحلة release موثقة. أضف اختبار `nginx -t` واختبار TLS فعلياً على staging، وسجل fingerprint للشهادة وتاريخ انتهاءها. لا تستخدم إعداد `listen 443 ssl` مع directives معلقة.

### OPS-03 — عالي: لا يوجد دليل Restore Drill أو نسخ خارجية/مشفرة، والنسخ لا يشمل Chroma

**النوع:** Reliability / Disaster Recovery / Security  
**الشدّة:** High.

**Fact:** توجد سكربتات `pg_dump` و`pg_restore`، لكن الوثائق تصف المراقبة بأنها Roadmap، ولا تسجل تجربة استعادة ناجحة.

**Evidence:** `deployment/scripts/backup.sh:21-28` يصدر PostgreSQL بصيغة custom ثم يضغطه بـ gzip ويطبق retention محلياً. لا يوجد تشفير أو رفع لمخزن خارجي أو تحقق checksum. السكربت يستخدم اسماً ثابتاً للحاوية `staging-postgres-1` في `deployment/scripts/backup.sh:11`. الاستعادة تكتب مباشرة إلى قاعدة البيانات وتطلب إدخالاً تفاعلياً في `deployment/scripts/restore.sh:22-35`. لا يوجد Backup لـ `chroma_data`، رغم أن Compose الإنتاجي يخزن Chroma في volume منفصل في `docker-compose.production.yml:145-148`. وتقر الوثيقة صراحة في `deployment/README.md:87-95` بأن المراقبة الحالية **Roadmap — غير منفذ في MVP**.

**Inference:** وجود السكربت لا يثبت قابلية الاستعادة أو اكتمال حالة المنتج؛ فقدان Chroma أو اختلاف اسم المشروع/الحاوية قد يجعل الاسترجاع غير كامل أو يفشل. كما أن النسخة المحلية غير المشفرة لا تحقق هدف حماية بيانات النسخ.

**Impact:** عدم القدرة على تحديد RPO/RTO، أو استرجاع قاعدة البيانات دون فهرس البحث، أو فقد النسخة مع المضيف، أو تسرب بيانات النسخ. التشغيل الآلي عبر cron قد ينجح شكلياً دون تنبيه عند الفشل.

**Recommendation:** عرّف RPO/RTO وامتلك النسخ في مخزن خارجي مشفر مع lifecycle وchecksum. وثّق هل Chroma قابل لإعادة البناء من dataset أم يجب نسخه، ونفذ restore drill دورياً على بيئة معزولة مع قياس زمن الاستعادة والتحقق من عدد السجلات/الآيات. أضف `flock`، خروجاً واضحاً عند فشل `docker exec` أو الكتابة، وتنبيهاً عند الفشل أو امتلاء القرص.

### OPS-04 — عالي: سكربت Smoke Test غير متسق مع عقد API ولا يثبت المسار المعلن

**النوع:** Testing / Deployment  
**الشدّة:** High.

**Fact:** الاختبار يطلب حالات HTTP ثابتة لا تغطي كل الحالات التي يذكرها تعليقه، ويستخدم payload مختلفاً عن عقد login الفعلي، ولا يختبر recommendation رغم وصفه السابق.

**Evidence:** `deployment/scripts/smoke_test.sh:32-39` يطلب 200 فقط من `/health/ready`، مع أن endpoint يعيد 503 عند فشل أي dependency وفق `backend/app/api/v1/endpoints/health.py:49-67`. في `deployment/scripts/smoke_test.sh:44-54` يرسل login JSON بحقول `email/password` ويقبل في التعليق 401/400/422، لكن `print_result` يقارن بالرقم 401 فقط في `:48`، بينما الاختبار الفعلي يرسل form data بحقل `username/password` في `backend/tests/test_api/test_security_contract.py:83-88`. كما أن السكربت لا يحتوي طلب recommendation، بالرغم من أن `scripts/smoke_test.sh:26-33` في النسخة الجذرية القديمة يصف ذلك المسار.

**Inference:** يمكن أن يفشل smoke test بسبب عقد خاطئ حتى عندما تكون الخدمة سليمة، أو يمر بفحص health سطحي بينما لا تكون dependencies جاهزة. لا يمكن اعتباره E2E لمسارات المنتج.

**Impact:** false negatives تؤخر الإصدارات، وfalse confidence قد يمرر نشرًا لا يعمل فيه التوصية أو المصادقة كما يتوقع العميل.

**Recommendation:** اربط smoke test بعقد OpenAPI/نماذج endpoint الحالية. اسمح صراحة بمجموعة الحالات المتوقعة بدلاً من مقارنة رقم واحد، واختبر التسجيل ثم login ثم token-authenticated recommendation/history ثم health عبر Nginx/TLS. افصل readiness dependency failure كحالة متوقعة ومقيسة، لا كفشل غامض.

### OPS-05 — متوسط/عالٍ: فحوص الأداء تقيس وظائف محلية اصطناعية لا مسار الإنتاج

**النوع:** Performance / Testing  
**الشدّة:** Medium-High.

**Fact:** توجد اختبارات p95 لـ reranking وsemantic orchestration وRAG fallback، لكنها تعمل على fake embedding وبيانات صغيرة وتضع ميزانية 20ms.

**Evidence:** `backend/tests/performance/test_search_rag_performance.py:64-76` و`:79-95` تنفذان 120 عينة على `fake_embedding_service()`، و`:100-116` و`:119-140` تختبران RAG محلياً أو fallback مع `gemini` معطل. الوثيقة `backend/tests/performance/README.md` تعرض أمراً منفصلاً للاختبارات وتذكر تشغيل CI، لكن لا توجد نتيجة تشغيل أو baseline محفوظة في المستودع. بحث الملفات لم يجد `coverage.xml` أو `.coverage` أو تقارير اختبار أو artifact release.

**Inference:** هذه اختبارات regression micro-performance مفيدة، لكنها لا تثبت p95/p99 لتطبيق كامل مع PostgreSQL وRedis وChroma وGemini أو تحت حمل متزامن.

**Impact:** قد يمر benchmark المحلي مع تدهور latency أو error rate أو استهلاك ذاكرة في النشر الفعلي. ميزانية 20ms ليست ميزانية API كاملة ولا موثقة كـ SLO.

**Recommendation:** عرّف SLOs للـ endpoint مع p50/p95/p99 وerror rate وCPU/ذاكرة. نفذ load/stress على صورة staging مرتبطة بالالتزام ونسخة البيانات والنموذج، مع عزل استدعاء Gemini وقياس timeouts وfallbacks. احتفظ بالنتائج كـ CI artifacts مع baseline ومقارنة تمنع regression.

### OPS-06 — متوسط: CI يضم بوابات جيدة لكن لا توجد نتيجة موثقة ولا build release فعلي

**النوع:** Testing / Release  
**الشدّة:** Medium-High.

**Fact:** Workflow واحد موجود ويشغل Ruff وpip-audit وAlembic واختبارات Backend والأداء واختبارات Flutter.

**Evidence:** `.github/workflows/main.yml:42-102` يضم lint وdependency audit وmigration وpytest وperformance، و`:104-124` يضم Flutter analyze/test. لكنه لا يبني Android APK/AAB أو iOS archive، ولا ينفذ `docker compose up` أو `nginx -t` أو restore drill. `deployment/README.md:98-113` يبقي build والتوقيع واختبار الجهاز وTestFlight في قائمة unchecked. ولا توجد نتائج CI أو artifacts في الالتزام؛ `git status --short --branch` كان نظيفاً، ولم توجد ملفات coverage أو APK/AAB.

**Inference:** وجود workflow يثبت تعريف البوابات فقط، وليس نجاحها لهذا الالتزام أو صلاحية artifact قابل للتوزيع.

**Impact:** احتمال اكتشاف فشل Flutter release أو التوقيع أو الحاويات بعد الدمج أو عند النشر، مع غياب traceability للـ artifact.

**Recommendation:** ثبّت إصدارات Flutter/Dart والصور، أضف build Android release واختبار transport policy وCompose validation داخل CI، وارفع artifacts موقعة عبر secret management. اربط كل release بالـ commit ونتيجة smoke وSBOM/scan، وأضف بوابة تمنع الوسم قبل نجاحها.

### OPS-07 — متوسط: النشر الإنتاجي مربوط بالإقلاع ويعيد seed/migration دون release job مستقل

**النوع:** Reliability / Deployment  
**الشدّة:** Medium.

**Fact:** أمر backend في Compose الإنتاجي ينفذ تحقق Chroma ثم migration ثم يشغل Uvicorn عند كل بدء للحاوية.

**Evidence:** `docker-compose.production.yml:71-75` يضع `python scripts/seed_quran.py --verify && alembic upgrade head && uvicorn ...` في `command`. وفي المقابل توجد توصية لاحقة في خطة المشروع لفصل migrations عن startup، كما أن المستودع لا يحتوي release job مستقلاً في `.github/workflows/main.yml`.

**Inference:** restart أو scale-out يربط availability بنجاح migration/verification، وقد يسبب سباقاً بين نسخ متعددة أو يجعل rollback غير واضح. التحقق من Chroma يعتمد على volume مشترك ومرحلة init، لكنه ليس migration/rollback contract كاملاً.

**Impact:** إطالة زمن الإقلاع، تعطل الخدمة بسبب seed/DB عابر، أو صعوبة التحكم في schema أثناء نشر متعدد النسخ.

**Recommendation:** انقل migrations إلى release job أحادي القفل قبل تبديل traffic، وعرّف expand/contract وrollback. اجعل startup يقوم بفحوص readiness فقط، وسجل version/schema/data fingerprint في release evidence.

### OPS-08 — متوسط: سطح الهجوم التشغيلي والـ supply chain غير محكومين بالكامل

**النوع:** Security / Reliability  
**الشدّة:** Medium.

**Fact:** بعض الضوابط الأمنية موجودة، لكن صور Compose وبعض حزم Python غير مثبتة بدقة، وDockerfile لا يحدد مستخدماً غير root.

**Evidence:** `docker-compose.production.yml:2` يستخدم `nginx:alpine`، و`:102` `postgres:15-alpine`، و`:125` `redis:7-alpine` دون digest. `backend/requirements.txt:6-18` يترك FastAPI وUvicorn وSQLAlchemy وRedis و`sentence-transformers` وغيرها دون pins، مع تثبيت Chroma فقط في `:5`. `backend/Dockerfile:1-27` يبني من `python:3.12-slim` ويثبت `build-essential` ثم لا يحدد `USER` غير root. توجد عوازل شبكة و`read_only` لـ Nginx في `docker-compose.production.yml:13-23` و`:150-160`، وهي نقطة إيجابية لكنها لا تعالج بقية السلسلة.

**Inference:** إعادة البناء غير حتمية، والتحديث غير المقصود قد يغير السلوك أو الثغرات، واختراق backend يعمل بامتيازات أعلى من اللازم.

**Impact:** صعوبة التحقيق وإعادة الإنتاج، وتوسيع أثر compromise، واحتمال اختلاف صورة الإنتاج عن الصورة التي اختُبرت.

**Recommendation:** ثبّت صوراً بـ digest وحزم runtime عبر lock/constraints مع تحديثات دورية آلية وSBOM وscan. استخدم multi-stage build ومستخدماً غير root وقلل حزم البناء من الصورة النهائية. اختبر أن التطبيق يستطيع الكتابة فقط إلى المسارات المطلوبة.

## نقاط إيجابية مثبتة، مع حدودها

1. **فحوص readiness حقيقية نسبياً:** `backend/app/api/v1/endpoints/health.py:49-67` يفحص PostgreSQL وRedis وChroma بالتوازي ويعيد 503 عند الفشل. هذا Implemented جيد، لكنه لا يثبت التشغيل الفعلي أو وجود monitoring.
2. **عزل الشبكات والمنافذ:** Compose الإنتاجي لا ينشر منافذ DB/Redis، ويستخدم شبكات `internal` في `docker-compose.production.yml:150-160`. هذا يقلل السطح المكشوف، لكنه لا يغني عن فحص TLS وامتيازات الصور.
3. **Rate limiting موزع عند ضبط Redis:** `backend/app/core/security.py:30-34` يستخدم Redis storage إذا كان `REDIS_URL` موجوداً، مع تقييد forwarded IP إلى شبكات موثوقة في `:10-27`. يلزم اختباراً تشغيلياً خلف Nginx للتأكد من أن peer الفعلي يقع ضمن الشبكة الصحيحة.
4. **اختبارات سلبية للأمن:** `backend/tests/test_api/test_security_contract.py:27-63` و`:91-139` تغطي JWT غير صالح، CORS، أنواع/أحجام الصوت، السر الخاطئ، وقيم الإنتاج. هذه أدلة اختبار كود، وليست دليلاً على نشر أو DAST.
5. **Fallback وtimeout لمزود AI:** `backend/app/services/ai/rag_engine.py` يهيئ عميل Gemini بمهلة 5000ms في المواضع التي تنشئ العميل، وتوجد مسارات fallback في القسم المقروء من الخدمة. لا توجد، مع ذلك، نتيجة load أو سياسة retry/circuit breaker موثقة للمزود الخارجي.

## سجل الاختبارات والفحوص المنفذة في هذه المراجعة

| الأمر | النتيجة القابلة للتتبع | الدلالة |
|---|---|---|
| `git rev-parse --verify c915d0b^{commit}` | `c915d0b03ff976c731e36cd98f6343bedd56f904` | الالتزام المطلوب موجود ومراجعته ثابتة |
| `git status --short --branch` | `## main...origin/main` بلا تغييرات | لم أعدل المستودع؛ التقرير خارج المستودع في المسار المطلوب |
| `bash -n deployment/scripts/*.sh scripts/smoke_test.sh` | `shell_exit=0` | الصياغة النحوية للـ shell سليمة، ولا يثبت السلوك التشغيلي |
| `docker compose ... config --quiet` | `bash: docker: command not found`، exit 127 | لم يمكن التحقق من Compose أو بناء الحاويات في sandbox |
| `python -m pytest -m 'not performance' -q` من `backend` | `/usr/bin/python: No module named pytest`، exit 1 | لم تنفذ اختبارات Backend؛ لا يجوز وسمها Tested محلياً |
| `python -m pytest tests/performance -m performance -q` | `/usr/bin/python: No module named pytest`، exit 1 | لم تنفذ اختبارات الأداء؛ لا توجد نتيجة p95 فعلية |
| إحصاء ساكن | 26 ملف اختبار Backend و80 دالة اختبار تقريباً؛ 9 ملفات Flutter و30 استدعاء test تقريباً؛ Workflow واحد | حجم الاختبارات موجود، لكن العدد لا يثبت نجاحها أو التغطية |
| البحث عن artifacts | لا توجد `coverage.xml` أو `.coverage` أو تقارير JUnit أو APK/AAB متتبعة | لا توجد أدلة تسليم/تغطية محفوظة في الالتزام |

## فصل الأدلة عن الاستنتاجات

**Facts:** الملفات والسطور المذكورة أعلاه موجودة في الالتزام، و`bash -n` نجح، بينما Docker وpytest غير متاحين في بيئة المراجعة. كما أن وثيقة النشر تصف المراقبة بأنها Roadmap وتترك خطوات الإصدار unchecked.

**Evidence:** كل حكم تشغيلي رئيسي مرتبط بمسار ورقم سطر، أو بأمر ونتيجة مباشرة في جدول سجل الاختبارات. لم أعتبر تعليقات مثل `# Security Headers` أو وجود سكربت backup دليلاً على نجاح التشغيل.

**Inference:** أحكام مثل احتمال فشل Settings في الإنتاج، وعدم اكتمال HTTPS، وعدم كفاية اختبارات الأداء، مستخلصة من تركيب الكود والإعدادات. وُسمت صراحة كاستدلال عندما لم ينفذ runtime داخل هذه البيئة.

**Recommendation:** التوصيات تركز على إغلاق الدليل الناقص: اختبار الصورة الفعلية، TLS فعلي، restore drill، SLO/load evidence، release artifacts، وsecret/image/dependency controls. لا تتطلب هذه التوصيات تغييراً نفذته في هذا التدقيق.

## الخلاصة وقرار الإصدار

لا أوصي بوسم `c915d0b` كإصدار إنتاجي لهذا المحور. قبل الإطلاق، يجب على الأقل حل أو إثبات OPS-01، جعل TLS في staging قابلاً للتشغيل والتحقق، تنفيذ restore drill مشفر وموثق يشمل حالة البحث، إصلاح smoke test ليطابق العقد، وتشغيل CI/Compose/release فعلياً مع نتائج محفوظة. بعد ذلك يلزم load test على staging ومراقبة وتنبيه وSLO واضح؛ عندها فقط يمكن الانتقال من **Implemented** إلى **Integrated/Verified** ثم تقييم **Production Ready**.

## المراجع الداخلية

[1]: ../../../docker-compose.production.yml "Compose الإنتاجي"
[2]: ../../../deployment/staging/docker-compose.yml "Compose staging"
[3]: ../../../deployment/staging/nginx.conf "إعداد Nginx في staging"
[4]: ../../../deployment/README.md "وثيقة النشر والتشغيل"
[5]: ../../../deployment/scripts/backup.sh "سكربت النسخ الاحتياطي"
[6]: ../../../deployment/scripts/restore.sh "سكربت الاستعادة"
[7]: ../../../deployment/scripts/smoke_test.sh "اختبار الدخان"
[8]: ../../../backend/app/core/config.py "إعدادات التطبيق"
[9]: ../../../backend/app/api/v1/endpoints/health.py "مسارات الصحة والجاهزية"
[10]: ../../../.github/workflows/main.yml "Workflow الاختبارات"
[11]: ../../../backend/tests/performance/test_search_rag_performance.py "اختبارات أداء البحث وRAG"
[12]: ../../../backend/tests/test_api/test_security_contract.py "اختبارات عقد الأمن"
[13]: ../../../backend/Dockerfile "صورة Backend"
[14]: ../../../backend/requirements.txt "اعتماديات Backend"
[15]: ../../../backend/app/core/security.py "Rate limiting والثقة في proxy"
[16]: ../../../backend/app/services/ai/rag_engine.py "محرك RAG ومزود AI"

> **حدود المراجعة:** لم تُثبت نتائج تشغيل Compose أو pytest في هذه البيئة لأن `docker` و`pytest` غير متاحين. لم يتم تعديل أي ملف في المستودع ولم ينفذ commit.
