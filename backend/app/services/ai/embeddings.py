import chromadb
from chromadb.config import Settings
import google.generativeai as genai
from app.core.config import settings

class EmbeddingService:
    def __init__(self):
        self.client = chromadb.PersistentClient(path="./chroma_db")
        self.collection = self.client.get_or_create_collection(
            name="islamic_content",
            metadata={"description": "القرآن والأحاديث والتفاسير"}
        )
        if settings.GEMINI_API_KEY:
            genai.configure(api_key=settings.GEMINI_API_KEY)

    def create_embedding(self, text: str) -> list:
        result = genai.embed_content(
            model="models/gemini-embedding-2",
            content=text
        )
        return result['embedding']
        
    def store_document(self, doc_id: str, text: str, metadata: dict):
        embedding = self.create_embedding(text)
        self.collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[text],
            metadatas=[metadata]
        )

    def search_similar(self, query: str, n_results: int = 3, filters: dict = None):
        query_embedding = self.create_embedding(query)
        results = self.collection.query(
            query_embeddings=[query_embedding],
            n_results=n_results,
            where=filters
        )
        return results
