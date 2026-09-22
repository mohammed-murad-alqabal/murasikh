# تقرير التدقيق النهائي — Murasikh

**نقطة المراجعة:** `c915d0b03ff976c731e36cd98f6343bedd56f904`  
**تاريخ المراجعة:** 2026-09-23  
**النطاق:** تقارير المحاور الثمانية من `01-docs.md` إلى `08-ops.md`، مع التمييز بين **Fact** و**Evidence** و**Inference** و**Recommendation**، وبين **Implemented** و**Integrated** و**Tested** و**Verified** و**Production Ready**.

> **قرار التدقيق المختصر:** Murasikh هو **MVP فعلي قابل للتطوير وstaging المشروط**، وليس إصداراً إنتاجياً أو تجارياً مثبت الجاهزية. توجد نواة حقيقية للتوصية القرآنية النصية، وواجهات Backend وFlutter، وتخزين للتاريخ، وفحوص بنيوية للقرآن، وبعض ضوابط الأمن والتشغيل. لكن الأدلة لا تثبت الجاهزية التشغيلية أو جودة الفهم العربي أو سلامة provenance الشرعي أو عزل البيانات المحلية أو الاستعادة أو إصداراً موقّعاً قابلاً للتتبع. لا يوصي هذا التقرير بـRewrite أو Microservices؛ الأولوية هي إغلاق فجوات الدليل والعقود والضوابط داخل البنية الحالية.

## Executive Summary

**Fact:** المستودع عند commit محدد ونظيف، ويحتوي على تنفيذ ملموس لمسار النص: `POST /api/v1/analyze`، واسترجاع Chroma مفلتر إلى `type=verse`، وصياغة مع fallback، وحفظ تفاعل للمستخدم المصادق عليه. توجد كذلك واجهات Home والصوت والتاريخ، واختبارات مصدرية وWorkflow CI وسكربتات نشر ونسخ واستعادة. [1] [2] [3]

**Evidence:** `docs/حالة-المنتج-2026-09-22.md:11-24` يصنف النشر والمراقبة والاستعادة والمنصات والخصوصية بأنها جزئية أو غير مثبتة، و`docs/reports/P3_acceptance_report.md:3-26` يبقي بوابات staging وbackup/restore والمراقبة والأجهزة والإصدار غير مغلقة. تعذر تشغيل `pytest` و`alembic` وFlutter وDocker في بيئة المراجعة، بينما نجح `compileall` وفحص shell syntax فقط. [1] [2] [8]

**Inference:** المنتج ليس مجرد وثائق أو stubs، لكنه أيضاً ليس نظاماً قابلاً للتدقيق كإصدار إنتاجي. الخطر الأكبر هو أن طبقة الوثائق والعنوان التسويقي للـcommit يبدوان أوسع من الأدلة التشغيلية. توجد فجوات حرجة تمس الخصوصية، وجاهزية الإقلاع، وسلامة المحتوى، والتعافي، ويجب إغلاقها قبل إطلاق عام.

**Recommendation:** اعتمد مسار إطلاق مرحلياً محافظاً: ثبّت مصفوفة حالة واحدة، صحّح العقود والذاكرة المحلية، أقفل provenance القرآني، أبقِ الحديث خارج عقد التوصية أو افصله بوضوح، شغّل CI وCompose وFlutter على نفس SHA، ثم نفذ staging smoke وrestore drill وقياس حمل وأدلة artifact موقّع. لا تغيّر أسلوب النشر إلى Microservices ولا تعِد كتابة النظام ما لم تظهر نتائج قياس تثبت أن البنية الحالية هي سبب عجز محدد.

### مصفوفة Capability | Vision | Requirement | Design | Implementation | Verified | Quality | Gap

