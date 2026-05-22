"""Thin async client for Supabase PostgREST.

Reads only. Uses the anon key by default; the service-role key is reserved for the ingest
scripts in `.cursor/skills/market-map/scripts/`, never the live web request path.

A single module-level `httpx.AsyncClient` is reused across requests so we keep TLS
connections alive to Supabase — rebuilding the client per call (the previous behavior)
added ~100-300 ms of handshake latency to every Market Map hit and was the dominant
source of perceived slowness.
"""
from __future__ import annotations

import logging
import os
from typing import Any, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)


class SupabaseError(Exception):
    def __init__(self, message: str, *, status_code: Optional[int] = None, body: Any = None) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.body = body


def is_configured() -> bool:
    return bool(os.getenv("SUPABASE_URL") and os.getenv("SUPABASE_ANON_KEY"))


def _base_url() -> str:
    url = os.getenv("SUPABASE_URL")
    if not url:
        raise SupabaseError("SUPABASE_URL is not set")
    return url.rstrip("/")


def _headers() -> Dict[str, str]:
    key = os.getenv("SUPABASE_ANON_KEY")
    if not key:
        raise SupabaseError("SUPABASE_ANON_KEY is not set")
    return {
        "apikey": key,
        "Authorization": f"Bearer {key}",
        "Accept": "application/json",
    }


# ---------------------------------------------------------------------------
# Shared async client (keep-alive)
# ---------------------------------------------------------------------------

_client: Optional[httpx.AsyncClient] = None


def _get_client() -> httpx.AsyncClient:
    """Lazily build the shared client. Reads SUPABASE_URL at first call so tests can
    monkeypatch env vars before the first request."""
    global _client
    if _client is None:
        _client = httpx.AsyncClient(
            base_url=_base_url(),
            headers=_headers(),
            timeout=httpx.Timeout(10.0, connect=5.0),
            limits=httpx.Limits(
                max_keepalive_connections=20,
                max_connections=40,
                keepalive_expiry=30.0,
            ),
        )
    return _client


async def aclose() -> None:
    """Close the shared client. Wire this to the FastAPI shutdown lifespan."""
    global _client
    if _client is not None:
        await _client.aclose()
        _client = None


async def get(
    path: str,
    *,
    params: Optional[Dict[str, Any]] = None,
    timeout: Optional[float] = None,
) -> List[Dict[str, Any]]:
    """GET against PostgREST and return JSON. `path` is e.g. '/rest/v1/projects'."""
    client = _get_client()
    request_kwargs: Dict[str, Any] = {"params": params}
    if timeout is not None:
        request_kwargs["timeout"] = timeout
    try:
        response = await client.get(path, **request_kwargs)
    except httpx.HTTPError as exc:
        logger.exception("Supabase request failed: %s", exc)
        raise SupabaseError(f"Network error talking to Supabase: {exc}") from exc

    if response.status_code >= 400:
        try:
            body = response.json()
        except Exception:
            body = response.text
        raise SupabaseError(
            f"Supabase returned {response.status_code}",
            status_code=response.status_code,
            body=body,
        )

    try:
        return response.json()
    except Exception as exc:
        raise SupabaseError(f"Could not parse Supabase response: {exc}") from exc


async def get_single(
    path: str,
    *,
    params: Optional[Dict[str, Any]] = None,
    timeout: Optional[float] = None,
) -> Optional[Dict[str, Any]]:
    rows = await get(path, params=params, timeout=timeout)
    if not rows:
        return None
    return rows[0]
