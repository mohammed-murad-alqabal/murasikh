# 🌳 استراتيجية Git

استراتيجية التحكم بالإصدار والفروع المتبعة في مشروع مُرَسِّخ.

---

## 📊 نموذج الفروع

نستخدم **GitHub Flow** المبسط مع تعديلات طفيفة:

```
main (production)
  │
  ├── develop (integration)
  │     │
  │     ├── feature/user-authentication
  │     │     └── (merged to develop)
  │     │
  │     ├── feature/recommendation-engine
  │     │     └── (merged to develop)
  │     │
  │     └── fix/database-timeout
  │           └── (merged to develop)
  │
  └── release/v0.2.0 (created from develop)
```

---

## 🌿 أنواع الفروع

### 1. Main Branch (main)

- **الاستخدام:** الكود الجاهز للإنتاج
- **الحماية:** محمي، لا يمكن Push مباشرة
- **الدمج:** فقط عبر Pull Request من `release/*`
- **الإصدارات:** كل دمج = إصدار جديد

### 2. Develop Branch (develop)

- **الاستخدام:** دمج الفروع الفرعية
- **الحماية:** محمي، يتطلب موافقة
- **الدمج:** من `feature/*`, `fix/*`, `refactor/*`

### 3. Feature Branches (feature/*)

- **الاستخدام:** ميزات جديدة
- **الاسم:** `feature/description`
- **القاعدة:** من `develop`
- **الدمج:** إلى `develop`

**أمثلة:**
```
feature/user-authentication
feature/offline-support
feature/emotion-classification
```

### 4. Fix Branches (fix/*)

- **الاستخدام:** إصلاح أخطاء
- **الاسم:** `fix/description`
- **القاعدة:** من `develop` أو `main` (للـ hotfix)

**أمثلة:**
```
fix/database-connection-timeout
fix/rtl-layout-issue
fix/embedding-calculation-error
```

### 5. Refactor Branches (refactor/*)

- **الاستخدام:** تحسين الكود بدون تغيير الوظيفة
- **الاسم:** `refactor/description`
- **القاعدة:** من `develop`

### 6. Documentation Branches (docs/*)

- **الاستخدام:** تحديث التوثيق
- **الاسم:** `docs/description`
- **القاعدة:** من `develop` أو `main`

### 7. Release Branches (release/*)

- **الاستخدام:** تجهيز إصدار جديد
- **الاسم:** `release/vX.Y.Z`
- **القاعدة:** من `develop`
- **الدمج:** إلى `main` و `develop`

### 8. Hotfix Branches (hotfix/*)

- **الاستخدام:** إصلاح عاجل في الإنتاج
- **الاسم:** `hotfix/vX.Y.Z-description`
- **القاعدة:** من `main`
- **الدمج:** إلى `main` و `develop`

---

## 🔄 سير العمل

### إنشاء ميزة جديدة

```bash
# 1. تحديث develop
git checkout develop
git pull origin develop

# 2. إنشاء فرع جديد
git checkout -b feature/my-feature

# 3. العمل على الميزة
# ... commits ...

# 4. Push الفرع
git push origin feature/my-feature

# 5. إنشاء Pull Request إلى develop
# عبر GitHub UI
```

### إصلاح خطأ

```bash
# 1. إنشاء فرع من develop
git checkout develop
git pull origin develop
git checkout -b fix/my-fix

# 2. إصلاح الخطأ
# ... commits ...

# 3. Push وإنشاء Pull Request
git push origin fix/my-fix
```

### Hotfix للإنتاج

```bash
# 1. إنشاء فرع من main
git checkout main
git pull origin main
git checkout -b hotfix/v0.1.1-database-fix

# 2. إصلاح المشكلة
# ... commits ...

# 3. إنشاء Pull Request إلى main
git push origin hotfix/v0.1.1-database-fix

# 4. بعد الدمج، دمج في develop أيضاً
git checkout develop
git merge hotfix/v0.1.1-database-fix
git push origin develop
```