| Capability | Vision | Requirement | Design | Implementation | Verified | Quality | Gap |
|---|---|---|---|---|---|---|---|
| التوصية القرآنية النصية | رفيق يفهم الرسالة ويقترح آية مناسبة | عقد `/api/v1/analyze`، نص canonical، أثر قابل للتتبع | Agent + RAG + صياغة Gemini/fallback | منفذ ومتكامل جزئياً؛ `recommend.py:26-32,158-192` | ساكن فقط؛ `pytest` غير متاح | **Medium**: المسار موجود، الجودة العربية غير مقاسة | **High — جودة/محتوى:** لا Recall/MRR ولا exact hash للنص |
| فهم المستخدم والfallback | فهم النفي واللهجات والغموض | dataset عربي، calibration، سياسة رفض | Gemini ثم قوائم كلمات heuristic | منفذ كfallback؛ `conversational_agent.py:109-177` | غير مثبت | **Low–Medium**: ثقة ثابتة بلا معايرة | **High — AI quality:** «ضيق» قد يصنف إرهاقاً بثقة 0.4 |
| المحادثة متعددة الأدوار | سياق جلسة متصل للضيف والمستخدم | `conversation_id` أو transcript محدود وTTL | آخر 5 تفاعلات للمستخدم المصادق | جزئي؛ `recommend.py:55-85` ولا يرسل Flutter transcript | غير مثبت | **Low–Medium**: ذاكرة مستخدم لا جلسة | **High — Contract:** الضيف وoffline لا يملكان السياق نفسه |
| History وMemory | تاريخ قابل للحذف والعزل والمزامنة | namespace، clear semantics، IDs موحدة | PostgreSQL + Hive chat/history | منفذ لكن مخزنا Hive عالميان | غير مثبت؛ Flutter غير متاح | **Low** للخصوصية المحلية | **Critical — Privacy:** احتمال ظهور حساب A لحساب B |
| Audio | فهم محتوى الصوت والانفعال | STT عربي أو تسمية tone فقط، موافقة وقياس | ميزات نبرة وقواعد عتبات | tone classification موصول بالتوصية؛ `audio_analyzer.py:54-67` | لا جهاز/ملفات حقيقية مثبتة | **Medium**: رفع مضبوط، فهم دلالي غائب | **High — Capability:** لا STT ولا محتوى منطوق داخل RAG |
| Image/Face | فهم وسائط متعددة | عقد modality وmodel/confidence وسياسة خصوصية | FaceDetector وخصائص وجه محلية | Face heuristic؛ لا Image pipeline مستقل | غير مثبت | **Low–Medium**: `faces.first` وعتبات ثابتة | **High — Scope/Privacy:** لا فهم صورة عام ولا معايرة |
| القرآن وprovenance | محتوى قرآني موثوق ومراجع | manifest، مصدر وإصدار وhash ومراجعة | `quran.json` + `seed_quran` + Chroma | 6,236 آية وفحوص بنيوية؛ provenance ناقص | بنيوي فقط | **Medium** بنيوياً، **Low** شرعياً | **High — Content governance:** `source` مولد لا مصدر قابل للتدقيق |
| الحديث | محتوى حديثي بدرجات قابلة للتفسير | grades[]، provenance، سياسة تعارض | JSON + model + `seed_hadiths` | أصول وسكربت فقط، غير داخل العقد | غير مثبت | **Low** | **Critical — Religious data:** درجات مفقودة/متعددة وتسقط عند seed |
| Offline | توصية محلية مكافئة للاتصال | محرك محلي أو وعد cached واضح | cache + latest/fallback | منفذ كـfallback، لا تحليل عام؛ `api_service.dart:219-232` | اختبارات مصدرية فقط | **Medium** كـgraceful degradation | **Medium — Product promise:** النص يوحي بتوليد محلي |
| Reliability/Deployment | خدمة قابلة للإطلاق والاستعادة | TLS، RPO/RTO، monitoring، smoke وartifact | Compose + health + scripts | الأدوات موجودة، التشغيل غير مثبت | لا Docker/restore/staging evidence | **Low–Medium** | **Critical — Release:** لا restore drill ولا signed artifact |
| Security/Privacy | عزل، حذف، حماية نقل وبيانات | session policy، TLS فعلي، retention، support | JWT/Argon2/Hive/Compose | ضوابط جزئية؛ staging TLS معلق | لا DAST/device proof | **Medium** في Backend، منخفض محلياً | **Critical/High — Privacy/Security:** local namespace وlegal gaps |
| Performance | تجربة سريعة قابلة للقياس | SLO p50/p95/p99 وحمل فعلي | micro-benchmarks محلية | fake embedding و20ms budget | لا نتائج CI/load | **Low** كدليل إنتاج | **High — Verification:** لا أداء end-to-end |
| Testing/Release | كل تغيير قابل لإعادة التشغيل | CI مرتبط بـSHA وبناء artifact | Workflow يعرّف lint/migrations/tests | Configured، لا نتيجة محفوظة | غير مثبت | **Medium** | **High — Traceability:** لا APK/AAB/IPA أو تقارير CI متتبعة |

## Product Goal

**Fact:** الهدف المعلن هو مساعد عربي/قرآني يلتقط حالة المستخدم من النص وبعض الإشارات، ثم يقدم آية وتوصية دافئة مع تاريخ وfeedback وHome سياقي. التنفيذ الفعلي يدعم جزءاً من ذلك: مسار نصي، RAG قرآني، واجهة محادثة، صوت بنبرة، ووجه بخصائص محدودة. [3] [5] [6]

**Evidence:** `backend/app/api/v1/endpoints/recommend.py:26-32,55-85,158-192` يثبت حدود طلب النص وسياق آخر خمسة تفاعلات وفلتر `type=verse`. `frontend/lib/main.dart:64-89` و`frontend/lib/core/navigation/main_shell.dart:22-68` يثبتان الرحلة الأساسية. [3] [7]

**Inference:** الهدف القابل للدفاع حالياً ليس «فهم متعدد الوسائط» أو «ذاكرة جلسة كاملة»، بل **توصية قرآنية نصية مع سياق قصير للمستخدم المصادق، ودعم صوتي/وجهي تجريبي، وتدهور offline قائم على cache**.

**Recommendation:** ثبّت هذا النطاق في العقد ودليل المستخدم. لا توسّع الهدف إلى حديث أو Image Understanding أو STT قبل أن تملك عقداً مستقلاً، provenance، dataset تقييم، وقرار إطلاق منفصلاً.

## Current Reality

المشروع يملك نواة MVP حقيقية. Backend يسجل routers للمصادقة والتوصية والتاريخ والصوت وHome، ويدعم JWT وArgon2 وتدوير refresh JTI وrate limiting عند تهيئة Redis. توجد قاعدة بيانات وتدفق Alembic وCompose وhealth endpoints. هذه نقاط قوة **Implemented** وليست دليلاً تلقائياً على **Verified**. [2] [8]

القرآن المحلي قابل للعد والتحقق البنيوي: 114 سورة و6,236 آية ومعرفات فريدة ونصوص غير فارغة. لكن provenance لا يحمل URL أو version أو license أو hash مصدر مستقل. الحديث موجود كملفات ونموذج وسكربت، لكنه خارج عقد التوصية ومسار الإقلاع. [4]

