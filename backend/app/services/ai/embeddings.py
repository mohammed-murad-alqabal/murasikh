import json
import os
from pathlib import Path

import chromadb
from sentence_transformers import SentenceTransformer


class EmbeddingService:
    def __init__(self):
        default_chroma_path = Path(__file__).resolve().parents[3] / "chroma_db"
        chroma_path = os.environ.get("CHROMA_PATH", str(default_chroma_path))
        self.client = chromadb.PersistentClient(path=chroma_path)
        self.collection = self.client.get_or_create_collection(
            name="islamic_content_minilm",
            metadata={"description": "القرآن", "hnsw:space": "cosine"}
        )
        # استخدام موديل عربي متخصص للملاءمة مع المهام الدينية
        self.model = SentenceTransformer('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2')
        
        # تحميل البصمات التصنيفية للآيات إن وُجدت
        self.fingerprints = {}
        fp_path = os.path.join(os.path.dirname(__file__), "../../../scripts/verse_fingerprints.json")
        if os.path.exists(fp_path):
            try:
                with open(fp_path, "r", encoding="utf-8") as f:
                    self.fingerprints = json.load(f)
            except Exception as e:
                print(f"Warning: Could not load fingerprints: {e}")

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
        
        # استرجاع عدد أكبر إذا كان هناك حالة، لإجراء الترتيب الهجين بناءً على البصمات
        fetch_count = (n_results * 5) if emotion and emotion != "طبيعي" else n_results
        
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=fetch_count,
            where=filters
        )
        
        if not emotion or emotion == "طبيعي" or not results.get('documents') or not results['documents'][0]:
            if results.get('documents') and len(results['documents'][0]) > n_results:
                return {
                    "ids": [results["ids"][0][:n_results]],
                    "distances": [results["distances"][0][:n_results]],
                    "documents": [results["documents"][0][:n_results]],
                    "metadatas": [results["metadatas"][0][:n_results]]
                }
            return results

        # ── إعادة الترتيب الهجين باستخدام البصمات التصنيفية (Fingerprints) ──
        doc_ids = results["ids"][0]
        distances = results["distances"][0]
        documents = results["documents"][0]
        metadatas = results["metadatas"][0]
        
        scored_results = []
        max_dist = max(distances) if distances and max(distances) > 0 else 1.0
        
        for i in range(len(doc_ids)):
            doc_id = doc_ids[i]
            dist = distances[i]
            meta = metadatas[i]
            
            # تقييم الدلالة (Semantic Score): 0.0 إلى 1.0
            semantic_score = 1.0 - (dist / max_dist)
            
            # استخراج وزن الحالة من البصمة التصنيفية في الذاكرة
            emotion_weight = 0.0
            if doc_id in self.fingerprints:
                fp = self.fingerprints[doc_id].get("dimensions", {})
                emotion_weight = float(fp.get(emotion, 0.0))
            
            # النتيجة المركبة: دمج البحث الدلالي مع البصمة
            combined_score = (semantic_score * 0.5) + (emotion_weight * 0.5)
            
            scored_results.append({
                "id": doc_id,
                "distance": dist,
                "document": documents[i],
                "metadata": meta,
                "combined_score": combined_score
            })
            
        # ترتيب تنازلي
        scored_results.sort(key=lambda x: x["combined_score"], reverse=True)
        top_results = scored_results[:n_results]
        
        return {
            "ids": [[r["id"] for r in top_results]],
            "distances": [[r["distance"] for r in top_results]],
            "documents": [[r["document"] for r in top_results]],
            "metadatas": [[r["metadata"] for r in top_results]]
        }
