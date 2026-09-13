"""
build_taxonomic_fingerprints.py
===============================
يولّد بصمة تصنيفية لكل آية قرآنية (Fingerprint) بناءً على قائمة الأبعاد الـ 65+.
السكريبت يعمل بذكاء:
1. يقرأ الآيات من ChromaDB باستخدام offset لتجنب التكرار.
2. يرسل الآيات في دُفعات (15 آية) إلى Gemini.
3. يحفظ الناتج تدريجياً في `verse_fingerprints.json` محلياً.
4. **لا يقوم بالكتابة** على ChromaDB لتوفير موارد الجهاز! (سيتم قراءة الـ JSON لاحقاً في الذاكرة).
"""

import chromadb
import json
import os
import sys
import time
import google.generativeai as genai
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
BACKEND_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(BACKEND_DIR))

FINGERPRINTS_FILE = SCRIPT_DIR / "verse_fingerprints.json"

from app.core.taxonomy import EMOTION_TAXONOMY
ALL_DIMENSIONS = list(EMOTION_TAXONOMY.keys())

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
if not GEMINI_API_KEY:
    print("❌ يرجى تعيين GEMINI_API_KEY")
    sys.exit(1)

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-3.6-flash')

def build_prompt(verses_batch: list) -> str:
    dims = "، ".join(ALL_DIMENSIONS)
    verses_text = "\n".join([f"ID: {v['id']} | النص: {v['text']}" for v in verses_batch])
    return f"""أنت خبير في التفسير القرآني والتحليل النفسي والسلوكي.

لكل آية، قم ببناء "بصمة تصنيفية" (Fingerprint) تعكس محتواها بدقة من الأبعاد التالية:
{dims}

المطلوب لكل آية:
1. اختر من 3 إلى 6 أبعاد فقط تنطبق بدقة عالية على الآية. (لا تختلق أبعاداً غير موجودة).
2. أعطِ كل بُعد وزناً من 0.1 إلى 1.0.
3. اكتب جملة واحدة (signature) تشرح سبب اختيار أعلى بُعد.

الآيات:
{verses_text}

أعد النتيجة بصيغة JSON فقط بهذا الشكل:
{{
  "ID_الآية": {{
    "dimensions": {{"توحيد": 0.9, "يقين": 0.7, "ابتلاء": 0.4}},
    "signature": "الآية تؤكد على وحدانية الله في كشف الضر"
  }}
}}
لا تكتب أي نص خارج ה-JSON.
"""

def get_all_verses(collection) -> list:
    all_verses = []
    offset = 0
    batch = 500
    while True:
        result = collection.get(
            where={"type": "verse"},
            limit=batch,
            offset=offset,
            include=["documents"]
        )
        if not result["ids"]:
            break
        for i, vid in enumerate(result["ids"]):
            all_verses.append({
                "id": vid,
                "text": result["documents"][i]
            })
        if len(result["ids"]) < batch:
            break
        offset += batch
    return all_verses

def main():
    print("=" * 60)
    print("🕌 بناء البصمة التصنيفية للآيات القرآنية (Fingerprints)")
    print("=" * 60)

    client = chromadb.PersistentClient(path=str(BACKEND_DIR / "chroma_db"))
    collection = client.get_or_create_collection("islamic_content")

    print("\n📖 جلب الآيات من ChromaDB...")
    all_verses = get_all_verses(collection)
    total = len(all_verses)
    print(f"✅ وُجد {total} آية")

    progress = {}
    if FINGERPRINTS_FILE.exists():
        with open(FINGERPRINTS_FILE, "r", encoding="utf-8") as f:
            progress = json.load(f)

    done_ids = set(progress.keys())
    remaining = [v for v in all_verses if v["id"] not in done_ids]
    
    print(f"✅ مكتمل سابقاً: {len(done_ids)}")
    print(f"🔄 متبقٍّ: {len(remaining)}")

    if not remaining:
        print("\n🎉 اكتمل بناء جميع البصمات!")
        return

    BATCH_SIZE = 15
    batches = [remaining[i:i+BATCH_SIZE] for i in range(0, len(remaining), BATCH_SIZE)]
    
    b_idx = 0
    while b_idx < len(batches):
        batch = batches[b_idx]
        print(f"\nدُفعة {b_idx+1}/{len(batches)}...")
        try:
            prompt = build_prompt(batch)
            response = model.generate_content(prompt)
            raw = response.text.strip().replace('```json','').replace('```','')
            results = json.loads(raw)
            
            for verse in batch:
                vid = verse["id"]
                data = results.get(vid)
                if data and "dimensions" in data:
                    progress[vid] = data
                    print(f"  ✅ {vid} → {list(data['dimensions'].keys())[:2]}...")
                else:
                    progress[vid] = {"dimensions": {}, "signature": "غير محدد"}
            
            with open(FINGERPRINTS_FILE, "w", encoding="utf-8") as f:
                json.dump(progress, f, ensure_ascii=False, indent=2)
            
            b_idx += 1  # Success, move to next
            time.sleep(2)
        except json.JSONDecodeError as e:
            print(f"  ❌ خطأ JSON: {e}")
            # Mark them as empty to not get stuck forever on a bad format
            for verse in batch:
                progress[verse["id"]] = {"dimensions": {}, "signature": "خطأ في التنسيق"}
            with open(FINGERPRINTS_FILE, "w", encoding="utf-8") as f:
                json.dump(progress, f, ensure_ascii=False, indent=2)
            b_idx += 1
            time.sleep(2)
        except Exception as e:
            err = str(e).lower()
            if "quota" in err or "429" in err:
                print(f"  ⏸️  تجاوز الحصة! ننتظر 60 ثانية ثم نعيد المحاولة...")
                time.sleep(60)
                # لا نزيد b_idx لنعيد المحاولة
            else:
                print(f"  ❌ خطأ: {e}")
                time.sleep(3)
                b_idx += 1 # skip on other errors to avoid infinite loop
if __name__ == '__main__':
    main()

