from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException, status

from app.schemas import WaitlistResponse, WaitlistSignup
from app.services.instantly import InstantlyError, add_lead

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["waitlist"])


@router.post(
    "/waitlist",
    response_model=WaitlistResponse,
    status_code=status.HTTP_200_OK,
)
async def join_waitlist(payload: WaitlistSignup) -> WaitlistResponse:
    # Honeypot — if the hidden `company` field was filled, silently 200 like a real signup.
    if payload.company:
        logger.info("Honeypot tripped for %s", payload.email)
        return WaitlistResponse(ok=True)

    custom_variables = {
        "source": payload.source,
    }
    if payload.role:
        custom_variables["role"] = payload.role

    try:
        result = await add_lead(payload.email, custom_variables=custom_variables)
    except InstantlyError as exc:
        # Treat duplicate-skip and similar 4xx as a soft success so we don't punish
        # a returning visitor or leak info to bots.
        if exc.status_code and 400 <= exc.status_code < 500:
            logger.info(
                "Instantly soft-rejected lead %s (%s): %s",
                payload.email,
                exc.status_code,
                exc.body,
            )
            return WaitlistResponse(ok=True)

        logger.error("Instantly upstream error for %s: %s", payload.email, exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Could not reach our email provider. Please try again shortly.",
        ) from exc

    lead_id = None
    if isinstance(result, dict):
        lead_id = result.get("id") or result.get("lead_id")

    return WaitlistResponse(ok=True, lead_id=lead_id)
