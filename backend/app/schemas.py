from typing import Literal, Optional

from pydantic import BaseModel, EmailStr, Field

Role = Literal["web3", "ai", "both"]
Source = Literal["landing", "market-map", "agents", "footer", "other"]


class WaitlistSignup(BaseModel):
    """Inbound payload for `POST /api/waitlist`."""

    email: EmailStr
    role: Optional[Role] = None
    source: Source = "landing"
    # Honeypot — must be empty. Bots will fill it.
    company: Optional[str] = Field(default="", max_length=0)


class WaitlistResponse(BaseModel):
    ok: bool
    lead_id: Optional[str] = None


class HealthResponse(BaseModel):
    ok: bool
    service: str = "canhav-backend"
    instantly_configured: bool
    supabase_configured: bool = False