في الواجهة توجد رحلة Home والرفيق والتاريخ والإعدادات، لكن Flutter وDart غير متاحين في المراجعة. العمل دون اتصال هو cache أو fallback ثابت، وليس تحليلاً محلياً مكافئاً. التخزين المحلي للمحادثة والتاريخ غير مربوط بهوية الحساب، كما أن مسح شاشة لا يساوي مسح الذاكرة الخلفية. [5] [7]

تشغيلياً، توجد ملفات Compose وNginx وbackup/restore وsmoke وCI. لا توجد نتيجة staging خارجية، ولا restore drill، ولا monitoring/alerts/SLO، ولا artifact Android/iOS موقّع متتبع. `docker-compose.production.yml` يربط migration وChroma verification بإقلاع Backend، وقد يكون تحقق `SECRET_KEY` من kwargs فقط عائق إقلاع؛ هذا الأخير **Inference يحتاج runtime confirmation** وليس نتيجة تشغيل. [8]

## Vision vs Reality

الرؤية تفترض تجربة رفيق يفهم الرسالة والسياق والوسائط ويعود بتوصية موثوقة قابلة للحذف والعمل offline. الواقع يحقق مساراً نصياً متماسكاً جزئياً، لكنه لا يملك contract جلسة، ولا يقيس دقة fallback العربي، ولا يثبت سلامة النص القرآني بمقارنة canonical، ولا يقدم STT أو Image pipeline.

الفجوة ليست في غياب كل الكود. الفجوة في الانتقال من **وجود وظيفة** إلى **وظيفة موثقة ومقاسة ومتكاملة وقابلة للتحقق**. كما أن الوثائق تعرض أحياناً «مكتمل/100%» بينما تصف مصفوفة الحالة الرسمية نفس المجالات بأنها غير مثبتة. `docs/README.md:68-77,81-95,137-149` مقابل `docs/حالة-المنتج-2026-09-22.md:11-24` هو مثال مباشر على تعارض مصدر الحقيقة. [1]

## Core User Journey Audit

المسار الأساسي القابل للإثبات هو: بدء التطبيق وتهيئة Hive والخدمات، دخول MainShell، جلب Home وسياقها، فتح ChatScreen، إرسال النص إلى `/analyze`، عرض التوصية وحفظها، ثم عرض history. هذا المسار موجود في `frontend/lib/main.dart:64-89` و`frontend/lib/core/navigation/main_shell.dart:22-68` و`frontend/lib/features/home/presentation/screens/home_screen.dart:35-52,113-153`.

**Fact:** عند الاتصال يعمل العميل والخادم بعقد حديث، ويُحفظ التفاعل للمستخدم المصادق عليه. **Evidence:** `frontend/lib/services/api_service.dart:179-205` و`backend/app/services/history_manager.py:16-43`. **Inference:** المسار الأساسي صالح كـMVP، لكنه لا يثبت سلوك جهاز فعلي أو نجاح كل dependencies.

عند offline، يختار العميل cache أو آخر توصية أو fallback. **Evidence:** `frontend/lib/services/api_service.dart:114-134,219-232` و`offline_service.dart:60-79,121-129`. **Gap:** المستخدم قد يظن أن الرسالة الحالية حُللت محلياً وهي لم تُحلل.

عند مسح ChatScreen، يمسح العميل box المحلي فقط بينما يبقى آخر خمسة تفاعلات في الخادم. وعند مسح HistoryScreen، يمسح local history دون chat box. **Evidence:** `chat_screen.dart:188-214` و`history_service.dart:202-217` و`chat_dependencies.dart:20`. هذا يخرق دلالة الحذف المتوقعة.

## Architecture Assessment

البنية الحالية monolithic modular نسبياً: FastAPI، PostgreSQL، Redis، Chroma، Flutter، وGemini/بدائل محلية. توجد حدود خدمات واضحة بما يكفي لمعالجة الفجوات دون Rewrite. لا يوجد دليل أن تقسيمها إلى Microservices سيحل المخاطر الحالية؛ بل قد يزيد تعقيد الاتساق والمراقبة والاستعادة.

**Fact:** التوصية تعتمد على حفظ Interaction ثم حفظ DelayedResponse في معاملتين منفصلتين. **Evidence:** `backend/app/api/v1/endpoints/recommend.py:241-269`، `history_manager.py:28-42`، `delayed_response_service.py:30-42`. **Inference:** يمكن أن تبقى حالة نصف مكتملة. **Recommendation:** orchestration transaction واحدة مع `flush` وrollback واختبار فشل منتصف العملية.

**Fact:** Compose يشغل `seed_quran --verify` وAlembic ثم Uvicorn عند بدء Backend. **Evidence:** `docker-compose.production.yml:71-75`. **Inference:** restart/scale-out مرتبطان بنجاح migration وقد يتعقد rollback. **Recommendation:** release job أحادي القفل، مع إبقاء startup لفحوص readiness بعد إثبات الاستقرار.

## AI / User Understanding Assessment

المسار الأساسي هو Agent يفهم `action` و`emotion` ثم RAG وصياغة. عند فشل Gemini، fallback يعتمد على substrings ثابتة. **Evidence:** `backend/app/services/ai/conversational_agent.py:52-107,109-177`. لا توجد مجموعة تقييم عربية للنفي واللهجات والتعدد والغموض. **Inference:** أرقام confidence ليست احتمالات معايرة، وقد تكون النتيجة غير ملائمة عند انقطاع المزود.

مسار `action=ask` يعيد `tier=minimal` وconfidence الفعلية، لكنه يحفظ Interaction بالdefaults `confidence=1.0` و`tier=moderate`. **Evidence:** `recommend.py:87-117` و`history_manager.py:16-39`. هذه فجوة عقدية P1 لأنها تلوث التاريخ والتحليلات والسياق اللاحق.

