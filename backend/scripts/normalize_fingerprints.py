"""Normalize existing verse fingerprints to the canonical taxonomy schema."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.taxonomy import EMOTION_TAXONOMY

SCRIPT_DIR = Path(__file__).resolve().parent
FINGERPRINTS_FILE = SCRIPT_DIR / "verse_fingerprints.json"
EXPECTED_DIMENSIONS = len(EMOTION_TAXONOMY)
EXPECTED_VERSES = 6236


def normalize(data: dict) -> dict:
    normalized: dict = {}
    for verse_id, fingerprint in data.items():
        raw = fingerprint.get("dimensions", {}) if isinstance(fingerprint, dict) else {}
        dimensions = {
            emotion: round(max(float(raw.get(emotion, 0.0)), 0.0), 4)
            for emotion in EMOTION_TAXONOMY
        }
        primary = max(dimensions, key=dimensions.get) if dimensions else "غير محدد"
        normalized[verse_id] = {
            "dimensions": dimensions,
            "signature": (
                fingerprint.get("signature")
                if isinstance(fingerprint, dict) and fingerprint.get("signature")
                else f"صُنفت ضمن '{primary}' بناءً على التقارب الدلالي النصي"
            ),
        }
    return normalized


def validate(data: dict) -> None:
    if len(data) != EXPECTED_VERSES:
        raise ValueError(f"Expected {EXPECTED_VERSES} fingerprints, found {len(data)}")
    for verse_id, fingerprint in data.items():
        dimensions = fingerprint.get("dimensions", {})
        if len(dimensions) != EXPECTED_DIMENSIONS:
            raise ValueError(
                f"{verse_id} has {len(dimensions)} dimensions; expected {EXPECTED_DIMENSIONS}"
            )
        if set(dimensions) != set(EMOTION_TAXONOMY):
            raise ValueError(f"{verse_id} dimensions do not match taxonomy")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="validate without changing the file")
    args = parser.parse_args()

    with FINGERPRINTS_FILE.open("r", encoding="utf-8") as handle:
        current = json.load(handle)
    normalized = normalize(current)
    validate(normalized)

    if args.check:
        print(
            f"Fingerprint schema verified: verses={len(normalized)}, "
            f"dimensions={EXPECTED_DIMENSIONS}"
        )
        return 0

    temporary = FINGERPRINTS_FILE.with_suffix(".json.tmp")
    with temporary.open("w", encoding="utf-8") as handle:
        json.dump(normalized, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    temporary.replace(FINGERPRINTS_FILE)
    print(
        f"Fingerprint schema normalized: verses={len(normalized)}, "
        f"dimensions={EXPECTED_DIMENSIONS}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
