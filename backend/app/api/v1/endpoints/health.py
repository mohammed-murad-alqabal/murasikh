"""Operational health endpoints with a lightweight liveness check."""

from __future__ import annotations

import asyncio
from typing import Any

import chromadb
from fastapi import APIRouter, Response, status
from redis import Redis
from sqlalchemy import text

from app.core.config import settings
from app.db.database import engine

router = APIRouter()


def _check_database() -> None:
    with engine.connect() as connection:
        connection.execute(text("SELECT 1"))


def _check_redis() -> None:
    if not settings.REDIS_URL:
        raise RuntimeError("REDIS_URL is not configured")
    client = Redis.from_url(
        settings.REDIS_URL, socket_connect_timeout=1, socket_timeout=1
    )
    try:
        if client.ping() is not True:
            raise RuntimeError("Redis ping failed")
    finally:
        client.close()


def _check_chroma() -> None:
    client = chromadb.PersistentClient(path=settings.CHROMA_PATH)
    collection = client.get_collection("islamic_content_minilm")
    if collection.count() != 6236:
        raise RuntimeError("Quran Chroma collection is incomplete")


@router.get("/health/live")
async def liveness() -> dict[str, str]:
    return {"status": "ok"}


@router.get("/health/ready")
async def readiness(response: Response) -> dict[str, Any]:
    checks: dict[str, str] = {}
    checks_to_run = {
        "database": _check_database,
        "redis": _check_redis,
        "chroma": _check_chroma,
    }
    results = await asyncio.gather(
        *(asyncio.to_thread(check) for check in checks_to_run.values()),
        return_exceptions=True,
    )
    for name, result in zip(checks_to_run, results):
        checks[name] = "ok" if not isinstance(result, Exception) else "failed"

    ready = all(value == "ok" for value in checks.values())
    if not ready:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return {"status": "ok" if ready else "not_ready", "checks": checks}


@router.get("/health")
async def health_alias(response: Response) -> dict[str, Any]:
    return {"status": "ok"}


__all__ = ["router"]
