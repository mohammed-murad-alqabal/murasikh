# Murassikh — دليل النشر والتشغيل

## متطلبات الإعداد

| الأداة | الإصدار المطلوب |
|--------|----------------|
| Docker | >= 24.x |
| Docker Compose | >= 2.x |
| Nginx (على الخادم) | >= 1.24 |
| Certbot (Let's Encrypt) | أحدث إصدار |

---

## النشر على Staging (F-16)

### 1. إعداد متغيرات البيئة

أنشئ ملف `.env` في نفس مجلد `docker-compose.yml` بالمتغيرات التالية (لا تحتفظ بهذا الملف في git):

```bash
POSTGRES_USER=murassikh
POSTGRES_PASSWORD=<كلمة_مرور_قوية>
POSTGRES_DB=murassikh_db
SECRET_KEY=<مفتاح_عشوائي_64_حرفاً>
GEMINI_API_KEY=<مفتاح_Google_Gemini>
CORS_ORIGINS=https://murassikh.com,https://www.murassikh.com
```

### 2. إعداد شهادة SSL (TLS)

```bash
certbot certonly --nginx -d api.murassikh.com
```

تركيب الشهادة إلزامي في `deployment/staging/docker-compose.yml`؛ يجب أن توجد الملفات التالية قبل التشغيل:

```text
deployment/staging/ssl/live/api.murassikh.com/fullchain.pem
deployment/staging/ssl/live/api.murassikh.com/privkey.pem
```

### 3. التشغيل

```bash
cd deployment/staging
docker compose up -d --build
```

### 4. تأكيد الـ Chroma Index

يقوم `entrypoint.sh` تلقائياً بالتحقق من فهرس القرآن (6236 آية) قبل الإقلاع. إذا فشل، يجب تشغيل الـ Seed يدوياً:

```bash
docker exec -it staging-backend-1 python -m scripts.seed_quran
```

---

## النسخ الاحتياطي والاستعادة (F-17)

### النسخ الاحتياطي اليدوي

```bash
export DB_CONTAINER=staging-postgres-1
export CHROMA_VOLUME=murassikh-staging_chroma-data
./scripts/backup.sh
```

ينشئ السكربت نسخة PostgreSQL ونسخة Chroma منفصلة، مع ملف `sha256` لكل نسخة. لا يُعد النسخ كاملاً إذا لم يُحدّد `CHROMA_VOLUME`.

### جدولة النسخ الاحتياطي التلقائي (cron)

```bash
# كل يوم الساعة 2 صباحاً
0 2 * * * /path/to/deployment/scripts/backup.sh >> /var/log/murassikh_backup.log 2>&1
```

### الاستعادة من نسخة احتياطية

```bash
export DB_CONTAINER=staging-postgres-1
export CHROMA_VOLUME=murassikh-staging_chroma-data
./scripts/restore.sh \
  /var/backups/murassikh/murassikh_db_2026-09-22_02-00-00.sql.gz \
  /var/backups/murassikh/murassikh_chroma_2026-09-22_02-00-00.tar.gz
```

يتطلب الاستعادة ملفات checksum المطابقة، وتظل عملية مدمرة تفاعلية يجب تنفيذها فقط داخل بيئة معزولة أثناء `restore drill` موثق.

---

## Smoke Test (F-16 #6)

بعد النشر، شغّل اختبار الدخان للتحقق من صحة الخدمات:

```bash
./scripts/smoke_test.sh https://api.murassikh.com
```

---

## المراقبة (F-17 #4 و #5)

الوضع الحالي: **Roadmap** — غير منفذ في MVP.

يُوصى في الإصدار التالي بإضافة:
- **Uptime monitoring:** Uptime Kuma أو BetterStack على `/health/live`.
- **Centralized logging:** Grafana Loki أو Datadog.
- **Alerting:** تنبيه فوري عند ظهور أخطاء HTTP 5xx أو ارتفاع latency.

---

## قائمة التحقق قبل الإصدار (F-18)

### Android ✅
- [ ] اختبار تثبيت APK على جهاز حقيقي
- [ ] التحقق من أذونات الميكروفون والصوت
- [ ] التحقق من أذونات الموقع الجغرافي
- [ ] اختبار الإشعارات
- [ ] بناء `flutter build apk --release`
- [ ] توقيع APK (keystore)

### iOS ⏳ (يتطلب Mac + Apple Developer Account)
- [ ] اختبار Face ID / Touch ID
- [ ] اختبار الإشعارات
- [ ] اختبار HealthKit
- [ ] `flutter build ipa --release`
- [ ] رفع على TestFlight

### متاجر التطبيقات
- [ ] أصول المتاجر (لقطات الشاشة، الأيقونة، وصف التطبيق)
- [ ] رابط سياسة الخصوصية (PRIVACY_POLICY.md)
- [ ] شروط الاستخدام (TERMS_OF_USE.md)


---

## الإصدار الموقَّع لـ Android (F-18 #3)

لبناء نسخة موقَّعة جاهزة للنشر في Google Play:

### 1. إنشاء Keystore (مرة واحدة فقط)
```bash
keytool -genkey -v -keystore murassikh-release.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias murassikh
```
احتفظ بهذا الملف في مكان آمن خارج المستودع.

### 2. إعداد التوقيع في Flutter
أضف في `frontend/android/key.properties` (مستبعد من git):
```
storePassword=<كلمة_مرور_keystore>
keyPassword=<كلمة_مرور_key>
keyAlias=murassikh
storeFile=<المسار_الكامل_لـ_murassikh-release.jks>
```

### 3. بناء الـ APK الموقَّع
```bash
cd frontend && flutter build apk --release
```
النتيجة: `frontend/build/app/outputs/flutter-apk/app-release.apk`

### 4. بناء App Bundle (للـ Play Store)
```bash
cd frontend && flutter build appbundle --release
```
