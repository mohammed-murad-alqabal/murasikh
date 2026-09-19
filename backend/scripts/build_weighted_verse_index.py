"""
build_weighted_verse_index.py
============================
يولّد أوزاناً نسبية لكل آية قرآنية مقابل 50+ حالة نفسية وإيمانية.
- يعالج 20 آية لكل طلب Gemini (لتقليل عدد الطلبات)
- يحفظ التقدم تدريجياً في progress.json
- يُكمل من حيث توقف عند الإعادة
- يُحدِّث ChromaDB بالأوزان كـ metadata
"""

import json
import os
import sys
import time
from pathlib import Path

import chromadb
import google.generativeai as genai

# ── إعداد المسارات ──────────────────────────────────────────
SCRIPT_DIR = Path(__file__).parent
BACKEND_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))

PROGRESS_FILE = SCRIPT_DIR / "verse_weights_progress.json"
OUTPUT_FILE = SCRIPT_DIR / "verse_weights_final.json"

# ── الحالات الـ 50+ ─────────────────────────────────────────
from app.core.taxonomy import EMOTION_TAXONOMY

ALL_EMOTIONS = list(EMOTION_TAXONOMY.keys())

# ── إعداد Gemini ─────────────────────────────────────────────
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not GEMINI_API_KEY:
    print("❌ يرجى تعيين GEMINI_API_KEY")
    sys.exit(1)

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel("gemini-3.6-flash")


# ── Prompt ──────────────────────────────────────────────────
def build_prompt(verses_batch: list) -> str:
    emotions_list = "، ".join(ALL_EMOTIONS)
    verses_text = "\n".join([f"ID:{v['id']} | {v['text']}" for v in verses_batch])
    return f"""أنت خبير في تفسير القرآن الكريم والتحليل النفسي الإسلامي.

لكل آية مما يلي، حدِّد أعلى 7 حالات نفسية أو إيمانية تُعبِّر عنها الآية أو تُعالجها، مع إعطاء وزن نسبي من 0.0 إلى 1.0 لكل حالة.

الحالات المتاحة: {emotions_list}

الآيات:
{verses_text}

أعد النتيجة بصيغة JSON فقط بهذا الشكل (لا تكتب أي شيء خارج الـ JSON):
{{
  "ID_للآية_1": {{"حالة1": 0.9, "حالة2": 0.7, ...}},
  "ID_للآية_2": {{"حالة1": 0.85, "حالة2": 0.6, ...}},
  ...
}}

قواعد مهمة:
- فقط 7 حالات للآية الواحدة
- الأوزان من 0.0 إلى 1.0
- استند إلى المعنى الحقيقي للآية وسياقها
- لا تُكرر الحالات
"""