### إصدار جديد

```bash
# 1. إنشاء فرع الإصدار
git checkout develop
git checkout -b release/v0.2.0

# 2. تحديث الإصدار
# - تحديث version في الملفات
# - تحديث CHANGELOG.md
# - اختبارات نهائية

# 3. دمج في main
git checkout main
git merge --no-ff release/v0.2.0
git tag -a v0.2.0 -m "Release version 0.2.0"
git push origin main --tags

# 4. دمج في develop
git checkout develop
git merge --no-ff release/v0.2.0
git push origin develop

# 5. حذف فرع الإصدار
git branch -d release/v0.2.0
```

---

## 📝 رسائل Commit

### التنسيق

```
<type>(<scope>): <subject>

<body>

<footer>
```

### الأنواع (Types)

| النوع | الوصف |
|-------|-------|
| `feat` | ميزة جديدة |
| `fix` | إصلاح خطأ |
| `docs` | توثيق |
| `style` | تنسيق (بدون تغيير منطق) |
| `refactor` | إعادة هيكلة |
| `perf` | تحسين أداء |
| `test` | اختبارات |
| `chore` | صيانة |
| `ci` | CI/CD |

### النطاق (Scope) - اختياري

| النطاق | مثال |
|--------|------|
| `api` | `feat(api): add recommendation endpoint` |
| `db` | `fix(db): resolve connection pool issue` |
| `ui` | `style(ui): fix RTL layout` |
| `ai` | `refactor(ai): optimize embedding creation` |

### أمثلة

```bash
# ميزة جديدة
feat(api): add user authentication system

# إصلاح
fix(db): resolve PostgreSQL connection timeout

# توثيق
docs(readme): update installation instructions

# تحسين
perf(ai): optimize embedding batch processing

# مع تفاصيل
feat(ui): add offline mode support

- Implement Hive for local storage
- Add connectivity check
- Create sync mechanism

Closes #123
```

---

## 🛡️ قواعد الحماية

### Branch Protection Rules

#### main
- ✅ Require pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Include administrators

#### develop
- ✅ Require pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass

---

## ✅ قائمة التحقق للـ Pull Request

- [ ] الفرع مأخوذ من القاعدة الصحيحة
- [ ] اسم الفرع يتبع القواعد
- [ ] رسائل Commit واضحة ومنظمة
- [ ] الاختبارات تمر
- [ ] لا توجد تعارضات
- [ ] التوثيق محدث (إذا لزم الأمر)
- [ ] تم طلب المراجعة

---

## 🏷️ الإصدارات

نتبع [Semantic Versioning](https://semver.org/):

```
MAJOR.MINOR.PATCH

مثال: 1.2.3
- MAJOR (1): تغييرات جوهرية غير متوافقة
- MINOR (2): ميزات جديدة متوافقة
- PATCH (3): إصلاحات أخطاء
```

### أمثلة

| الإصدار | التغيير |
|---------|---------|
| 0.1.0 → 0.1.1 | إصلاح خطأ |
| 0.1.1 → 0.2.0 | ميزة جديدة |
| 0.2.0 → 1.0.0 | تغيير جوهري |

---

## 🔄 Git Hooks

### Pre-commit

```bash
#!/bin/bash
# .git/hooks/pre-commit

# تشغيل التنسيق
black --check app/
isort --check-only app/

# تشغيل Linter
flake8 app/

# تشغيل الاختبارات السريعة
pytest tests/ -m "not slow"
```

### Pre-push

```bash
#!/bin/bash
# .git/hooks/pre-push

# تشغيل جميع الاختبارات
pytest tests/
```

---

## 📚 المراجع

- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Branching Strategies](https://www.atlassian.com/git/tutorials/comparing-workflows)

---

**آخر تحديث:** 2026-09-11
