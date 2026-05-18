"""Thin async client for Supabase PostgREST.

Reads only. Uses the anon key by default; the service-role key is reserved for the ingest
scripts in `.cursor/skills/market-map/scripts/`, never the live web request path.
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


async def get(
    path: str,
    *,
    params: Optional[Dict[str, Any]] = None,
    timeout: float = 10.0,
) -> List[Dict[str, Any]]:
    """GET against PostgREST and return JSON. `path` is e.g. '/rest/v1/projects'."""
    url = f"{_base_url()}{path}"
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.get(url, headers=_headers(), params=params)
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
    timeout: float = 10.0,
) -> Optional[Dict[str, Any]]:
    rows = await get(path, params=params, timeout=timeout)
    if not rows:
        return None
    return rows[0]
