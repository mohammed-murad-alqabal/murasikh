import sys
import os
import json
import chromadb
from sentence_transformers import SentenceTransformer
from tqdm import tqdm
import time

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def seed_quran():
    print("تحميل نموذج AraBERT...")
    model = SentenceTransformer('Omartificial-Intelligence-Space/GATE-AraBERT-v1')
    
    client = chromadb.PersistentClient(path="./chroma_db")
    collection = client.get_or_create_collection(
        name="islamic_content",
        metadata={"description": "القرآن والأحاديث والتفاسير (Local Embeddings)"}
    )
    
    print("قراءة ملف القرآن...")
    with open('quran.json', 'r', encoding='utf-8') as f:
        quran_data = json.load(f)
        
    documents = []
    metadatas = []
    ids = []
    
    # قائمة ببعض الآيات المهمة لنربطها بحالات عاطفية محددة لتعزيز الدقة (كما طلب المستخدم)
    emotion_mapping = {
        "3:134": {"emotion": "غضب", "tafsir": "الذين يمسكون ما في أنفسهم من الغضب، ويعفون عمن أساء إليهم."},
        "2:155": {"emotion": "حزن", "tafsir": "بشارة عظيمة لمن يصبر على الحزن والمصيبة محتسباً الأجر من الله."},
        "2:156": {"emotion": "حزن", "tafsir": "بشارة عظيمة لمن يصبر على الحزن والمصيبة محتسباً الأجر من الله."},
        "13:28": {"emotion": "قلق", "tafsir": "القلوب تسكن وتستريح بذكر الله والتوكل عليه في أوقات التوتر والقلق."},
        "9:40": {"emotion": "يأس", "tafsir": "لا تيأس ولا تحزن، فإن الله يحفظنا ويرعانا في أشد الأوقات ضيقاً."},
        "94:5": {"emotion": "توتر", "tafsir": "فإن مع الشدة والضيق يسرًا وفرجًا."},
        "94:6": {"emotion": "توتر", "tafsir": "إن مع الشدة والضيق يسرًا وفرجًا."},
        "2:286": {"emotion": "إرهاق", "tafsir": "لا يكلف الله نفساً إلا وسعها."},
        "39:53": {"emotion": "ذنب", "tafsir": "لا تقنطوا من رحمة الله إن الله يغفر الذنوب جميعاً."},
        "14:7": {"emotion": "شكر", "tafsir": "لئن شكرتم لأزيدنكم."},
        "20:46": {"emotion": "خوف", "tafsir": "لا تخافا إنني معكما أسمع وأرى."},
        "65:3": {"emotion": "حيرة", "tafsir": "ومن يتوكل على الله فهو حسبه."},
    }

    print("تجهيز الآيات...")
    for surah_num, verses in quran_data.items():
        for v in verses:
            v_id = f"{v['chapter']}:{v['verse']}"
            text = v['text']
            meta = {
                "type": "verse",
                "source": f"سورة رقم {v['chapter']} : آية {v['verse']}",
                "chapter": v['chapter'],
                "verse": v['verse']
            }
            
            # إضافة المشاعر إذا كانت موجودة في القائمة الخاصة
            if v_id in emotion_mapping:
                meta["emotion"] = emotion_mapping[v_id]["emotion"]
                meta["tafsir"] = emotion_mapping[v_id]["tafsir"]
                
            documents.append(text)
            metadatas.append(meta)
            ids.append(f"verse_{v_id}")

    print(f"تم تجهيز {len(documents)} آية. البدء بعملية الـ Embedding...")
    
    # إدخال البيانات على دفعات (Batching) لتجنب استهلاك الذاكرة العشوائية (RAM)
    batch_size = 256
    for i in tqdm(range(0, len(documents), batch_size)):
        batch_docs = documents[i:i+batch_size]
        batch_meta = metadatas[i:i+batch_size]
        batch_ids = ids[i:i+batch_size]
        
        # إنشاء الـ Embeddings
        batch_emb = model.encode(batch_docs).tolist()
        
        # حفظ في ChromaDB
        collection.add(
            ids=batch_ids,
            embeddings=batch_emb,
            documents=batch_docs,
            metadatas=batch_meta
        )

    print("تم حفظ جميع الآيات الـ 6236 بنجاح في قاعدة البيانات المحلية!")

if __name__ == "__main__":
    seed_quran()
