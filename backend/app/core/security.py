import os
from slowapi import Limiter
from slowapi.util import get_remote_address

def get_real_ip(request):
    """Get the real IP address, respecting X-Forwarded-For if set."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)

redis_url = os.environ.get("REDIS_URL")

if redis_url:
    limiter = Limiter(key_func=get_real_ip, storage_uri=redis_url)
else:
    limiter = Limiter(key_func=get_real_ip)
