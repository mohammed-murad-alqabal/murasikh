import chromadb
client = chromadb.PersistentClient(path="./chroma_db")
try:
    collection = client.get_collection("islamic_content")
    print(f"Total documents: {collection.count()}")
    results = collection.get(limit=2)
    print("Sample:", results['documents'])
except Exception as e:
    print(e)
