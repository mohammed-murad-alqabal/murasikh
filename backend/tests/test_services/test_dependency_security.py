from pathlib import Path

REQUIREMENTS = Path(__file__).parents[2] / "requirements.txt"


def test_chromadb_is_pinned_before_affected_versions():
    lines = REQUIREMENTS.read_text(encoding="utf-8").splitlines()
    chroma_lines = [
        line.strip() for line in lines if line.strip().lower().startswith("chromadb==")
    ]

    assert chroma_lines == ["chromadb==0.4.16"]


def test_project_uses_embedded_chroma_only():
    source_root = REQUIREMENTS.parents[0] / "app"
    source = "\n".join(
        path.read_text(encoding="utf-8") for path in source_root.rglob("*.py")
    )

    assert "chromadb.HttpClient" not in source
    assert "trust_remote_code" not in source
