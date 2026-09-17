# تطبيق مُرَسِّخ

## تشغيل التطبيق محليًا

بعد تثبيت Flutter، ثبّت الاعتماديات ثم شغّل التطبيق مع عنوان Backend المناسب للبيئة:

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

يُستخدم `10.0.2.2` لمحاكي Android للوصول إلى Backend يعمل على الجهاز المضيف. على جهاز فعلي، استبدله بعنوان IP الخاص بالجهاز المضيف أو بعنوان الخادم.

## بناء نسخة الإنتاج

```bash
flutter build apk \
  --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

إذا لم يتم تمرير `API_BASE_URL` فسيستخدم التطبيق قيمة التطوير الافتراضية:

```text
http://127.0.0.1:8000/api/v1
```

## الاختبارات

```bash
flutter analyze
flutter test
```
