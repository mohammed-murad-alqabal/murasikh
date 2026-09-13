import chromadb
from sentence_transformers import SentenceTransformer

class EmbeddingService:
    def __init__(self):
        self.client = chromadb.PersistentClient(path="./chroma_db")
        self.collection = self.client.get_or_create_collection(
            name="islamic_content",
            metadata={"description": "القرآن والأحاديث والتفاسير (Local Embeddings)"}
        )
        # استخدام موديل عربي متخصص للملاءمة مع المهام الدينية
        # سيتم تحميله مرة واحدة
        self.model = SentenceTransformer('Omartificial-Intelligence-Space/GATE-AraBERT-v1')

    def create_embedding(self, text: str) -> list:
        # Generate the embedding and convert to list of floats for ChromaDB
        embedding = self.model.encode(text)
        return embedding.tolist()
        
    def store_document(self, doc_id: str, text: str, metadata: dict):
        embedding = self.create_embedding(text)
        self.collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[text],
            metadatas=[metadata]
        )

    def search_similar(self, query: str, n_results: int = 3, filters: dict = None, emotion: str = None):
        query_embedding = self.create_embedding(query)
        
        # إذا تم تمرير حالة محددة، نسترجع عدداً أكبر لإعادة الترتيب (Hybrid Search)
        fetch_count = (n_results * 5) if emotion and emotion != "طبيعي" else n_results
        
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=fetch_count,
            where=filters
        )
        
        if not emotion or emotion == "طبيعي" or not results.get('documents') or not results['documents'][0]:
            # إذا لم تكن هناك حالة أو لا توجد نتائج، نعيد النتائج الأصلية
            if results.get('documents') and len(results['documents'][0]) > n_results:
                return {
                    "ids": [results["ids"][0][:n_results]],
                    "distances": [results["distances"][0][:n_results]],
                    "documents": [results["documents"][0][:n_results]],
                    "metadatas": [results["metadatas"][0][:n_results]]
                }
            return results

        # ── إعادة الترتيب الهجين (Hybrid Re-ranking) ──
        # ChromaDB يعيد 'distances' (المسافة: الأقل أفضل).
        # سنحسب نتيجة مركبة: نعطي وزناً للتقارب الدلالي ووزناً للوزن المخزن في metadata.
        import json
        
        doc_ids = results["ids"][0]
        distances = results["distances"][0]
        documents = results["documents"][0]
        metadatas = results["metadatas"][0]
        
        scored_results = []
        
        # إيجاد أعلى مسافة لتطبيع المسافات (Normalization)
        max_dist = max(distances) if distances and max(distances) > 0 else 1.0
        
        for i in range(len(doc_ids)):
            dist = distances[i]
            meta = metadatas[i]
            
            # تقييم الدلالة (Semantic Score): الأعلى أفضل (0 إلى 1)
            semantic_score = 1.0 - (dist / max_dist)
            
            # استخراج وزن الحالة المخزن (Emotion Weight)
            emotion_weight = 0.0
            if "emotion_weights" in meta:
                try:
                    weights = json.loads(meta["emotion_weights"])
                    emotion_weight = float(weights.get(emotion, 0.0))
                except:
                    pass
            
            # النتيجة المركبة: 60% للبحث الدلالي، 40% لوزن الحالة الثابت
            combined_score = (semantic_score * 0.6) + (emotion_weight * 0.4)
            
            scored_results.append({
                "id": doc_ids[i],
                "distance": dist,
                "document": documents[i],
                "metadata": meta,
                "combined_score": combined_score
            })
            
        # ترتيب تنازلي حسب النتيجة المركبة
        scored_results.sort(key=lambda x: x["combined_score"], reverse=True)
        top_results = scored_results[:n_results]
        
        return {
            "ids": [[r["id"] for r in top_results]],
            "distances": [[r["distance"] for r in top_results]],
            "documents": [[r["document"] for r in top_results]],
            "metadatas": [[r["metadata"] for r in top_results]]
        }
