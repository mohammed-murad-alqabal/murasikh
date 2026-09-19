import pytest
from scripts.benchmark_semantic_rag import percentile_ms, summarize


def test_percentile_ms_is_deterministic():
    assert percentile_ms([0.001, 0.002, 0.003, 0.004], 0.95) == pytest.approx(4.0)


def test_benchmark_summary_contains_operational_metrics():
    summary = summarize([0.001, 0.002, 0.003])

    assert summary["count"] == 3
    assert summary["p50_ms"] == pytest.approx(2.0)
    assert summary["p95_ms"] == pytest.approx(3.0)
    assert summary["throughput_per_second"] > 0
