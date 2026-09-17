import pytest
from app.core.taxonomy import (
    get_taxonomy_keys,
    build_semantic_query,
    EMOTION_TAXONOMY
)

def test_get_taxonomy_keys():
    """Test that get_taxonomy_keys returns all keys from EMOTION_TAXONOMY."""
    keys = get_taxonomy_keys()
    assert isinstance(keys, list)
    assert len(keys) == len(EMOTION_TAXONOMY)
    assert set(keys) == set(EMOTION_TAXONOMY.keys())
    assert "توحيد" in keys
    assert "قنوط" in keys

def test_build_semantic_query_with_antidote():
    """Test building a query for an emotion that has an explicit antidote."""
    # "قنوط" is in the antidotes dictionary
    query = build_semantic_query("قنوط")
    assert "آيات القرآن الكريم عن" in query
    assert "لا تقنطوا من رحمة الله" in query

def test_build_semantic_query_with_taxonomy_description():
    """Test building a query for an emotion in EMOTION_TAXONOMY but not in antidotes."""
    # "إيمان" is in EMOTION_TAXONOMY but not in antidotes
    query = build_semantic_query("إيمان")
    assert "آيات القرآن الكريم عن إيمان" in query
    assert EMOTION_TAXONOMY["إيمان"] in query

def test_build_semantic_query_unknown_emotion():
    """Test building a query for an unknown emotion (fallback)."""
    # "مجهول" is not in any dictionary
    query = build_semantic_query("مجهول")
    assert query == "آيات القرآن الكريم عن مجهول والصبر والطمأنينة"
