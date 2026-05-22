from __future__ import annotations

import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routes.market_map import router as market_map_router
from app.routes.waitlist import router as waitlist_router
from app.schemas import HealthResponse
from app.services.instantly import is_configured as instantly_configured
from app.services.supabase import aclose as supabase_aclose
from app.services.supabase import is_configured as supabase_configured

load_dotenv()

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)


@asynccontextmanager
async def lifespan(_: FastAPI):
    try:
        yield
    finally:
        await supabase_aclose()


app = FastAPI(
    title="CanHav Backend",
    description="Backend API for canhav.com — waitlist + future agent marketplace endpoints.",
    version="0.1.0",
    lifespan=lifespan,
)


def _allowed_origins() -> list[str]:
    raw = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000")
    return [origin.strip() for origin in raw.split(",") if origin.strip()]


app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins(),
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

app.include_router(waitlist_router)
app.include_router(market_map_router)


@app.get("/", include_in_schema=False)
async def root() -> dict[str, str]:
    return {"service": "canhav-backend", "docs": "/docs"}


@app.get("/api/health", response_model=HealthResponse, tags=["meta"])
async def health() -> HealthResponse:
    return HealthResponse(
        ok=True,
        instantly_configured=instantly_configured(),
        supabase_configured=supabase_configured(),
    )