**Recommendation:** أنشئ dataset عربي versioned ومراجعاً، قس macro-F1 وconfusion وcalibration، أضف سياسة رفض للغموض، وصحح تمرير حقول ask. لا تعتبر confidence الحالية دليلاً إحصائياً.

## Conversation / Investigation Assessment

توجد وظيفة استقصاء عند `ask`، لكن «المحادثة» ليست جلسة حقيقية. الخادم يمرر آخر خمسة تفاعلات للمستخدم المصادق عليه فقط. Flutter يرسل الرسالة الحالية و`user_context` ولا يرسل transcript المحلي. **Evidence:** `backend/app/api/v1/endpoints/recommend.py:55-85` و`frontend/lib/features/chat/presentation/screens/chat_screen.dart:256-281` و`api_service.dart:194-203`.

لا يوجد `conversation_id` أو `session_id` أو token budget أو تلخيص. هذا يجعل الإحالات السياقية للضيف وoffline غير مثبتة، وقد يخلط موضوعاً قديماً بموضوع جديد للمستخدم نفسه. **Recommendation:** أضف session boundary وTTL وحداً صريحاً للسياق، أو اجعل transcript محدوداً ومتحققاً في العقد. اختبر guest/authenticated/new-session/offline-online.

مسار الصوت لا يمرر الذاكرة الحوارية نفسها؛ يستعمل tone وuser context/feedback فقط. **Evidence:** `backend/app/api/v1/endpoints/audio.py:93-127,210-223`. يجب إما توحيد session memory أو وصف الصوت كـrecommendation مستقل.

## Recommendation & Quran Retrieval Assessment

الاسترجاع الهجين منفذ: MiniLM، Chroma، curated/general retrieval، ووزن semantic/emotion. **Evidence:** `backend/app/services/ai/embeddings.py:10-40,52-179` واختبارات `test_embedding_ranking.py:19-43`. لكنه غير مثبت من حيث Recall@k أو MRR أو nDCG على golden set عربي؛ البيانات في الاختبارات مصطنعة.

حاجز جيد هو أن النظام يقيد الاسترجاع بـ`type=verse` ويضيف نص الآية حرفياً خارج Gemini. **Evidence:** `recommend.py:158-192` و`rag_engine.py:304-343`. لكن الاختبارات تتحقق من الاحتواء لا exact equality، ولا يوجد hash canonical للنص والمصدر. **Recommendation:** manifest للـcorpus وhash لكل verse، وCI/startup integrity check، وgolden set بمراجعة domain expert.

provenance القرآني غير مكتمل: `quran.json` حقوله `chapter/text/verse`، و`seed_quran.py:84-90` يولد source من رقم السورة والآية. هذا display reference وليس source provenance. **Inference:** لا يجوز وصفه بـ`source_verified` قبل إضافة source_id وURL وversion وlicense وreview_status.

## Memory / History Assessment

Backend history معزول حسب `user_id` في الاستعلامات، ويخزن Interaction وfeedback. هذه نقطة قوة. لكن Hive chat box وlocal history box عالميان: `murassikh_chat_box` في `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:14-48` و`murassikh_local_history` في `frontend/lib/services/history_service.dart:83-100`، ولا يمسحهما logout في `auth_service.dart:97-116`.

**Severity Critical — Privacy/data isolation:** بعد logout من A وتسجيل B، قد يظهر سجل A محلياً. **Recommendation:** namespace حسب account identifier آمن، أو purge كامل عند تبديل الحساب، واختبار A→logout→B.

**Severity High — Semantic deletion:** clear chat محلي فقط ولا يمسح server history؛ clear history لا يمسح chat box. **Recommendation:** عقد reset واضح، وربط remote interaction ID بالمحلي بدلاً من timestamp فقط.

**Severity Medium — Memory model:** آخر خمسة تفاعلات ليست session memory، ولا يوجد budget أو summary. **Recommendation:** session/conversation model بسيط داخل البنية الحالية، دون إعادة كتابة النظام.

## Multimodal Assessment

النص هو الوسيط الأكثر اكتمالاً. الصوت يسجل ويرفع ويحلل النبرة بميزات عددية وعتبات؛ لا يوجد STT ولا يدخل محتوى الكلام إلى RAG. **Evidence:** `backend/app/services/ai/audio_analyzer.py:54-67` و`audio.py:52-96,167-180`. لذلك يجب تسمية الميزة tone classification، لا speech understanding.

الوجه يستخدم camera وML Kit، يأخذ `faces.first`، ويصنف فرح/سكينة/حزن/قلق/طبيعي من smiling/eye probabilities. **Evidence:** `frontend/lib/services/face_emotion_service.dart:73-90,147-195`. لا يوجد image understanding عام أو endpoint مستقل. **Inference:** «فهم متعدد الوسائط» ادعاء أوسع من الواقع.

**Recommendation:** إمّا تضييق النطاق إلى tone/face heuristics، أو بناء عقد موحد يتضمن modality وmodel_version وconfidence وtimestamp وprivacy expiry، مع اختبارات تعارض الوسائط وموافقة وحذف واختبار جهاز حقيقي. لا توجد حاجة لدمج raw media في نموذج موحد قبل إثبات الحاجة بقياسات.

## Performance Assessment

اختبارات الأداء الحالية تقيس وظائف محلية اصطناعية باستخدام fake embedding وبيانات صغيرة وميزانية p95 قدرها 20ms. **Evidence:** `backend/tests/performance/test_search_rag_performance.py:64-140`. **Fact:** لا توجد نتائج CI أو baseline أو قياسات p50/p95/p99 لمسار API الكامل مع PostgreSQL وRedis وChroma وGemini.

