"""
build_local_fingerprints.py
يولد بصمة تصنيفية لكل آية محلياً بالكامل (بدون إنترنت/Gemini)
باستخدام MiniLM لحساب التقارب بين معاني الآية وقاموس المشاعر (67 حالة).
"""

import json
import sys
from pathlib import Path

import chromadb
import numpy as np
from sentence_transformers import SentenceTransformer

SCRIPT_DIR = Path(__file__).parent
BACKEND_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))

FINGERPRINTS_FILE = SCRIPT_DIR / "verse_fingerprints.json"
from app.core.taxonomy import EMOTION_TAXONOMY


def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))


def main():
    print("=" * 60)
    print("🧠 بناء البصمة التصنيفية محلياً (باستخدام MiniLM)")
    print("=" * 60)

    # 1. تحميل الموديل المحلي
    print("📥 تحميل نموذج MiniLM (محلي)...")
    model = SentenceTransformer(
        "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    )

    # 2. تحضير أبعاد التصنيف (Embeddings)
    print(f"📊 معالجة {len(EMOTION_TAXONOMY)} بُعد تصنيفي...")
    emotion_embeddings = {}
    for emotion, desc in EMOTION_TAXONOMY.items():
        text = f"{emotion}: {desc}"
        emotion_embeddings[emotion] = model.encode(text)

    # 3. جلب جميع الآيات من ChromaDB
    print("\n📖 جلب الآيات من ChromaDB...")
    client = chromadb.PersistentClient(path=str(BACKEND_DIR / "chroma_db"))
    collection = client.get_or_create_collection("islamic_content_minilm")

    all_verses = []
    offset = 0
    batch = 500
    while True:
        result = collection.get(
            where={"type": "verse"}, limit=batch, offset=offset, include=["documents"]
        )
        if not result["ids"]:
            break
        for i, vid in enumerate(result["ids"]):
            all_verses.append({"id": vid, "text": result["documents"][i]})
        offset += batch
        print(f"   تم جلب {offset} آية...")

    total = len(all_verses)
    print(f"✅ وُجد {total} آية")

    # 4. بناء البصمات
    progress = {}
    if FINGERPRINTS_FILE.exists():
        with open(FINGERPRINTS_FILE, "r", encoding="utf-8") as f:
            progress = json.load(f)

    done_ids = set(progress.keys())
    remaining = [v for v in all_verses if v["id"] not in done_ids]

    print(f"✅ مكتمل سابقاً: {len(done_ids)}")
    print(f"🔄 متبقٍّ للمعالجة: {len(remaining)}")

    if not remaining:
        print("\n🎉 اكتمل بناء جميع البصمات!")
        return

    print("\n🚀 البدء في التحليل الدلالي (قد يستغرق بضع دقائق)...")

    import time

    start_time = time.time()

    # معالجة الباقي
    for i, verse in enumerate(remaining):
        vid = verse["id"]
        text = verse["text"]

        verse_emb = model.encode(text)

        # حساب التشابه مع كل بُعد
        scores = {}
        for emotion, e_emb in emotion_embeddings.items():
            sim = cosine_similarity(verse_emb, e_emb)
            scores[emotion] = float(sim)

        # حفظ متجه كامل من 67 بُعداً. الأبعاد غير المنطبقة تحفظ بصفر حتى
        # يكون شكل البيانات ثابتاً وقابلاً للتحقق بين جميع الآيات.
        top_emotions = sorted(scores.items(), key=lambda x: x[1], reverse=True)[:5]
        dimensions = {
            emotion: round(max(float(scores[emotion]), 0.0), 4)
            for emotion in EMOTION_TAXONOMY
        }
        primary = top_emotions[0][0] if top_emotions else "غير محدد"

        progress[vid] = {
            "dimensions": dimensions,
            "signature": f"صُنفت ضمن '{primary}' بناءً على التقارب الدلالي النصي",
        }

        if (i + 1) % 100 == 0:
            elapsed = time.time() - start_time
            print(
                f"  ⏳ تمت معالجة {i + 1}/{len(remaining)} آية... ({elapsed:.1f} ثانية)"
            )

            # حفظ تدريجي
            with open(FINGERPRINTS_FILE, "w", encoding="utf-8") as f:
                json.dump(progress, f, ensure_ascii=False, indent=2)

    # حفظ نهائي
    with open(FINGERPRINTS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)

    print("\n🎉 اكتمل العمل! تم حفظ البصمات بنجاح.")


if __name__ == "__main__":
    main()
