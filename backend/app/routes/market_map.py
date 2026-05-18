"""Read-only Market Map API. Backed by Supabase PostgREST.

All endpoints under `/api/market-map/`. RLS on Supabase ensures the anon key can only
read; writes happen out-of-band via the ingest scripts using the service-role key.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query, status

from app.services.supabase import SupabaseError, get, get_single, is_configured

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/market-map", tags=["market-map"])


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _require_supabase() -> None:
    if not is_configured():
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Market Map data store is not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY.",
        )


def _map_supabase_error(exc: SupabaseError) -> HTTPException:
    if exc.status_code and 400 <= exc.status_code < 500:
        return HTTPException(status_code=status.HTTP_502_BAD_GATEWAY, detail="Upstream Supabase rejected the query.")
    return HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail="Could not reach the Market Map data store. Please try again shortly.",
    )


# ---------------------------------------------------------------------------
# routes
# ---------------------------------------------------------------------------

@router.get("/sectors")
async def list_sectors() -> List[Dict[str, Any]]:
    """All sectors with subsector + project counts. Driven by the sector_summary view."""
    _require_supabase()
    try:
        rows = await get(
            "/rest/v1/sector_summary",
            params={"select": "*", "order": "sector_display_order.asc"},
        )
    except SupabaseError as exc:
        logger.error("sectors list failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc
    return rows


@router.get("/sectors/{sector_slug}")
async def get_sector(sector_slug: str) -> Dict[str, Any]:
    """A sector + its subsectors (with counts)."""
    _require_supabase()
    try:
        sector = await get_single(
            "/rest/v1/sectors",
            params={
                "slug": f"eq.{sector_slug}",
                "select": "slug,name,description,display_order,common_field_schema",
            },
        )
        if sector is None:
            raise HTTPException(status_code=404, detail=f"Sector not found: {sector_slug}")

        subsectors = await get(
            "/rest/v1/subsector_summary",
            params={
                "sector_slug": f"eq.{sector_slug}",
                "select": "*",
                "order": "subsector_display_order.asc",
            },
        )
    except SupabaseError as exc:
        logger.error("sector get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    return {**sector, "subsectors": subsectors}


@router.get("/subsectors/{subsector_slug}")
async def get_subsector(subsector_slug: str) -> Dict[str, Any]:
    """A subsector + its parent sector + its specific_field_schema."""
    _require_supabase()
    try:
        sub = await get_single(
            "/rest/v1/subsectors",
            params={
                "slug": f"eq.{subsector_slug}",
                "select": "slug,sector_slug,name,description,display_order,specific_field_schema,source_sheet_id,source_sheet_gid",
            },
        )
        if sub is None:
            raise HTTPException(status_code=404, detail=f"Subsector not found: {subsector_slug}")

        sector = await get_single(
            "/rest/v1/sectors",
            params={
                "slug": f"eq.{sub['sector_slug']}",
                "select": "slug,name,common_field_schema",
            },
        )
    except SupabaseError as exc:
        logger.error("subsector get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    return {**sub, "sector": sector}


@router.get("/subsectors/{subsector_slug}/projects")
async def list_subsector_projects(
    subsector_slug: str,
    limit: int = Query(default=200, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> List[Dict[str, Any]]:
    _require_supabase()
    try:
        rows = await get(
            "/rest/v1/projects",
            params={
                "subsector_slug": f"eq.{subsector_slug}",
                "select": "*",
                "order": "name.asc",
                "limit": str(limit),
                "offset": str(offset),
            },
        )
    except SupabaseError as exc:
        logger.error("subsector projects failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc
    return rows


@router.get("/projects")
async def list_projects(
    sector: Optional[str] = None,
    subsector: Optional[str] = None,
    search: Optional[str] = None,
    stage: Optional[str] = None,
    status_filter: Optional[str] = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> List[Dict[str, Any]]:
    _require_supabase()
    params: Dict[str, str] = {
        "select": "*",
        "order": "name.asc",
        "limit": str(limit),
        "offset": str(offset),
    }
    if sector:
        params["sector_slug"] = f"eq.{sector}"
    if subsector:
        params["subsector_slug"] = f"eq.{subsector}"
    if stage:
        params["stage"] = f"eq.{stage}"
    if status_filter:
        params["status"] = f"eq.{status_filter}"
    if search:
        params["name"] = f"ilike.*{search}*"

    try:
        rows = await get("/rest/v1/projects", params=params)
    except SupabaseError as exc:
        logger.error("projects list failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc
    return rows


@router.get("/projects/{slug}")
async def get_project(slug: str) -> Dict[str, Any]:
    _require_supabase()
    try:
        project = await get_single(
            "/rest/v1/projects",
            params={"slug": f"eq.{slug}", "select": "*"},
        )
        if project is None:
            raise HTTPException(status_code=404, detail=f"Project not found: {slug}")

        sector = await get_single(
            "/rest/v1/sectors",
            params={"slug": f"eq.{project['sector_slug']}", "select": "slug,name,common_field_schema"},
        )
        subsector = await get_single(
            "/rest/v1/subsectors",
            params={
                "slug": f"eq.{project['subsector_slug']}",
                "select": "slug,name,specific_field_schema",
            },
        )
    except SupabaseError as exc:
        logger.error("project get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    return {**project, "sector": sector, "subsector": subsector}