**Inference:** لا يمكن تحويل 20ms إلى SLO إنتاجي أو إلى ادعاء `<100ms` الوارد في دليل المستخدم. **Recommendation:** عرّف SLOs للرحلة، نفذ load/stress على staging مرتبطاً بالـSHA والبيانات والنموذج، وقس latency/error rate/CPU/memory وtimeouts/fallbacks. لا تحسن المعمارية قبل ظهور عنق زجاجة مقاس.

## Reliability Assessment

توجد health وreadiness تفحص PostgreSQL وRedis وChroma وتعيد 503 عند فشل dependency. **Evidence:** `backend/app/api/v1/endpoints/health.py:19-67`. توجد أيضاً شبكات داخلية وrate limiting عند ضبط Redis. هذه ضوابط جيدة لكنها **Implemented** لا **Verified**.

**Severity Critical — مشروط بتأكيد runtime:** `backend/app/core/config.py:38-47` يتحقق من وجود `SECRET_KEY` في kwargs، بينما Compose يمرره من environment في `docker-compose.production.yml:56-65`. **Inference:** قد يفشل الإقلاع. يجب تأكيده داخل صورة Docker وإصلاح التحقق للقيمة النهائية قبل الإطلاق.

**Severity High:** `deployment/staging/nginx.conf:11-17` يعلن 443 ssl لكن directives الشهادة معلقة، وCompose لا يركب volumes الشهادات. يجب جعل TLS secret/volume مطلوباً وإضافة `nginx -t` وTLS smoke.

**Severity High:** backup محلي غير مشفر، لا checksum أو رفع خارجي، ولا Chroma backup، ولا restore drill. **Evidence:** `deployment/scripts/backup.sh:21-28` و`restore.sh:22-35` و`docker-compose.production.yml:145-148`. يجب تعريف RPO/RTO ونسخ خارجية مشفرة واختبار استعادة معزول.

## Security & Privacy Assessment

Backend يملك JWT وArgon2 وrefresh rotation وعزل history حسب user. لكن logout يبطل refresh JTI ولا access token الجاري؛ `auth.py:113-127,170-178` و`core/auth.py:52-61`. هذا **Medium** إذا كان العقد يقصد إبطال refresh فقط، و**High** إن كان المستخدم يتوقع logout فورياً. يجب توثيق العقد أو إضافة session version/deny-list قصيرة.

التسجيل لا يفرض طول كلمة المرور أو EmailStr: `backend/app/api/v1/endpoints/auth.py:20-24` و`user_manager.py:17-24`. هذا **Medium — API security**؛ أضف schema constraints واختبارات 422.

الخصوصية المحلية هي الخطر الأشد: boxes غير namespaced ولا تمسح عند logout. كما أن سياسة الخصوصية تحتوي `[البريد الإلكتروني للدعم]` ولا تحدد retention أو المعالِجين أو إجراء النسخة والحذف. **Evidence:** `PRIVACY_POLICY.md:7-28`. لا يجوز وصف الخصوصية بأنها كاملة أو AES-256 دون إثبات آلية التشفير والحذف.

سلسلة التوريد غير محكومة بالكامل: صور Compose بلا digest، requirements بلا pins كافية، وDockerfile لا يحدد `USER` غير root. **Evidence:** `docker-compose.production.yml:2,102,125` و`backend/requirements.txt:6-18` و`backend/Dockerfile:1-27`. هذه **Medium**؛ عالجها تدريجياً عبر pins/constraints وSBOM وscan ومستخدم غير root، لا عبر إعادة بناء معماري.

## Documentation Assessment

الوثائق واسعة ومفيدة، لكنها تخلط بين «وثيقة موجودة» و«ميزة مكتملة». **Evidence:** `docs/README.md:68-77,137-149` مقابل مصفوفة الحالة وتقرير P3. كما توجد مسارات API قديمة في وثائق تاريخية مثل `docs/06-knowledge-base/تقرير-الفجوات-والخطوات-التالية.md:219-231` رغم أن الاختبارات تحرس العقد الحديث.

دليل المستخدم يذكر Offline و`<100ms` وAES-256 و36,000+ حديث بصيغة حقائق حالية في `docs/04-user-guide/الميزات.md:38-49,90-103,122-137`، بينما الحالة الرسمية تثبتها جزئياً فقط. ADR يذكر GATE-AraBERT وaccuracy 0.94 في `docs/06-knowledge-base/adr/004-نموذج-Embedding.md:31-72`، والكود يستخدم MiniLM. هذه **High — documentation truth**.

**Recommendation:** استخدم headers `Canonical/Historical/Deprecated`، واجعل status record مرتبطاً بـSHA والبيئة والاختبار وartifact. خفف الوعود غير المثبتة، وأضف manifest للبيانات والنماذج.

## Testing Assessment

توجد ملفات اختبار Backend وFlutter وWorkflow يعرّف Ruff وpip-audit وmigrations وpytest وFlutter analyze/test. **Evidence:** `.github/workflows/main.yml:37-41,51-62,77-124`. هذا يثبت إعداد الاختبارات، لا نجاحها.

**Evidence:** `pytest` أعاد `command not found`، و`alembic` كذلك، وFlutter/Dart وDocker غير متاحين. نجح `python3 -m compileall -q backend/app backend/tests`، و`bash -n deployment/scripts/*.sh scripts/smoke_test.sh`، وهما لا يثبتان runtime. لا توجد coverage/JUnit/APK/AAB/IPA متتبعة.

