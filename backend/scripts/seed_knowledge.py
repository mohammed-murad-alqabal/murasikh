"""Deprecated compatibility entry point for Quran-only knowledge seeding.

The old script mixed Quran verses with a sample hadith. That behavior is no
longer allowed. Use ``scripts/seed_quran.py`` to build the production index.
"""

from __future__ import annotations

import sys


def seed_database() -> None:
    raise RuntimeError(
        "seed_knowledge.py no longer accepts curated mixed content. "
        "Run `python scripts/seed_quran.py` to seed the Quran-only collection."
    )


def main() -> int:
    print(
        "This command is deprecated because mixed Quran/Hadith seeding violates "
        "the Quran-only retrieval policy."
    )
    print("Use: python scripts/seed_quran.py")
    return 2


if __name__ == "__main__":
    sys.exit(main())
