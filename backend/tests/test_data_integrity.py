import json
from pathlib import Path

from app.core.taxonomy import EMOTION_TAXONOMY

BACKEND_DIR = Path(__file__).resolve().parents[1]


def test_quran_dataset_has_expected_verse_count():
    with (BACKEND_DIR / "quran.json").open(encoding="utf-8") as handle:
        quran = json.load(handle)

    verses = [verse for chapter in quran.values() for verse in chapter]
    ids = {f"verse_{verse['chapter']}:{verse['verse']}" for verse in verses}

    assert len(quran) == 114
    assert len(verses) == 6236
    assert len(ids) == 6236
    assert all(verse["text"].strip() for verse in verses)


def test_fingerprints_match_quran_and_taxonomy_schema():
    with (BACKEND_DIR / "scripts/verse_fingerprints.json").open(
        encoding="utf-8"
    ) as handle:
        fingerprints = json.load(handle)
    with (BACKEND_DIR / "quran.json").open(encoding="utf-8") as handle:
        quran = json.load(handle)

    expected_ids = {
        f"verse_{verse['chapter']}:{verse['verse']}"
        for chapter in quran.values()
        for verse in chapter
    }

    assert len(fingerprints) == 6236
    assert set(fingerprints) == expected_ids
    for fingerprint in fingerprints.values():
        assert set(fingerprint["dimensions"]) == set(EMOTION_TAXONOMY)
        assert len(fingerprint["dimensions"]) == 67
        assert all(0.0 <= value <= 1.0 for value in fingerprint["dimensions"].values())


def test_production_seed_path_cannot_insert_hadiths():
    seed_quran = (BACKEND_DIR / "scripts/seed_quran.py").read_text(encoding="utf-8")

    assert '"type": "hadith"' not in seed_quran
    assert "verify_quran_only_collections" in seed_quran


def test_hadith_seed_isolated_and_fails_without_provenance():
    seed_hadiths = (BACKEND_DIR / "scripts/seed_hadiths.py").read_text(
        encoding="utf-8"
    )

    assert "HADITH_CHROMA_PATH" in seed_hadiths
    assert "hadith_content_minilm" in seed_hadiths
    assert "has no source grades" in seed_hadiths
