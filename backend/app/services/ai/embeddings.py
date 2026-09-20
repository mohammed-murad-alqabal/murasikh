import functools
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
            metadata={"description": "القرآن", "hnsw:space": "cosine"},
        )
        # استخدام موديل عربي متخصص للملاءمة مع المهام الدينية
        self.model = SentenceTransformer(
            "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
        )

        # تحميل البصمات التصنيفية للآيات إن وُجدت
        self.fingerprints = {}
        fp_path = os.path.join(
            os.path.dirname(__file__), "../../../scripts/verse_fingerprints.json"
        )
        if os.path.exists(fp_path):
            try:
                with open(fp_path, "r", encoding="utf-8") as f:
                    self.fingerprints = json.load(f)
            except Exception as e:
                print(f"Warning: Could not load fingerprints: {e}")

        @functools.lru_cache(maxsize=512)
        def cached_encode(text_to_encode: str) -> list:
            return self.model.encode(text_to_encode).tolist()

        self._cached_encode = cached_encode

    def create_embedding(self, text: str) -> list:
        # Generate the embedding and convert to list of floats for ChromaDB
        return self._cached_encode(text)

    def store_document(self, doc_id: str, text: str, metadata: dict):
        embedding = self.create_embedding(text)
        self.collection.add(
            ids=[doc_id], embeddings=[embedding], documents=[text], metadatas=[metadata]
        )

    def search_similar(
        self,
        query: str,
        n_results: int = 3,
        filters: dict | None = None,
        emotion: str | None = None,
    ):
        query_embedding = self.create_embedding(query)

        # استرجاع عدد أكبر إذا كان هناك حالة، لإجراء الترتيب الهجين بناءً على البصمات
        fetch_count = (n_results * 5) if emotion and emotion != "طبيعي" else n_results

        # ابحث دائماً أولاً في الآيات المُصنّفة يدوياً
        curated_results = None
        try:
            curated_filter = {"is_curated": True}
            if filters:
                # دمج الفلترات مع is_curated
                curated_filter = {
                    "$and": [{k: v} for k, v in {**filters, "is_curated": True}.items()]
                }
            curated_results = self.collection.query(
                query_embeddings=[query_embedding],
                n_results=min(n_results, 5),
                where=curated_filter,
            )
        except Exception:
            curated_results = None

        results = self.collection.query(
            query_embeddings=[query_embedding], n_results=fetch_count, where=filters
        )

        # دمج نتائج الآيات المُصنّفة مع النتائج العامة
        if (
            curated_results
            and curated_results.get("documents")
            and curated_results["documents"][0]
        ):
            # دمج الـ IDs لتجنب التكرار
            seen_ids = set(results["ids"][0])
            for i, cid in enumerate(curated_results["ids"][0]):
                if cid not in seen_ids:
                    seen_ids.add(cid)
                    results["ids"][0].insert(0, cid)  # إضافة في البداية لتأخذ الأولوية
                    results["distances"][0].insert(
                        0, curated_results["distances"][0][i] * 0.7
                    )
                    results["documents"][0].insert(
                        0, curated_results["documents"][0][i]
                    )
                    results["metadatas"][0].insert(
                        0, curated_results["metadatas"][0][i]
                    )

        if (
            not emotion
            or emotion == "طبيعي"
            or not results.get("documents")
            or not results["documents"][0]
        ):
            if results.get("documents") and len(results["documents"][0]) > n_results:
                return {
                    "ids": [results["ids"][0][:n_results]],
                    "distances": [results["distances"][0][:n_results]],
                    "documents": [results["documents"][0][:n_results]],
                    "metadatas": [results["metadatas"][0][:n_results]],
                }
            return results

        return self._rerank_results(results, n_results=n_results, emotion=emotion)

    def _rerank_results(self, results: dict, n_results: int, emotion: str) -> dict:
        """Apply deterministic semantic + fingerprint ranking to Chroma results."""
        doc_ids = results["ids"][0]
        distances = results["distances"][0]
        documents = results["documents"][0]
        metadatas = results["metadatas"][0]

        scored_results = []
        max_dist = max(distances, default=0.0)

        for i in range(len(doc_ids)):
            doc_id = doc_ids[i]
            dist = distances[i]
            meta = metadatas[i]

            # تقييم الدلالة (Semantic Score): 0.0 إلى 1.0
            semantic_score = 1.0 if max_dist == 0 else 1.0 - (dist / max_dist)

            # استخراج وزن الحالة من البصمة التصنيفية في الذاكرة
            emotion_weight = 0.0
            if doc_id in self.fingerprints:
                fp = self.fingerprints[doc_id].get("dimensions", {})
                emotion_weight = float(fp.get(emotion, 0.0))

            # النتيجة المركبة: دمج البحث الدلالي مع البصمة
            combined_score = (semantic_score * 0.5) + (emotion_weight * 0.5)

            scored_results.append(
                {
                    "id": doc_id,
                    "distance": dist,
                    "document": documents[i],
                    "metadata": meta,
                    "combined_score": combined_score,
                }
            )

            # مكافأة الآيات المُصنّفة يدوياً ذات التفسير (تُعطى أولوية أعلى)
            is_curated = meta.get("is_curated", False)
            emotion_tag = meta.get("emotion_tag", "")
            if is_curated and emotion_tag == emotion:
                scored_results[-1]["combined_score"] += 0.35
            elif is_curated and meta.get("tafsir"):
                scored_results[-1]["combined_score"] += 0.15

        # ترتيب تنازلي
        scored_results.sort(key=lambda x: x["combined_score"], reverse=True)
        top_results = scored_results[:n_results]

        return {
            "ids": [[r["id"] for r in top_results]],
            "distances": [[r["distance"] for r in top_results]],
            "documents": [[r["document"] for r in top_results]],
            "metadatas": [[r["metadata"] for r in top_results]],
        }