Smoke test لا يطابق العقد: `deployment/scripts/smoke_test.sh:44-54` يستخدم email/password بينما اختبار security يستخدم form username/password، ولا يختبر recommendation كاملاً. الأداء fake. **Recommendation:** CI نظيف على SHA نفسه، artifact outputs محفوظة، Compose/nginx validation، migrations، E2E auth→recommendation→history، Flutter analyze/test/build، وrestore drill.

## Critical Gaps

1. **Critical — Privacy/data isolation:** `murassikh_chat_box` و`murassikh_local_history` غير مرتبطين بالحساب ولا يمسحهما logout؛ قد تظهر بيانات A للمستخدم B. الأدلة: `frontend/lib/features/chat/presentation/screens/chat_dependencies.dart:14-48`، `frontend/lib/services/history_service.dart:83-100`، `frontend/lib/services/auth_service.dart:97-116`.
2. **Critical للإطلاق — Release verification:** لا staging smoke مثبت، ولا restore drill، ولا monitoring/alerts/SLO، ولا artifact موقّع Android/iOS. الأدلة: `docs/reports/P3_acceptance_report.md:3-26`، `docs/05-deployment/المراقبة.md:1,211-225`.
3. **Critical — Religious data governance:** درجات الحديث مفقودة في Bukhari/Muslim ومتعددة في الكتب الأخرى، و`seed_hadiths.py:56-118` يسقطها؛ لا يجوز نشر حديث أو `is_authentic` بلا provenance وسياسة تعارض. [4]
4. **Critical محتمل يحتاج تأكيد runtime — Startup:** تحقق `SECRET_KEY` قد لا يرى environment-loaded value. الأدلة: `backend/app/core/config.py:38-47,81` و`docker-compose.production.yml:56-65`.
5. **High — Content integrity:** لا canonical hash exact equality للآية والمصدر، وprovenance القرآني ناقص. الأدلة: `quran.json`، `seed_quran.py:84-90,111-143`، `rag_engine.py:304-343`.
6. **High — Conversation contract:** لا session boundary، وclear chat لا يصفر server memory، ومسار الصوت لا يشارك ذاكرة النص. الأدلة: `recommend.py:55-85`، `chat_screen.dart:188-214`، `audio.py:93-127`.
7. **High — AI quality:** fallback العربي غير مقاس، والاسترجاع بلا golden set أو relevance metrics، و`ask` يحفظ defaults خاطئة. الأدلة: `conversational_agent.py:109-177`، `recommend.py:87-117`، `embeddings.py:52-179`.
8. **High — TLS/DR:** staging TLS غير مكتمل، والنسخ محلي غير مشفر ولا يشمل Chroma ولا يملك drill. الأدلة: `deployment/staging/nginx.conf:11-17`، `deployment/scripts/backup.sh:21-28`.

## Root Causes

السبب الجذري الأول هو **عدم وجود release evidence ككائن إلزامي**. يوجد كود ووثيقة وCI وسكربت، لكن لا يوجد سجل واحد يربط SHA بالبيئة، ونتائج التشغيل، وartifact، وchecksum، ومالك الدليل.

السبب الثاني هو **تعدد مصادر الحقيقة**. README وADR ودليل المستخدم ومصفوفة الحالة والعقد التاريخي لا تستخدم طبقات Canonical/Historical/Deprecated ثابتة، فتختلط حالة الوثيقة بحالة المنتج.

السبب الثالث هو **عقود غير مكتملة بين الطبقات**: لا contract للجلسة، ولا ownership للـlocal boxes، ولا دلالة موحدة للمسح، ولا identifier mapping بين ChatMessage وHistoryItem وInteraction.

السبب الرابع هو **حوكمة بيانات غير مكتملة**. القرآن مضبوط بنيوياً لكن provenance/review ناقص، والحديث يملك assets دون سياسة درجات أو gate نطاق. كذلك لا توجد evaluation datasets عربية أو golden retrieval sets.

السبب الخامس هو **اختبارات مصدرية أكثر من اختبارات تنفيذية**. الاختبارات موجودة لكن الأدوات والنتائج وartifacts غير مثبتة لهذا commit، ولا توجد device/E2E/restore/load evidence.

## Recommended Direction

أوصي بالاستمرار في البنية الحالية مع **تصحيح العقود وإغلاق الأدلة**، لا Rewrite ولا Microservices. اجعل المنتج في الإصدار القريب **Quran-only، نصياً أولاً، وstaging مشروطاً**. سمِّ الصوت tone classification والوجه face heuristics، واجعل Image خارج النطاق المعلن. اجعل Offline cached/fallback ما لم يظهر دليل محرك محلي.

اعتمد status record واحداً لكل SHA مرشح. يجب أن يحتوي على الحالة لكل capability، الأمر والنتيجة، البيئة، version للبيانات والنموذج، digest للصورة، artifact ID، وقرار المالك. امنع عبارة Production Ready إن لم تغلق بوابات smoke وrestore وmonitoring وartifact.

صحح أولاً الفجوات التي تمس الخصوصية وسلامة المحتوى والاتساق: local namespaces، deletion semantics، atomic delayed response، ask fields، canonical Quran manifest، ونطاق الحديث. بعد ذلك قس الجودة والأداء قبل أي تحسين معماري.

## Target Architecture / Operating Model

**حدود التطبيق:** أبقِ FastAPI كتطبيق موحد مع وحدات واضحة: API/auth، conversation/history، recommendation/RAG، content governance، health/ops. أبقِ Flutter عميلاً لهذه العقود. لا تفصل خدمات مستقلة قبل قياس حدود التوسع أو العزل التي لا يمكن للبنية الحالية معالجتها.

