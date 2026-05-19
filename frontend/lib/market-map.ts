/**
 * Server-side typed client for the Market Map API.
 *
 * Reads via the FastAPI backend (`/api/market-map/*`). Never speaks to Supabase directly
 * from the browser — keeps anon key off the wire and lets us add server-side caching
 * uniformly.
 */

export type ProjectStatus = "live" | "testnet" | "mainnet" | "archived" | "unknown";
export type ProjectStage =
  | "idea"
  | "pre-seed"
  | "seed"
  | "series-a"
  | "series-b"
  | "series-c-plus"
  | "profitable"
  | "acquired"
  | "shutdown"
  | "unknown";

export interface SectorSummary {
  sector_slug: string;
  sector_name: string;
  sector_description: string | null;
  sector_display_order: number;
  subsector_count: number;
  project_count: number;
}

export interface SubsectorSummary {
  subsector_slug: string;
  subsector_name: string;
  subsector_description: string | null;
  subsector_display_order: number;
  sector_slug: string;
  source_sheet_id: string | null;
  source_sheet_gid: string | null;
  project_count: number;
}

export interface SectorDetail {
  slug: string;
  name: string;
  description: string | null;
  display_order: number;
  common_field_schema: Record<string, unknown>;
  subsectors: SubsectorSummary[];
}

export interface SubsectorDetail {
  slug: string;
  sector_slug: string;
  name: string;
  description: string | null;
  display_order: number;
  specific_field_schema: Record<string, unknown>;
  source_sheet_id: string | null;
  source_sheet_gid: string | null;
  sector: {
    slug: string;
    name: string;
    common_field_schema: Record<string, unknown>;
  } | null;
}

export interface ProjectRow {
  id: string;
  slug: string;
  name: string;
  description: string | null;
  website_url: string | null;
  logo_url: string | null;
  twitter_handle: string | null;
  github_url: string | null;
  status: ProjectStatus | null;
  stage: ProjectStage | null;
  founded_year: number | null;
  hq_country: string | null;
  team_size_range: string | null;
  total_funding_usd: number | null;
  last_funding_round: string | null;
  last_funding_date: string | null;
  sector_slug: string;
  subsector_slug: string;
  sector_attributes: Record<string, unknown>;
  subsector_attributes: Record<string, unknown>;
  source_last_synced_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProjectDetail extends ProjectRow {
  sector: {
    slug: string;
    name: string;
    common_field_schema: Record<string, unknown>;
  } | null;
  subsector: {
    slug: string;
    name: string;
    specific_field_schema: Record<string, unknown>;
  } | null;
}

function apiBase(): string {
  // Server-side: prefer the internal env var. Falls back to the public one.
  return (
    process.env.API_BASE_URL ||
    process.env.NEXT_PUBLIC_API_BASE_URL ||
    "http://localhost:8000"
  ).replace(/\/$/, "");
}

async function fetchJson<T>(path: string, init?: RequestInit): Promise<T> {
  const url = `${apiBase()}${path}`;
  // During the M8 sector-by-sector build phase we want ingest results to appear immediately
  // on the live site, not 60s later. Once data stabilizes we can re-enable ISR by replacing
  // `cache: "no-store"` with `next: { revalidate: 60 }`.
  const res = await fetch(url, {
    ...init,
    headers: { Accept: "application/json", ...(init?.headers ?? {}) },
    cache: "no-store",
  });
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new MarketMapError(
      `Market Map API ${res.status} for ${path}: ${text.slice(0, 200)}`,
      res.status,
    );
  }
  return (await res.json()) as T;
}

export class MarketMapError extends Error {
  constructor(message: string, public status: number) {
    super(message);
  }
}

export async function listSectors(): Promise<SectorSummary[]> {
  return fetchJson<SectorSummary[]>("/api/market-map/sectors");
}

export async function getSector(slug: string): Promise<SectorDetail | null> {
  try {
    return await fetchJson<SectorDetail>(`/api/market-map/sectors/${slug}`);
  } catch (err) {
    if (err instanceof MarketMapError && err.status === 404) return null;
    throw err;
  }
}

export async function getSubsector(slug: string): Promise<SubsectorDetail | null> {
  try {
    return await fetchJson<SubsectorDetail>(`/api/market-map/subsectors/${slug}`);
  } catch (err) {
    if (err instanceof MarketMapError && err.status === 404) return null;
    throw err;
  }
}

export async function listSubsectorProjects(
  slug: string,
  opts?: { limit?: number; offset?: number },
): Promise<ProjectRow[]> {
  const params = new URLSearchParams();
  if (opts?.limit) params.set("limit", String(opts.limit));
  if (opts?.offset) params.set("offset", String(opts.offset));
  const query = params.toString();
  return fetchJson<ProjectRow[]>(
    `/api/market-map/subsectors/${slug}/projects${query ? `?${query}` : ""}`,
  );
}

export async function getProject(slug: string): Promise<ProjectDetail | null> {
  try {
    return await fetchJson<ProjectDetail>(`/api/market-map/projects/${slug}`);
  } catch (err) {
    if (err instanceof MarketMapError && err.status === 404) return null;
    throw err;
  }
}
