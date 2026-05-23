"""Read-only Market Map API. Backed by Supabase PostgREST.

All endpoints under `/api/market-map/`. RLS on Supabase ensures the anon key can only
read; writes happen out-of-band via the ingest scripts using the service-role key.
"""
from __future__ import annotations

import asyncio
import logging
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query, Response, status

from app.services.supabase import SupabaseError, get, get_single, is_configured

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/market-map", tags=["market-map"])


# ---------------------------------------------------------------------------
# Subsector view registry (sector-agnostic).
#
# Some subsectors store enrichment in 1:1 sidecar tables exposed via Postgres
# `*_full_view` views. The frontend project page only renders the
# `sector_attributes` / `subsector_attributes` JSONB on `public.projects`,
# so without this projection the page shows only ~6-9 fields per project
# versus 20+ for sectors that write straight into JSONB. The registry below
# is keyed by `subsector_slug`: any subsector that ships a sidecar view just
# adds one entry here and the merge happens automatically.
#
# History: originally hard-coded to Sector 2 (Rollup & Scaling Frameworks)
# as `SECTOR2_VIEWS` / `SECTOR2_VIEW_STRIP` / `SECTOR2_VIEW_TO_SECTOR_ATTRS`.
# Generalized in M8.16 ahead of Sector 5 (Data & Consensus Infrastructure)
# because that sector ships 5 sidecars and a per-sector patch would have been
# the same antipattern. See plan `sector_5_data_consensus_ingest`.
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class SubsectorViewSpec:
    """Wiring for one subsector's `*_full_view` -> JSONB projection.

    `view_name` is the Postgres view to fetch by `project_id`. `sector_attr_keys`
    are columns that should land in `sector_attributes` (sector-wide typed cols
    on `public.projects`) rather than `subsector_attributes`. Everything else
    in the view (after stripping common universal + schema-passthrough columns)
    lands in `subsector_attributes`.
    """

    view_name: str
    sector_attr_keys: frozenset[str] = field(default_factory=frozenset)


# Columns that live on `public.projects` or `public.organizations` already and
# should never be merged back into JSONB. Common to every subsector view.
_VIEW_STRIP_COMMON: set[str] = {
    "project_id",
    "slug",
    "display_name",
    "description",
    "website_url",
    "logo_url",
    "twitter_handle",
    "github_url",
    "status",
    "sector_slug",
    "subsector_slug",
    "is_aggregate",
    "not_applicable_reason",
    "created_at",
    "updated_at",
    # Org columns (already returned via projects + organizations joins).
    "org_slug",
    "org_display_name",
    "org_legal_name",
    "org_entity_type",
    "org_website_url",
    "org_twitter_handle",
    "org_hq_country",
    "org_founded_year",
    "org_total_funding_usd",
    "org_last_funding_round",
    "org_last_funding_date",
}

# Schema metadata appended to every `*_full_view` by migration 20260523_0001
# (and analogous later migrations). Stripped from the JSONB merge; could be
# projected into the `sector`/`subsector` nested objects in a future refactor.
_VIEW_SCHEMA_PASSTHROUGH: set[str] = {
    "sector_name",
    "subsector_name",
    "sector_common_field_schema",
    "subsector_specific_field_schema",
}

# Sector 2 (Rollup & Scaling Frameworks) sector-wide typed columns. These
# live on `public.projects` itself but are surfaced via the rollup views; we
# route them into `sector_attributes` so the frontend groups them under the
# sector heading rather than the subsector heading.
_SECTOR2_ATTR_KEYS: frozenset[str] = frozenset({
    "entity_role",
    "framework_subtype",
    "instance_subtype",
    "lifecycle_status",
    "lifecycle_status_changed_at",
    "settlement_layer",
    "data_availability_layer",
    "withdrawal_latency_minutes",
    "forked_from_slug",
    "forked_from_display_name",
    "forked_from_role",
})

# Sector 5 (Data & Consensus Infrastructure) sector-wide typed columns. Added
# to `public.projects` in migration 20260523_0002.
_SECTOR5_ATTR_KEYS: frozenset[str] = frozenset({
    "data_infra_archetype",
    "trust_model",
    "centralization_risk_score",
    "centralization_risk_evidence_quality",
})

