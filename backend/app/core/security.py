import os
import ipaddress

from slowapi import Limiter
from slowapi.util import get_remote_address

from app.core.config import settings


def get_real_ip(request):
    """Use forwarded IP only when the direct peer is a trusted proxy."""
    peer = request.client.host if request.client else ""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded and _is_trusted_proxy(peer):
        return forwarded.split(",")[0].strip()
    return get_remote_address(request)


def _is_trusted_proxy(peer: str) -> bool:
    try:
        address = ipaddress.ip_address(peer)
    except ValueError:
        return False
    return any(
        address in ipaddress.ip_network(network)
        for network in settings.trusted_proxy_networks
    )


redis_url = os.environ.get("REDIS_URL") or settings.REDIS_URL

if redis_url:
    limiter = Limiter(key_func=get_real_ip, storage_uri=redis_url)
else:
    limiter = Limiter(key_func=get_real_ip)
