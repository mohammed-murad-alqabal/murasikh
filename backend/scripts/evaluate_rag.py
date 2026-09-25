import asyncio
from app.services.ai.embeddings import EmbeddingService
import time

EVAL_DATASET = [
    {"query": "أشعر بضيق شديد في صدري ولا أعرف ماذا أفعل", "expected_chapter": 94, "expected_verse": 5},
    {"query": "خائف من المستقبل ومن الأعداء", "expected_chapter": 20, "expected_verse": 46},
    {"query": "أحس بالذنب الشديد بسبب أخطائي", "expected_chapter": 39, "expected_verse": 53},
    {"query": "أنا متعب جدا ومرهق من الحياة", "expected_chapter": 2, "expected_verse": 286},
]

def evaluate():
    print("Starting RAG Evaluation...")
    passed = 0
    start_time = time.time()
    
    service = EmbeddingService()
    
    for item in EVAL_DATASET:
        query = item["query"]
        print(f"\nQuery: {query}")
        
        # We simulate the conversational agent's behavior but directly use search_similar for MRR/Recall check
        results = service.search_similar(query, n_results=5, filters={"type": "verse"})
        
        found = False
        metadatas = results.get("metadatas", [[]])[0]
        
        for i, res in enumerate(metadatas):
            if res.get("chapter") == item["expected_chapter"] and res.get("verse") == item["expected_verse"]:
                print(f"✅ Found expected verse ({res.get('chapter')}:{res.get('verse')}) at rank {i+1}")
                passed += 1
                found = True
                break
                
        if not found:
            print(f"❌ Failed to find ({item['expected_chapter']}:{item['expected_verse']}) in top 5")
            for i, res in enumerate(metadatas):
                print(f"   Rank {i+1}: {res.get('chapter')}:{res.get('verse')}")
                
    total_time = time.time() - start_time
    print(f"\nEvaluation Complete: {passed}/{len(EVAL_DATASET)} passed in {total_time:.2f}s")

if __name__ == "__main__":
    evaluate()
