import json
import os
import sys

import chromadb
from sentence_transformers import SentenceTransformer
from tqdm import tqdm

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def seed_hadiths():
    print("تحميل نموذج AraBERT...")
    model = SentenceTransformer('Omartificial-Intelligence-Space/GATE-AraBERT-v1')
    
    client = chromadb.PersistentClient(path="./chroma_db")
    collection = client.get_or_create_collection(
        name="islamic_content",
        metadata={"description": "القرآن والأحاديث والتفاسير (Local Embeddings)"}
    )
    
    # أسماء الكتب بالعربية
    BOOK_NAMES_AR = {
        'bukhari': 'صحيح البخاري',
        'muslim': 'صحيح مسلم',
        'ara-abudawud': 'سنن أبي داود',
        'ara-tirmidhi': 'سنن الترمذي',
        'ara-nasai': 'سنن النسائي',
        'ara-ibnmajah': 'سنن ابن ماجه',
    }
    
    books = ['bukhari', 'muslim', 'ara-abudawud', 'ara-tirmidhi', 'ara-nasai', 'ara-ibnmajah']
    documents = []
    metadatas = []
    ids = []
    
    print("قراءة ملفات الأحاديث...")
    for book in books:
        file_path = f"{book}.json"
        if not os.path.exists(file_path):
            continue
            
        book_ar = BOOK_NAMES_AR.get(book, book)
        
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            hadiths = data.get('hadiths', [])
            
            for h in hadiths:
                raw_text = h.get('text', '').strip()
                if not raw_text:
                    continue
                
                # ✂️ إزالة سند الحديث: نبحث عن بداية المتن بعد "قَالَ" أو "أَنَّ"
                # عادةً المتن يبدأ بعد جملة كبيرة من الرواة. نقطع عند آخر "قَالَ" قبل علامة اقتباس
                import re
                # نبحث عن المتن بعد علامة الاقتباس الأولى (‏")
                match = re.search(r'[""‏"]\s*(.+)', raw_text, re.DOTALL)
                if match:
                    text = match.group(1).strip().rstrip('‏"" .')
                    if len(text) < 20:  # نص قصير جداً → استخدم الكامل
                        text = raw_text
                else:
                    text = raw_text
                    
                hadith_id = h.get('hadithnumber', 0)
                
                meta = {
                    "type": "hadith",
                    "source": f"{book_ar} - حديث رقم {hadith_id}",
                    "book": book_ar
                }
                
                documents.append(text)
                metadatas.append(meta)
                ids.append(f"hadith_{book}_{hadith_id}")
                
    print(f"تم تجميع {len(documents)} حديث. جاري البحث عن الأحاديث غير الموجودة مسبقاً...")
    
    # We want to skip existing hadiths
    existing = collection.get(include=[])
    existing_ids = set(existing['ids'])
    
    new_docs = []
    new_meta = []
    new_ids = []
    for doc, meta, hid in zip(documents, metadatas, ids):
        if hid not in existing_ids:
            new_docs.append(doc)
            new_meta.append(meta)
            new_ids.append(hid)
            
    print(f"عدد الأحاديث الجديدة للإضافة: {len(new_docs)}")
    
    batch_size = 256
    for i in tqdm(range(0, len(new_docs), batch_size)):
        batch_docs = new_docs[i:i+batch_size]
        batch_meta = new_meta[i:i+batch_size]
        batch_ids = new_ids[i:i+batch_size]
        
        batch_emb = model.encode(batch_docs).tolist()
        
        collection.add(
            ids=batch_ids,
            embeddings=batch_emb,
            documents=batch_docs,
            metadatas=batch_meta
        )

    print("تم حفظ الأحاديث بنجاح في قاعدة البيانات!")

if __name__ == "__main__":
    seed_hadiths()
