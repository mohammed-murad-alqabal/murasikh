import json
from typing import Any

import redis


class RedisCache:
    def __init__(self, host: str = "localhost", port: int = 6379):
        self.client = redis.Redis(host=host, port=port, decode_responses=True)

    def get(self, key: str) -> Any | None:
        value = self.client.get(key)
        return json.loads(value) if value else None

    def set(self, key: str, value: Any, ttl: int = 3600):
        self.client.setex(key, ttl, json.dumps(value, ensure_ascii=False))

    def cache_recommendation(self, emotion: str, result: dict):
        self.set(f"rec:{emotion}", result, ttl=86400)