SUBSECTOR_VIEW_REGISTRY: Dict[str, SubsectorViewSpec] = {
    # Sector 2 — Rollup & Scaling Frameworks
    "optimistic-rollups": SubsectorViewSpec(
        view_name="optimistic_rollup_full_view",
        sector_attr_keys=_SECTOR2_ATTR_KEYS,
    ),
    "zk-rollups": SubsectorViewSpec(
        view_name="zk_rollup_full_view",
        sector_attr_keys=_SECTOR2_ATTR_KEYS,
    ),
    "l3-appchain-frameworks": SubsectorViewSpec(
        view_name="l3_framework_full_view",
        sector_attr_keys=_SECTOR2_ATTR_KEYS,
    ),
    "validiums-volitions-hybrid": SubsectorViewSpec(
        view_name="validium_full_view",
        sector_attr_keys=_SECTOR2_ATTR_KEYS,
    ),
    # Sector 5 — Data & Consensus Infrastructure (added in M8.16).
    "rpc-node-providers": SubsectorViewSpec(
        view_name="rpc_endpoints_full_view",
        sector_attr_keys=_SECTOR5_ATTR_KEYS,
    ),
    "oracles-data-networks": SubsectorViewSpec(
        view_name="oracle_feeds_full_view",
        sector_attr_keys=_SECTOR5_ATTR_KEYS,
    ),
    "data-availability-systems": SubsectorViewSpec(
        view_name="da_commitments_full_view",
        sector_attr_keys=_SECTOR5_ATTR_KEYS,
    ),
    "indexing-query-engines": SubsectorViewSpec(
        view_name="indexer_datasets_full_view",
        sector_attr_keys=_SECTOR5_ATTR_KEYS,
    ),
    "analytics-intelligence": SubsectorViewSpec(
        view_name="analytics_dashboards_full_view",
        sector_attr_keys=_SECTOR5_ATTR_KEYS,
    ),
}


def _is_empty(value: Any) -> bool:
    """Treat null and trivially empty values as absent so the page doesn't
    render a wall of em-dashes for sidecar columns that weren't curated."""
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    if isinstance(value, (list, dict)) and len(value) == 0:
        return True
    return False


