# استخدام صورة بايثون خفيفة
FROM python:3.11-slim

# إعداد دليل العمل
WORKDIR /app

# تثبيت الاعتماديات الأساسية للنظام
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# نسخ ملف الاعتماديات
COPY backend/requirements.txt .

# تثبيت حزم بايثون
RUN pip install --no-cache-dir -r requirements.txt

# نسخ كامل كود الخادم الخلفي
COPY backend/ .

# إنشاء مجلدات البيانات إذا لم تكن موجودة
RUN mkdir -p data chroma_db

# كشف منفذ الخادم
EXPOSE 8000

# تشغيل التطبيق
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
