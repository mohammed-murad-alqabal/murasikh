# خطة ما بعد الإطلاق الأولي (Post-MVP Roadmap)

## نظرة عامة
وصل تطبيق "مُرسِّخ" إلى MVP تجريبي يضم نواة التوصية القرآنية وواجهة Flutter والمصادقة والسجل. بعض الميزات المتقدمة، مثل التحليل المحلي الكامل والعمل دون اتصال بكامل القدرات والإطلاق التجاري، لم تُثبت بعد. تستعرض هذه الخطة المهام المؤجلة والتوسعات المستقبلية.

---

## ١. الإطلاق التجاري والمنصات (Deployment & Platforms) 🚀
- [ ] **بناء نسخة iOS:** إعداد التطبيق وتجربته على بيئة Xcode وإصدار نسخة تجريبية (TestFlight).
- [ ] **النشر على المتاجر (App Stores):**
  - تجهيز الأصول الرسومية (Screenshots, Feature Graphic).
  - كتابة وصف التطبيق والكلمات المفتاحية (ASO).
  - رفع التطبيق لمراجعة متجر Google Play و App Store.
- [ ] **البنية التحتية السحابية (Production Infrastructure):**
  - [x] (مؤجل من الخطة 1) تغليف الخادم باستخدام Docker ووضع CI/CD Pipeline.
  - إعداد خادم إنتاجي (VPS أو Cloud Run) مع شهادات SSL (HTTPS).

## ٢. تحسينات واجهة المستخدم (UI/UX Polish) ✨
- [x] **الرسوم المتحركة (Animations):** إضافة تأثيرات انتقال سلسة بين شاشة الدردشة وتغير الحالات الشعورية (Transition Animations).
- [x] **الوضع الصامت / الاهتزاز:** إضافة تفاعلات لمسية (Haptic Feedback) عند التقييم الإيجابي أو السلبي.
- [x] **إحصائيات المستخدم:** توفير رسوم بيانية (Charts) تعرض للمستخدم ملخص حالاته الشعورية أسبوعياً أو شهرياً داخل التطبيق.

## ٣. الترابط مع الأجهزة (Hardware & Wearables) ⌚
- [ ] **تطبيق الساعات الذكية (Smartwatch App):** نسخة مبسطة لـ Apple Watch و Wear OS ترسل إشعارات بآيات السكينة عند رصد معدل نبضات قلب مرتفع.
- [x] **تحليل البيانات الحيوية:** الربط مع Apple Health و Google Fit لقراءة المؤشرات الفسيولوجية (تم إنشاء HealthService لجلب معدل النبض واستنتاج التوتر).

## ٤. الأمان والخصوصية (Security & Privacy) 🔒
- [x] **نظام المصادقة (Authentication):** (مؤجل من الخطة 1) تطبيق نظام حسابات سحابي اختياري باستخدام JWT و تشفير متقدم (تم بناء الأساس البرمجي في Backend).
- [x] **تصدير ومسح البيانات:** إعطاء المستخدم تحكماً كاملاً لتحميل أو حذف كافة بياناته ومحادثاته بشكل نهائي (GDPR Compliance).

---
**آخر تحديث:** 2026-09-16  
**الحالة:** خارطة طريق للمستقبل  

---

## 📌 Status Update (Post-MVP Deferral)
**Decision**: The above items (iOS TestFlight, App Stores, VPS setup, Apple Watch / Wear OS) are explicitly **DEFERRED**. The current status is **MVP experimental / staging candidate**, not production or commercial release. The items remain outside the current MVP scope until their operational evidence is completed.