async def _fetch_subsector_view_row(project: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Look up the matching `*_full_view` row for a project whose subsector
    is registered in `SUBSECTOR_VIEW_REGISTRY`. Returns None when no view is
    mapped. Logs and returns None on Supabase errors — the project page should
    still render with the universal projects.* columns even if the view fetch
    fails."""
    subsector_slug = project.get("subsector_slug") or ""
    spec = SUBSECTOR_VIEW_REGISTRY.get(subsector_slug)
    if spec is None:
        return None

    project_id = project.get("id")
    if not project_id:
        return None

    try:
        return await get_single(
            f"/rest/v1/{spec.view_name}",
            params={"project_id": f"eq.{project_id}", "select": "*"},
        )
    except SupabaseError as exc:
        logger.warning(
            "subsector view fetch failed for %s (view=%s): %s",
            project.get("slug"),
            spec.view_name,
            exc,
        )
        return None


def _merge_subsector_view_row(project: Dict[str, Any], view_row: Dict[str, Any]) -> None:
    """Merge sidecar columns from a `*_full_view` row into the project's
    `sector_attributes` / `subsector_attributes` JSONB. Existing JSONB keys
    win — the JSONB import is authoritative; the sidecar is an overlay that
    only fills gaps. Mutates `project` in place."""
    subsector_slug = project.get("subsector_slug") or ""
    spec = SUBSECTOR_VIEW_REGISTRY.get(subsector_slug)
    sector_attr_keys: frozenset[str] = spec.sector_attr_keys if spec else frozenset()

    sector_attrs: Dict[str, Any] = dict(project.get("sector_attributes") or {})
    subsector_attrs: Dict[str, Any] = dict(project.get("subsector_attributes") or {})

    for key, value in view_row.items():
        if key in _VIEW_STRIP_COMMON or key in _VIEW_SCHEMA_PASSTHROUGH:
            continue
        if _is_empty(value):
            continue
        target = sector_attrs if key in sector_attr_keys else subsector_attrs
        target.setdefault(key, value)

    project["sector_attributes"] = sector_attrs
    project["subsector_attributes"] = subsector_attrs


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# Cache-Control for read-only Market Map endpoints. The data set changes only
# when the ingest scripts run out-of-band, so 60s freshness with 5m
# stale-while-revalidate is conservative and dramatically reduces Supabase load
# on warm caches (Next.js, Render's edge, browser back/forward, CDN).
_MARKET_MAP_CACHE_CONTROL = "public, max-age=60, stale-while-revalidate=300"


def _set_cache_headers(response: Response) -> None:
    response.headers["Cache-Control"] = _MARKET_MAP_CACHE_CONTROL


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
async def list_sectors(response: Response) -> List[Dict[str, Any]]:
    """All sectors with subsector + project counts. Driven by the sector_summary view."""
    _require_supabase()
    _set_cache_headers(response)
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
async def get_sector(sector_slug: str, response: Response) -> Dict[str, Any]:
    """A sector + its subsectors (with counts)."""
    _require_supabase()
    _set_cache_headers(response)
    try:
        sector, subsectors = await asyncio.gather(
            get_single(
                "/rest/v1/sectors",
                params={
                    "slug": f"eq.{sector_slug}",
                    "select": "slug,name,description,display_order,common_field_schema",
                },
            ),
            get(
                "/rest/v1/subsector_summary",
                params={
                    "sector_slug": f"eq.{sector_slug}",
                    "select": "*",
                    "order": "subsector_display_order.asc",
                },
            ),
        )
        if sector is None:
            raise HTTPException(status_code=404, detail=f"Sector not found: {sector_slug}")
    except SupabaseError as exc:
        logger.error("sector get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    return {**sector, "subsectors": subsectors}


@router.get("/subsectors/{subsector_slug}")
async def get_subsector(subsector_slug: str, response: Response) -> Dict[str, Any]:
    """A subsector + its parent sector + its specific_field_schema.

    Uses PostgREST resource embedding so one round-trip covers both rows.
    """
    _require_supabase()
    _set_cache_headers(response)
    try:
        sub = await get_single(
            "/rest/v1/subsectors",
            params={
                "slug": f"eq.{subsector_slug}",
                "select": (
                    "slug,sector_slug,name,description,display_order,"
                    "specific_field_schema,source_sheet_id,source_sheet_gid,"
                    "sector:sectors(slug,name,common_field_schema)"
                ),
            },
        )
    except SupabaseError as exc:
        logger.error("subsector get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    if sub is None:
        raise HTTPException(status_code=404, detail=f"Subsector not found: {subsector_slug}")

    return sub


@router.get("/subsectors/{subsector_slug}/projects")
async def list_subsector_projects(
    subsector_slug: str,
    response: Response,
    limit: int = Query(default=200, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> List[Dict[str, Any]]:
    _require_supabase()
    _set_cache_headers(response)
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
    response: Response,
    sector: Optional[str] = None,
    subsector: Optional[str] = None,
    search: Optional[str] = None,
    stage: Optional[str] = None,
    status_filter: Optional[str] = Query(default=None, alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    offset: int = Query(default=0, ge=0),
) -> List[Dict[str, Any]]:
    _require_supabase()
    _set_cache_headers(response)
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
async def get_project(slug: str, response: Response) -> Dict[str, Any]:
    """Fetch a project with its sector/subsector schemas embedded in one PostgREST
    round-trip via resource embedding. For any subsector registered in
    `SUBSECTOR_VIEW_REGISTRY` the matching `*_full_view` row is fetched and its
    sidecar columns are merged into the JSONB blobs. Net: at most one extra
    round-trip of latency regardless of which sector the project lives in.

    The `*_full_view`s were extended in migration 20260523_0001 (and later
    sector migrations) with sector_common_field_schema /
    subsector_specific_field_schema columns; a future refactor could drop the
    embedded sector/subsector select and serve registered subsectors from the
    view alone, but the views don't yet include every universal
    `public.projects` column the frontend reads (stage, hq_country, team_size_range,
    total_funding_usd, sector_attributes JSONB, etc.), so we keep both paths
    converging through the projects table for now.

    `subsectors!projects_subsector_slug_fkey` disambiguates the embed:
    `public.subsector_memberships` (added M8.13 for validium cross-subsector
    members) creates a 2nd projects↔subsectors relationship, so PostgREST
    returns 300 PGRST201 ('more than one relationship') without the FK hint.
    Discovered via runtime curl during the M8.13+ perf-fix rollout."""
    _require_supabase()
    _set_cache_headers(response)
    try:
        project = await get_single(
            "/rest/v1/projects",
            params={
                "slug": f"eq.{slug}",
                "select": (
                    "*,"
                    "sector:sectors(slug,name,common_field_schema),"
                    "subsector:subsectors!projects_subsector_slug_fkey(slug,name,specific_field_schema)"
                ),
            },
        )
    except SupabaseError as exc:
        logger.error("project get failed: %s body=%s", exc, exc.body)
        raise _map_supabase_error(exc) from exc

    if project is None:
        raise HTTPException(status_code=404, detail=f"Project not found: {slug}")

    view_row = await _fetch_subsector_view_row(project)
    if view_row is not None:
        _merge_subsector_view_row(project, view_row)

    return project