**مصدر الذاكرة:** عرّف `conversation_id` اختيارياً أو session reset صريحاً. خزّن Interaction مع owner وremote ID، وحدد token/character budget وTTL أو summary. استخدم namespace محلياً حسب account، وحالات `local-only/pending/synced/deleted`.

**مصدر المحتوى:** أنشئ manifest غير قابل للالتباس لكل corpus: `source_id`, `source_url`, `source_version`, `retrieved_at`, `license`, `content_sha256`, `review_status`, وmodel/index version. فرّق `display_reference` عن `source_provenance`. اجعل Quran-only gate يفحص كل collections في CI/release.

**الوسائط:** عقد موحد للإشارة يتضمن modality وmodel_version وconfidence وtimestamp وprivacy expiry. في المرحلة الحالية، أرسل tone/face result بوصفه إشارة مشتقة، لا raw media، ولا تجعل threshold probability. إذا تطلب الهدف فهم كلام، أضف STT كمسار مستقل ثم مرر النص إلى `/analyze`.

**الإصدار والتشغيل:** استخدم release job منفصلاً للـmigrations وseed verification، ثم شغّل التطبيق بفحوص readiness. اجعل TLS secrets مطلوبة. نفذ نسخاً خارجية مشفرة مع checksum وChroma policy وrestore drill. اربط كل artifact بالـSHA وimage digest وSBOM وsmoke result.

**الحوكمة:** مالك واحد لمصدر الحقيقة، ومراجع شرعي لمحتوى قابل للعرض، ومالك تشغيل للـSLO/DR، ومالك خصوصية للحذف والاحتفاظ. كل Recommendation يجب أن تحمل source، corpus/index version، confidence semantics، وfallback state.

## Prioritized Roadmap

| الأولوية | العمل | النوع | دليل الإغلاق |
|---|---|---|---|
| P0 | عزل Hive chat/history حسب الحساب، وتوحيد logout/clear semantics | Critical / Privacy | اختبار حسابين، logout/login، clear chat/history، وفحص عدم بقاء البيانات |
| P0 | منع نشر محتوى حديثي غير محكوم، أو تثبيت Quran-only gate شامل | Critical / Religious data | CI manifest scan لكل collections، وفشل عند `type=hadith` غير مصرح |
| P0 | إثبات/إصلاح Settings production وTLS staging | Critical/High / Reliability | subprocess داخل صورة Docker، `nginx -t`، TLS smoke وfingerprint |
| P0 | إنشاء release/status record موحد مرتبط بالـSHA | Critical / Governance | سجل يحتوي commit/env/tests/artifacts/owner وCI gate |
| P1 | معاملة واحدة لـInteraction وDelayedResponse، وتصحيح ask fields | High / Data consistency | fault-injection وcontract test يقارن response بالصف المحفوظ |
| P1 | تعريف conversation/session contract وtoken budget | High / Product contract | guest/auth/session reset/offline-online E2E وعدم تسرب السياق |
| P1 | canonical Quran manifest وexact text/source integrity | High / Content | hash/checksum وstartup/CI verification وfixture exact equality |
| P1 | توحيد وعود Offline والوسائط في الوثائق والواجهة | High / Product truth | حالات cached/fallback صريحة، ونصوص لا تدعي STT/Image أو local generation |
| P1 | تشغيل CI فعلياً على SHA نفسه مع Flutter/pytest/migrations | High / Verification | نتائج pass/fail وcoverage/JUnit محفوظة |
| P2 | dataset عربي وقياس fallback، وgolden set للـRAG | High / AI quality | macro-F1، calibration، Recall@k/MRR/nDCG، regression thresholds |
| P2 | smoke E2E وload test على staging | High / Ops | auth→recommendation→history، p50/p95/p99، error/resource report |
| P2 | restore drill مشفر وخارجي يشمل Chroma policy | High / DR | RPO/RTO، checksum، زمن الاستعادة، تحقق counts/content |
| P2 | password validation، logout contract، readiness fingerprint | Medium / Security/Operations | اختبارات 422 وpost-logout وdataset version/fingerprint |
| P3 | pins/digests، SBOM، non-root، RLS/archive إن ثبتت الحاجة | Medium/Low / Supply chain | reproducible build وscan وpolicy evidence |

## Deferred Work

يؤجل **Rewrite أو Microservices**؛ لا يوجد دليل أداء أو استقلالية فرق يبررهما. تؤجل إضافة حديث إلى عقد التوصية حتى تكتمل grades/provenance/review، أو يعزل كمنتج مستقل بعقد مستقل. تؤجل Image Understanding العام حتى يثبت الطلب، والخصوصية، والدقة، ومسار رفع وحذف واضح.

يؤجل التعلم online من feedback؛ الموجود profile hint محدود لا recommender learning. يجب أولاً تسجيل candidate IDs/scores وإجراء offline evaluation. يؤجل STT العربي إذا ظل نطاق المنتج tone classification فقط، لكن يجب ألا توصف النبرة بأنها فهم محتوى.

تؤجل مراقبة متقدمة مثل Prometheus/Grafana إلى ما بعد تعريف SLOs وامتلاك staging قابل للقياس؛ لا يصح تركيب أدوات دون أهداف أو تنبيهات قابلة للاختبار. تؤجل RLS والأرشفة الآلية إن كانت متطلبات غير مؤكدة، مع تصحيح الوثائق حتى لا توصف كضوابط قائمة.

## Acceptance Criteria

