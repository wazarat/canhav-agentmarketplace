"""Thin client for the Instantly.ai v2 leads API.

Docs: https://developer.instantly.ai/api-reference/lead/create-lead
"""

from __future__ import annotations

import logging
import os
from typing import Any, Dict, Optional

import httpx

logger = logging.getLogger(__name__)

INSTANTLY_BASE_URL = "https://api.instantly.ai/api/v2"


class InstantlyError(Exception):
    """Raised when Instantly returns a non-2xx response or is unreachable."""

    def __init__(self, message: str, *, status_code: Optional[int] = None, body: Any = None) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.body = body


def is_configured() -> bool:
    return bool(os.getenv("INSTANTLY_API_KEY"))


async def add_lead(
    email: str,
    *,
    custom_variables: Optional[Dict[str, Any]] = None,
    timeout_seconds: float = 10.0,
) -> Dict[str, Any]:
    """Create a lead in the configured Instantly campaign.

    Returns the parsed JSON body on success. Raises InstantlyError on failure.
    """
    api_key = os.getenv("INSTANTLY_API_KEY")
    campaign_id = os.getenv("INSTANTLY_CAMPAIGN_ID")

    if not api_key:
        raise InstantlyError("INSTANTLY_API_KEY is not set")
    if not campaign_id:
        raise InstantlyError("INSTANTLY_CAMPAIGN_ID is not set")

    payload: Dict[str, Any] = {
        "email": email,
        "campaign": campaign_id,
        # Don't double-add the same lead if they're already in the workspace.
        "skip_if_in_workspace": True,
    }
    if custom_variables:
        payload["custom_variables"] = custom_variables

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    url = f"{INSTANTLY_BASE_URL}/leads"

    try:
        async with httpx.AsyncClient(timeout=timeout_seconds) as client:
            response = await client.post(url, json=payload, headers=headers)
    except httpx.HTTPError as exc:
        logger.exception("Instantly request failed: %s", exc)
        raise InstantlyError(f"Network error talking to Instantly: {exc}") from exc

    if response.status_code >= 400:
        try:
            body = response.json()
        except Exception:
            body = response.text
        logger.warning("Instantly returned %s: %s", response.status_code, body)
        raise InstantlyError(
            f"Instantly returned {response.status_code}",
            status_code=response.status_code,
            body=body,
        )

    try:
        return response.json()
    except Exception as exc:
        raise InstantlyError(f"Could not parse Instantly response: {exc}") from exc
