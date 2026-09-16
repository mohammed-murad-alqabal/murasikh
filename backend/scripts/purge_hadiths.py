import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from app.services.ai.embeddings import EmbeddingService

def purge():
    es = EmbeddingService()
    print("Fetching all items...")
    results = es.collection.get()
    
    ids_to_delete = []
    if results and results.get("ids"):
        ids = results["ids"]
        metas = results["metadatas"]
        for idx, item_id in enumerate(ids):
            meta = metas[idx] if metas else {}
            item_type = meta.get("type", "")
            if item_type == "hadith":
                ids_to_delete.append(item_id)
                
    if ids_to_delete:
        print(f"Found {len(ids_to_delete)} Hadiths to delete.")
        es.collection.delete(ids=ids_to_delete)
        print("Purge complete!")
    else:
        print("No Hadiths found in the database. Vector DB is already clean.")

if __name__ == "__main__":
    purge()