1. **مصدر الحقيقة:** لكل SHA مرشح status record واحد يذكر الحالة، البيئة، المالك، أمر الاختبار، النتيجة، model/data version، artifact وimage digest.
2. **الخصوصية:** لا يظهر محتوى حساب A في B بعد logout/login أو offline fallback؛ clear/delete يحدد ويمسح كل المخازن المقصودة، وتوجد اختبارات تنفيذية لذلك.
3. **العقد:** `/api/v1/analyze` و`/home/verse` وaudio موثقة Canonical؛ لا توجد المسارات القديمة في الوثائق التشغيلية أو دليل المستخدم؛ ask response وInteraction متطابقان.
4. **المعاملات:** فشل DelayedResponse بعد إنشاء Interaction لا يترك حالة نصف مكتملة؛ اختبار rollback ينجح.
5. **القرآن:** manifest يتضمن المصدر والإصدار والترخيص وhash وreview_status؛ startup/CI يطابق corpus وChroma؛ exact equality للنص والمصدر مثبتة.
6. **الحديث:** إما لا يوجد حديث في أي collection إنتاجية، أو توجد سياسة مستقلة تحفظ النص الخام والإسناد و`grades[]` وprovenance وحالة `needs_review`.
7. **AI:** dataset عربي versioned، metrics وcalibration ورفض للغموض؛ golden retrieval set وRecall@1/3/5 وMRR/nDCG بعتبات regression.
8. **المحادثة:** session boundary وbudget/summary وTTL أو reset مثبتة؛ اختبارات guest/auth/new session/text→audio→text.
9. **الوسائط:** الوثائق تسمي الصوت والوجه بدقة؛ أو عقد multimodal يتضمن modality/model/confidence/timestamp/expiry؛ لا ادعاء Image غير منفذ.
10. **Offline:** الواجهة تفرق `cached` و`fallback` و`serverUnavailable`، ولا تسمي توصية قديمة تحليلاً للنص الحالي.
11. **الأمن:** password policy وlogout semantics وTLS فعلي واختبارات `nginx -t` وTLS؛ secrets لا تكتب في الصور أو النسخ.
12. **DR:** نسخة خارجية مشفرة مع checksum وlifecycle، سياسة Chroma، restore drill معزول، وقياسات RPO/RTO.
13. **Testing/release:** CI ناجح على SHA نفسه ويشمل migrations/backend/frontend/build/Compose؛ artifact Android أو iOS موقّع قابل للتتبع؛ smoke E2E يطابق OpenAPI.
14. **Performance:** SLO مع p50/p95/p99 وerror rate وCPU/memory على staging، مع baseline محفوظ لا benchmark fake فقط.

## Final Assessment

**القرار النهائي: لا إطلاق إنتاجي/تجاري لهذا commit.** التصنيف المبرر هو:

- **Implemented:** نعم، للنواة النصية، الواجهة الأساسية، auth/history، Chroma القرآن، وبعض الصوت/الوجه والتشغيل.
- **Integrated:** جزئياً؛ التكامل النصي Backend–Flutter واضح، بينما الذاكرة المحلية، الصوت/النص، provenance، TLS، وDR غير مكتملة.
- **Tested:** جزئياً على مستوى ملفات الاختبار وCI configuration؛ لم تثبت نتيجة تنفيذية في بيئة المراجعة.
- **Verified:** جزئياً بنيوياً وساكناً فقط؛ لا staging/device/restore/load/release evidence كافية.
- **Production Ready:** لا.

**Fact:** لم تعدّل المراجعة المستودع ولم تنفذ commit. **Evidence:** تقارير المحاور تسجل بقاء HEAD عند `c915d0b03ff976c731e36cd98f6343bedd56f904`، ونجاح compileall وshell syntax، وفشل توفر pytest/Flutter/Docker. **Inference:** لا ينبغي قراءة هذا التقرير كإثبات runtime كامل، ولا ينبغي قراءة وجود كود أو اختبار كإثبات نجاحه. **Recommendation:** نفذ خارطة P0/P1، ثم أعد التدقيق اعتماداً على release evidence قابل لإعادة التشغيل.

## References

[1]: 01-docs.md "تقرير محور المنتج والوثائق ومصدر الحقيقة"
[2]: 02-backend.md "تقرير محور Backend وAPI وDatabase وAuthentication"
[3]: 03-ai.md "تقرير محور فهم المستخدم والمحادثة والاسترجاع"
[4]: 04-quran.md "تقرير محور حوكمة القرآن والحديث وprovenance"
[5]: 05-memory.md "تقرير محور History وMemory واستمرارية المحادثة"
[6]: 06-multimodal.md "تقرير محور الفهم متعدد الوسائط"
[7]: 07-frontend.md "تقرير محور Flutter وHome وOffline"
[8]: 08-ops.md "تقرير محور Reliability والأداء والأمن والاختبارات والنشر"
[9]: ../../حالة-المنتج-2026-09-22.md "مصفوفة حالة المنتج الرسمية"
[10]: ../P3_acceptance_report.md "تقرير قبول P3"
[11]: ../../../backend/app/api/v1/endpoints/recommend.py "مسار التوصية وعقد API"
[12]: ../../../frontend/lib/features/chat/presentation/screens/chat_dependencies.dart "تخزين الدردشة المحلي"
[13]: ../../../deployment/scripts/backup.sh "سكربت النسخ الاحتياطي"
[14]: ../../../deployment/staging/nginx.conf "إعداد Nginx في staging"

> **حدود الأدلة:** الإحالات إلى المسارات والأسطر مأخوذة من تقارير المحاور الثمانية. لم يُعتبر أي اختبار غير منفذ «ناجحاً»، ولم تُعتبر أي توصية تنفيذية تغييراً تم تطبيقه.
