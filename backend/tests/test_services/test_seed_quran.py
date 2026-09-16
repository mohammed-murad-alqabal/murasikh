import sys
import types

from scripts import seed_quran


class FakeCollection:
    def __init__(self):
        self.records = {}
        self.upsert_calls = 0

    def count(self):
        return len(self.records)

    def get(self, include=None):
        ids = list(self.records)
        return {
            "ids": ids,
            "metadatas": [self.records[item_id]["metadata"] for item_id in ids],
        }

    def upsert(self, ids, embeddings, documents, metadatas):
        self.upsert_calls += 1
        for record_id, embedding, document, metadata in zip(
            ids, embeddings, documents, metadatas
        ):
            self.records[record_id] = {
                "embedding": embedding,
                "document": document,
                "metadata": metadata,
            }


class FakeClient:
    def __init__(self):
        self.collection = FakeCollection()
        self.deleted = 0

    def get_or_create_collection(self, name, metadata):
        return self.collection

    def delete_collection(self, name):
        self.deleted += 1
        self.collection = FakeCollection()


class FakeModel:
    calls = 0

    def __init__(self, name):
        self.name = name

    def encode(self, texts, show_progress_bar=False):
        FakeModel.calls += 1
        return FakeEmbeddings([[0.1, 0.2, 0.3] for _ in texts])


class FakeEmbeddings:
    def __init__(self, values):
        self.values = values

    def tolist(self):
        return self.values


def test_load_verses_contract():
    verses = seed_quran.load_verses()

    assert len(verses) == seed_quran.EXPECTED_VERSE_COUNT
    assert len({verse["id"] for verse in verses}) == seed_quran.EXPECTED_VERSE_COUNT
    assert all(verse["metadata"]["type"] == "verse" for verse in verses)


def test_seed_quran_rebuilds_incomplete_collection_and_is_idempotent(monkeypatch):
    fake_client = FakeClient()
    monkeypatch.setattr(seed_quran.chromadb, "PersistentClient", lambda path: fake_client)
    monkeypatch.setitem(
        sys.modules,
        "sentence_transformers",
        types.SimpleNamespace(SentenceTransformer=FakeModel),
    )
    FakeModel.calls = 0

    seed_quran.seed_quran(batch_size=2048)
    assert fake_client.collection.count() == seed_quran.EXPECTED_VERSE_COUNT
    assert fake_client.deleted == 0
    first_model_calls = FakeModel.calls

    seed_quran.seed_quran(batch_size=2048)
    assert fake_client.collection.count() == seed_quran.EXPECTED_VERSE_COUNT
    assert FakeModel.calls == first_model_calls


def test_verify_collection_rejects_non_verse_records():
    collection = FakeCollection()
    collection.records = {
        "verse_1:1": {"metadata": {"type": "verse"}},
        "hadith_1": {"metadata": {"type": "hadith"}},
    }

    try:
        seed_quran.verify_collection(collection, seed_quran.load_verses())
    except RuntimeError as exc:
        assert "expected" in str(exc) or "IDs" in str(exc)
    else:
        raise AssertionError("Expected invalid collection verification to fail")
