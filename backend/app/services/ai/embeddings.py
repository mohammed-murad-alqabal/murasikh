import chromadb
from chromadb.config import Settings

class EmbeddingService:
    def __init__(self):
        self.client = chromadb.Client(Settings(
            persist_directory="./chroma_db"
        ))
        self.collection = self.client.get_or_create_collection(
            name="islamic_content",
            metadata={"description": "القرآن والأحاديث والتفاسير"}
        )
        
    def store_embedding(self, doc_id: str, text: str, embedding: list, metadata: dict):
        self.collection.add(
            ids=[doc_id],
            embeddings=[embedding],
            documents=[text],
            metadatas=[metadata]
        )
