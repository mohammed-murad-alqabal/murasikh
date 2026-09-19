"""Benchmark the production embedding + Chroma + local RAG path.

This is intentionally opt-in and is not part of CI. It requires a seeded
Chroma collection and downloads/loads the real SentenceTransformer model.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import os
import statistics
import time
from pathlib import Path

from app.services.ai.embeddings import EmbeddingService
from app.services.ai.rag_engine import RAGEngine

DEFAULT_QUERIES = [
    ("أشعر بالحزن وأحتاج إلى السكينة", "حزن"),
    ("أشعر بالقلق من المستقبل", "قلق"),
    ("أحتاج إلى الصبر بعد المصيبة", "حزن"),
    ("أشعر بالتوتر وأريد الطمأنينة", "توتر"),
]


def percentile_ms(samples: list[float], percentile: float) -> float:
    ordered = sorted(samples)
    if not ordered:
        return 0.0
    index = min(len(ordered) - 1, max(0, math.ceil(len(ordered) * percentile) - 1))
    return ordered[index] * 1000


def summarize(samples: list[float]) -> dict[str, float]:
    return {
        "count": len(samples),
        "min_ms": round(min(samples) * 1000, 3),
        "mean_ms": round(statistics.mean(samples) * 1000, 3),
        "p50_ms": round(percentile_ms(samples, 0.50), 3),
        "p95_ms": round(percentile_ms(samples, 0.95), 3),
        "p99_ms": round(percentile_ms(samples, 0.99), 3),
        "throughput_per_second": round(len(samples) / sum(samples), 3),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Benchmark the real SentenceTransformer, Chroma and local RAG path"
    )
    parser.add_argument("--iterations", type=int, default=30)
    parser.add_argument("--warmup", type=int, default=3)
    parser.add_argument(
        "--results", type=Path, default=Path("perf-results/semantic-rag-real.json")
    )
    parser.add_argument("--n-results", type=int, default=5)
    parser.add_argument("--min-count", type=int, default=6236)
    return parser


async def run_benchmark(args: argparse.Namespace) -> dict:
    if args.iterations <= 0 or args.warmup < 0 or args.n_results <= 0:
        raise ValueError(
            "iterations, n-results and warmup must be positive/non-negative"
        )

    service = EmbeddingService()
    collection_count = service.collection.count()
    if collection_count < args.min_count:
        raise RuntimeError(
            f"Chroma collection has {collection_count} records; expected at least {args.min_count}. "
            "Run scripts/seed_quran.py first."
        )

    rag = RAGEngine()
    # Keep the benchmark deterministic and offline after real retrieval.
    rag._gemini_available = False

    for index in range(args.warmup):
        query, emotion = DEFAULT_QUERIES[index % len(DEFAULT_QUERIES)]
        service.search_similar(
            query=query,
            n_results=args.n_results,
            filters={"type": "verse"},
            emotion=emotion,
        )

    search_samples: list[float] = []
    rag_samples: list[float] = []
    for index in range(args.iterations):
        query, emotion = DEFAULT_QUERIES[index % len(DEFAULT_QUERIES)]
        started = time.perf_counter()
        result = service.search_similar(
            query=query,
            n_results=args.n_results,
            filters={"type": "verse"},
            emotion=emotion,
        )
        search_samples.append(time.perf_counter() - started)

        verses = [
            {
                "text": result["documents"][0][position],
                "source": result["metadatas"][0][position].get("source", ""),
                "tafsir": result["metadatas"][0][position].get("tafsir", ""),
            }
            for position in range(len(result.get("documents", [[]])[0]))
        ]
        started = time.perf_counter()
        await rag.select_best_verse(query, emotion, verses)
        rag_samples.append(time.perf_counter() - started)

    return {
        "model": "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
        "chroma_path": os.environ.get("CHROMA_PATH", "backend/chroma_db"),
        "collection": service.collection.name,
        "collection_count": collection_count,
        "iterations": args.iterations,
        "n_results": args.n_results,
        "search": summarize(search_samples),
        "rag_local_selection": summarize(rag_samples),
    }


def main() -> int:
    args = build_parser().parse_args()
    results = asyncio.run(run_benchmark(args))
    args.results.parent.mkdir(parents=True, exist_ok=True)
    args.results.write_text(
        json.dumps(results, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(results, ensure_ascii=False, indent=2))
    print(f"Saved benchmark results to {args.results}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