# ── تحميل التقدم السابق ──────────────────────────────────────
def load_progress() -> dict:
    if PROGRESS_FILE.exists():
        with open(PROGRESS_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_progress(progress: dict):
    with open(PROGRESS_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)


# ── ChromaDB ──────────────────────────────────────────────────
def get_all_verse_ids(collection) -> list:
    """يجلب جميع معرّفات الآيات مع نصوصها"""
    all_verses = []
    offset = 0
    batch = 500
    while True:
        result = collection.get(
            where={"type": "verse"}, limit=batch, include=["documents", "metadatas"]
        )
        if not result["ids"]:
            break
        for i, vid in enumerate(result["ids"]):
            all_verses.append(
                {
                    "id": vid,
                    "text": result["documents"][i],
                    "metadata": result["metadatas"][i],
                }
            )
        if len(result["ids"]) < batch:
            break
        offset += batch
    return all_verses


def update_verse_weights(collection, verse_id: str, weights: dict):
    """يُحدِّث metadata آية معينة بالأوزان"""
    try:
        current = collection.get(
            ids=[verse_id], include=["metadatas", "documents", "embeddings"]
        )
        if not current["ids"]:
            return
        metadata = current["metadatas"][0].copy()
        # نخزّن الأوزان كـ JSON مضغوط
        metadata["emotion_weights"] = json.dumps(weights, ensure_ascii=False)
        # أعلى حالة — للبحث السريع
        if weights:
            top_emotion = max(weights, key=weights.get)
            metadata["primary_emotion"] = top_emotion
        collection.update(ids=[verse_id], metadatas=[metadata])
    except Exception as e:
        print(f"  ⚠️  خطأ في تحديث {verse_id}: {e}")


# ── المعالجة الرئيسية ─────────────────────────────────────────
def main():
    print("=" * 60)
    print("🕌 بناء الفهرس الموزون للآيات القرآنية")
    print("=" * 60)

    # اتصال ChromaDB
    client = chromadb.PersistentClient(path=str(BACKEND_DIR / "chroma_db"))
    collection = client.get_or_create_collection("islamic_content_minilm")

    # تحميل جميع الآيات
    print("\n📖 جلب الآيات من ChromaDB...")
    all_verses = get_all_verse_ids(collection)
    total = len(all_verses)
    print(f"✅ وُجد {total} آية")

    # تحميل التقدم السابق
    progress = load_progress()
    done_ids = set(progress.keys())
    remaining = [v for v in all_verses if v["id"] not in done_ids]

    print(f"✅ مكتمل سابقاً: {len(done_ids)}")
    print(f"🔄 متبقٍّ: {len(remaining)}")

    if not remaining:
        print("\n🎉 جميع الآيات معالجة! ننتقل للتحديث في ChromaDB...")
    else:
        # معالجة على دُفعات من 20
        BATCH_SIZE = 20
        batches = [
            remaining[i : i + BATCH_SIZE] for i in range(0, len(remaining), BATCH_SIZE)
        ]

        print(f"\n🚀 البدء في المعالجة ({len(batches)} دُفعة × {BATCH_SIZE} آية)")
        print("-" * 60)

        for b_idx, batch in enumerate(batches):
            print(f"\nدُفعة {b_idx + 1}/{len(batches)} ({len(batch)} آية)...")

            try:
                prompt = build_prompt(batch)
                response = model.generate_content(prompt)
                raw = response.text.strip().replace("```json", "").replace("```", "")

                results = json.loads(raw)

                for verse in batch:
                    vid = verse["id"]
                    weights = results.get(vid, {})
                    if weights:
                        # نضمن 7 حالات كحد أقصى
                        sorted_w = dict(
                            sorted(weights.items(), key=lambda x: x[1], reverse=True)[
                                :7
                            ]
                        )
                        progress[vid] = sorted_w
                        print(f"  ✅ {vid} → {list(sorted_w.keys())[:3]}...")
                    else:
                        progress[vid] = {}
                        print(f"  ⚠️  {vid} → لم تُعثر على بيانات")

                # حفظ التقدم كل دُفعة
                save_progress(progress)

                # تأخير لتجنب تجاوز الحصة
                time.sleep(1.5)

            except json.JSONDecodeError as e:
                print(f"  ❌ خطأ JSON في الدُفعة {b_idx + 1}: {e}")
                print(f"     الرد: {response.text[:200]}")
                # نُعيّن أوزاناً فارغة لتلافي التوقف
                for verse in batch:
                    progress[verse["id"]] = {}
                save_progress(progress)
                time.sleep(2)

            except Exception as e:
                err = str(e).lower()
                if "quota" in err or "429" in err or "resource_exhausted" in err:
                    print("  ⏸️  تجاوز الحصة! انتظار 60 ثانية...")
                    time.sleep(60)
                    # إعادة المحاولة
                    b_idx -= 1
                else:
                    print(f"  ❌ خطأ: {e}")
                    time.sleep(3)

    # ── تحديث ChromaDB ─────────────────────────────────────────
    print("\n" + "=" * 60)
    print("🔄 تحديث ChromaDB بالأوزان...")

    updated = 0
    skipped = 0
    for verse_id, weights in progress.items():
        if weights:
            update_verse_weights(collection, verse_id, weights)
            updated += 1
        else:
            skipped += 1

        if (updated + skipped) % 500 == 0:
            print(f"  تقدم: {updated + skipped}/{len(progress)}")

    print(f"\n✅ تم تحديث {updated} آية")
    print(f"⚠️  تخطّي {skipped} آية (بدون بيانات)")

    # حفظ النتيجة النهائية
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(progress, f, ensure_ascii=False, indent=2)
    print(f"\n💾 الملف النهائي: {OUTPUT_FILE}")
    print("🎉 اكتمل بناء الفهرس الموزون!")


if __name__ == "__main__":
    main()
