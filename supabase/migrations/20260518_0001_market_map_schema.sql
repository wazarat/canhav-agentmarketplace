-- M8.1: Market Map core schema (3-tier: universal columns + sector_attributes jsonb + subsector_attributes jsonb).
--
-- Notes:
--   * Universal columns are typed Postgres columns shared by every project across every sector.
--   * sector_attributes / subsector_attributes are JSONB blobs whose shape is documented in
--     sectors.common_field_schema / subsectors.specific_field_schema (JSON Schema).
--   * When a JSONB key stabilizes across 3+ sectors we promote it to a typed column in a follow-up migration.
--   * RLS: anon role can SELECT everything. Writes go through the Supabase service_role key (used only by
--     the backend ingest scripts in .cursor/skills/market-map/scripts/).

create extension if not exists pg_trgm;
create extension if not exists "uuid-ossp";

-- -----------------------------------------------------------------------------
-- sectors
-- -----------------------------------------------------------------------------
create table if not exists public.sectors (
  slug                  text primary key,
  name                  text not null,
  description           text,
  display_order         int  not null,
  common_field_schema   jsonb not null default '{}'::jsonb,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create unique index if not exists sectors_display_order_idx
  on public.sectors (display_order);

-- -----------------------------------------------------------------------------
-- subsectors
-- -----------------------------------------------------------------------------
create table if not exists public.subsectors (
  slug                    text primary key,
  sector_slug             text not null references public.sectors(slug) on delete cascade,
  name                    text not null,
  description             text,
  display_order           int  not null,
  source_sheet_id         text,                            -- Google Sheets workbook ID
  source_sheet_gid        text,                            -- gid of the tab within the workbook
  specific_field_schema   jsonb not null default '{}'::jsonb,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  unique (sector_slug, display_order)
);

create index if not exists subsectors_sector_idx
  on public.subsectors (sector_slug);

-- -----------------------------------------------------------------------------
-- projects
-- -----------------------------------------------------------------------------
create table if not exists public.projects (
  id                       uuid primary key default gen_random_uuid(),
  slug                     text unique not null,
  name                     text not null,
  description              text,
  website_url              text,
  logo_url                 text,
  twitter_handle           text,
  github_url               text,
  status                   text,                            -- live | testnet | mainnet | archived | unknown
  stage                    text,                            -- idea | pre-seed | seed | series-a | profitable | unknown
  founded_year             int,
  hq_country               text,
  team_size_range          text,                            -- e.g. '1-10', '11-50', '51-200'
  total_funding_usd        bigint,
  last_funding_round       text,
  last_funding_date        date,
  sector_slug              text not null references public.sectors(slug),
  subsector_slug           text not null references public.subsectors(slug),
  sector_attributes        jsonb not null default '{}'::jsonb,
  subsector_attributes     jsonb not null default '{}'::jsonb,
  source_row_hash          text,                            -- sha256 of the source row, for change detection
  source_last_synced_at    timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create index if not exists projects_sector_idx        on public.projects (sector_slug);
create index if not exists projects_subsector_idx     on public.projects (subsector_slug);
create index if not exists projects_status_idx        on public.projects (status);
create index if not exists projects_stage_idx         on public.projects (stage);
create index if not exists projects_name_trgm_idx     on public.projects using gin (name gin_trgm_ops);
create index if not exists projects_sector_attrs_gin  on public.projects using gin (sector_attributes);
create index if not exists projects_subsector_attrs_gin on public.projects using gin (subsector_attributes);

-- -----------------------------------------------------------------------------
-- updated_at maintenance
-- -----------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_sectors_updated_at on public.sectors;
create trigger trg_sectors_updated_at before update on public.sectors
  for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_subsectors_updated_at on public.subsectors;
create trigger trg_subsectors_updated_at before update on public.subsectors
  for each row execute procedure public.touch_updated_at();

drop trigger if exists trg_projects_updated_at on public.projects;
create trigger trg_projects_updated_at before update on public.projects
  for each row execute procedure public.touch_updated_at();

-- -----------------------------------------------------------------------------
-- RLS: public read, writes only via service_role
-- -----------------------------------------------------------------------------
alter table public.sectors    enable row level security;
alter table public.subsectors enable row level security;
alter table public.projects   enable row level security;

drop policy if exists "sectors_public_read"    on public.sectors;
drop policy if exists "subsectors_public_read" on public.subsectors;
drop policy if exists "projects_public_read"   on public.projects;

create policy "sectors_public_read"    on public.sectors    for select using (true);
create policy "subsectors_public_read" on public.subsectors for select using (true);
create policy "projects_public_read"   on public.projects   for select using (true);

-- -----------------------------------------------------------------------------
-- Convenience view: project counts per (sector, subsector) for fast UI loads
-- -----------------------------------------------------------------------------
create or replace view public.sector_summary as
  select
    s.slug                                                                  as sector_slug,
    s.name                                                                  as sector_name,
    s.description                                                           as sector_description,
    s.display_order                                                         as sector_display_order,
    count(distinct sub.slug)                                                as subsector_count,
    coalesce(sum(case when p.id is not null then 1 else 0 end), 0)::int     as project_count
  from public.sectors s
  left join public.subsectors sub on sub.sector_slug = s.slug
  left join public.projects  p   on p.subsector_slug = sub.slug
  group by s.slug, s.name, s.description, s.display_order
  order by s.display_order;

create or replace view public.subsector_summary as
  select
    sub.slug                                  as subsector_slug,
    sub.name                                  as subsector_name,
    sub.description                           as subsector_description,
    sub.display_order                         as subsector_display_order,
    sub.sector_slug                           as sector_slug,
    sub.source_sheet_id                       as source_sheet_id,
    sub.source_sheet_gid                      as source_sheet_gid,
    coalesce(count(p.id), 0)::int             as project_count
  from public.subsectors sub
  left join public.projects p on p.subsector_slug = sub.slug
  group by sub.slug, sub.name, sub.description, sub.display_order, sub.sector_slug,
           sub.source_sheet_id, sub.source_sheet_gid
  order by sub.sector_slug, sub.display_order;
