content = """# تقرير القبول للمرحلة P3 - جاهزية الإنتاج

## 1. إعداد Staging (F-16)
- [ ] خادم أو Cloud Run حقيقي.
- [ ] DNS وشهادة TLS.
- [ ] CORS_ORIGINS إنتاجي إلزامي.
- [ ] Nginx مع server_name فعلي وHSTS.
- [ ] PostgreSQL وRedis غير منشورين.
- [ ] smoke test خارجي على /health ومسارات المصادقة والتوصية.

## 2. النسخ الاحتياطي والمراقبة (F-17)
- [ ] جدول pg_dump أو خدمة Backup مدارة.
- [ ] تشفير النسخ وتحديد retention.
- [ ] اختبار restore دوري.
- [ ] مراقبة uptime وHealthcheck.
- [ ] سجل مركزي وتنبيه عند 5xx وارتفاع latency.

## 3. اختبار الأجهزة والإصدار (F-18)
- [ ] Android فعلي: القفل، الإشعارات، الصوت، Health permissions.
- [ ] iOS فعلي: Face ID/Touch ID، الإشعارات، HealthKit، background lifecycle.
- [ ] Build release موقّع.
- [ ] TestFlight وInternal App Sharing.
- [ ] أصول المتاجر وسياسة الخصوصية وشروط الاستخدام.

## معيار الإغلاق العام
تقرير قبول يحتوي نتائج كل جهاز ونظام وإصدار، مع روابط artifacts موقعة ونتيجة smoke test إنتاجي.
"""

with open("docs/reports/P3_acceptance_report.md", "w") as f:
    f.write(content)
