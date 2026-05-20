-- M8.9 — Network Upgrades subsector: dedicated 4-table relational schema.
--
-- WHY THIS IS DIFFERENT FROM EVERY OTHER SUBSECTOR.
-- The first four Core Protocol subsectors (Consensus Layer, Execution Layer,
-- Validators, MEV) are entity-shaped: every row is an organization, client, or
-- operator with continuous existence. Network Upgrades is event-shaped: every
-- row is a discrete, time-stamped protocol transition (London, The Merge,
-- Shapella, Dencun, Pectra, Fusaka, Glamsterdam …). Forcing event rows into
-- the universal-field model would null every column that matters (no funding,
-- no HQ, no Twitter, no maintaining_organization in the usual sense — the EF
-- doesn't "own" upgrades; the All-Core-Devs process does).
--
-- The v7 Perplexity drafts (network-upgrades.{narrative,data-sources,fields-
-- to-add}.md, mirrored at .cursor/skills/.../subsectors/) prescribe a small
-- relational schema instead:
--
--   1. public.network_upgrades  — the event table.
--   2. public.eips              — the artifact registry (one row per EIP).
--   3. public.upgrade_eips      — join: which EIPs ship in which upgrade.
--   4. public.upgrade_impact    — join: which subsector rows are affected.
--
-- The fourth table is the killer feature. It lets the platform answer
-- "Show me everything that changed for execution clients in Dencun" or
-- "Which validator operators are affected by Pectra account abstraction?"
-- with a single join — the unique value Network Upgrades contributes to the
-- canhav market map versus a static spreadsheet.
--
-- UI PARITY. The Market Map navigation expects every subsector to expose its
-- rows via public.projects so /market-map/<sector>/<subsector> works without
-- per-subsector special-casing. We honor that by mirroring each
-- network_upgrades row into public.projects with EVERY universal field NULL
-- and not_applicable_reason='protocol_event_not_entity'. The mirror row is
-- the navigation handle; the rich event payload lives in this migration's
-- four tables (joined via the upgrade_full_view).
--
-- This migration adds a new documented enum value
-- not_applicable_reason='protocol_event_not_entity' to the existing list on
-- public.projects. The column has no CHECK constraint (intentional, per the
-- M8.7 design), so this is a comment-only addition.
--
-- INGESTION. The weekly ingest worker lives at
-- backend/scripts/ingest_network_upgrades.py and is driven by a GitHub Actions
-- cron (.github/workflows/ingest-network-upgrades.yml). It pulls from
-- ethereum/EIPs, ethereum/consensus-specs, ethereum/execution-specs, and
-- ethereum/pm — all free, public, well-structured GitHub repos. No paid data
-- vendor required. See network-upgrades.data-sources.md for the full source
-- stack and rate-limit notes.
--
-- See:
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/
--     network-upgrades.{narrative,data-sources,fields-to-add}.md (v7 drafts).
--   - docs/DECISIONS.md 2026-05-20 (network-upgrades dedicated schema decision).

-- ---------------------------------------------------------------------------
-- 0. Document the new not_applicable_reason enum value.
-- ---------------------------------------------------------------------------

comment on column public.projects.not_applicable_reason is
  'When maintaining_organization is null OR universal fields are nulled, this records WHY. '
  'Enum: aggregate_category | dao_governed | protocol_specification | distributed_collective | '
  'protocol_event_not_entity. '
  '"protocol_event_not_entity" is set on Network Upgrades projects rows whose substance '
  'lives in the dedicated public.network_upgrades / eips / upgrade_eips / upgrade_impact '
  'tables (M8.9). The projects row is a thin navigation handle; every universal field is NULL.';

-- ---------------------------------------------------------------------------
-- 1. public.network_upgrades — the event table.
-- ---------------------------------------------------------------------------

create table if not exists public.network_upgrades (
  slug                          text primary key,
    -- Colloquial slug: 'london', 'the-merge', 'shapella', 'dencun', 'pectra',
    -- 'fusaka', 'glamsterdam'. Hyphenated, lowercase, never the formal EL/CL
    -- pair name (those go in execution_fork_name + consensus_fork_name).
  display_name                  text not null,
    -- 'London', 'The Merge', 'Shanghai / Capella (Shapella)', 'Cancun-Deneb (Dencun)', …
  execution_fork_name           text,
    -- 'London', 'Shanghai', 'Cancun', 'Prague', 'Osaka'. Null for consensus-only forks.
  consensus_fork_name           text,
    -- 'Bellatrix', 'Capella', 'Deneb', 'Electra', 'Fulu'. Null for execution-only forks.
  status                        text not null default 'proposed',
    -- one of: activated | scheduled | proposed | superseded | cancelled
  activation_date               date,
    -- Required when status='activated'. Mainnet activation date.
  activation_block_number       bigint,
    -- Execution-layer activation block. Etherscan link.
  activation_epoch              bigint,
    -- Consensus-layer activation epoch. beaconcha.in link.
  network                       text not null default 'mainnet',
    -- one of: mainnet | sepolia | holesky | hoodi | (other testnets). When an
    -- upgrade lands on a testnet first, store the mainnet activation here and
    -- the testnet activations in subsector_attributes.testnet_activations for
    -- now (Tier-2 promotes that to a sibling table).
  layers_affected               text not null default 'both',
    -- one of: execution | consensus | both
  primary_change_types          text[] not null default '{}',
    -- Subset of: security | scaling | economics | ux | architecture | staking
    -- | data-availability | account | privacy | energy | crypto
  backward_compatible           boolean not null default false,
    -- Almost always false for hard forks; the field is included for completeness.
  upgrade_risk_profile          text,
    -- one of: low | medium | medium-high | high | very-high | not-yet-assessed
  risk_rationale                text,
    -- Free-text rationale split out from the source sheet's compound risk cell.
  client_coordination_required  text,
    -- one of: execution-only | consensus-only | both
  description                   text,
    -- Plain-English summary of what the upgrade did.
  structural_significance       text,
    -- "Why it mattered structurally" — split from the source sheet.
  practitioner_note             text,
  practitioner_validation_check text,
  notable_changes               text,
    -- Catch-all for EIP-list bullet items that did not parse cleanly into a
    -- numbered EIP reference (e.g. "Account abstraction improvements").
  is_provisional                boolean not null default false,
    -- True for upgrades not yet activated whose EIP scope is still in flight
    -- (Glamsterdam-style rows). Worker flips to false when status='activated'.
  ethereum_org_url              text,
    -- e.g. https://ethereum.org/en/history/#london — set when the EF docs ship.
  source_pm_issue_url           text,
    -- Link to the ethereum/pm tracker issue for upcoming upgrades.
  source_commit_sha             text,
    -- SHA of the source markdown file when last ingested (change detection).
  data_confidence               text not null default 'estimate',
    -- one of: verified | estimate | stale
  last_ingested_at              timestamptz,
  attributes                    jsonb not null default '{}'::jsonb,
    -- Catch-all for fields that have not yet been promoted to typed columns
    -- (e.g. testnet_activations array, eip_authors_summary).
  created_at                    timestamptz not null default now(),
  updated_at                    timestamptz not null default now()
);

comment on table public.network_upgrades is
  'M8.9 — One row per Ethereum protocol upgrade (event-shaped, not entity-shaped). '
  'Each row is mirrored into public.projects with not_applicable_reason='
  '''protocol_event_not_entity'' so the Market Map UI navigation works. '
  'See .cursor/skills/.../subsectors/network-upgrades.fields-to-add.md for the field shape rationale.';

create index if not exists network_upgrades_status_idx           on public.network_upgrades (status);
create index if not exists network_upgrades_activation_date_idx  on public.network_upgrades (activation_date);
create index if not exists network_upgrades_layers_affected_idx  on public.network_upgrades (layers_affected);
create index if not exists network_upgrades_attributes_gin       on public.network_upgrades using gin (attributes);

drop trigger if exists trg_network_upgrades_updated_at on public.network_upgrades;
create trigger trg_network_upgrades_updated_at
  before update on public.network_upgrades
  for each row execute procedure public.touch_updated_at();

alter table public.network_upgrades enable row level security;

drop policy if exists "network_upgrades_public_read" on public.network_upgrades;
create policy "network_upgrades_public_read"
  on public.network_upgrades for select using (true);

-- Status invariant: activated rows must have an activation_date.
-- Use a NOT VALID constraint so any future backfill anomaly does not break the
-- DDL deploy; the weekly worker enforces it from the application side.
alter table public.network_upgrades
  drop constraint if exists network_upgrades_activated_has_date;
alter table public.network_upgrades
  add constraint network_upgrades_activated_has_date
  check (status <> 'activated' or activation_date is not null) not valid;

-- ---------------------------------------------------------------------------
-- 2. public.eips — the artifact registry.
-- ---------------------------------------------------------------------------

create table if not exists public.eips (
  eip_number         integer primary key,
    -- e.g. 1559, 4844, 7702
  title              text not null,
  eip_type           text,
    -- one of: standards-track | meta | informational
  eip_category       text,
    -- one of: core | networking | interface | erc  (required when eip_type='standards-track')
  status             text not null default 'draft',
    -- one of: draft | review | last-call | final | stagnant | withdrawn | living
  authors            text[] not null default '{}',
  created_date       date,
  requires           integer[] not null default '{}',
    -- EIPs this depends on.
  discussions_to_url text,
  source_url         text,
    -- Raw GitHub URL of the .md file.
  source_commit_sha  text,
    -- For change detection.
  last_ingested_at   timestamptz,
  attributes         jsonb not null default '{}'::jsonb,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

comment on table public.eips is
  'M8.9 — One row per Ethereum Improvement Proposal. Populated by the weekly '
  'worker from github.com/ethereum/EIPs. CC0-1.0 license; redistribute freely.';

create index if not exists eips_status_idx       on public.eips (status);
create index if not exists eips_eip_type_idx     on public.eips (eip_type);
create index if not exists eips_eip_category_idx on public.eips (eip_category);
create index if not exists eips_authors_gin      on public.eips using gin (authors);
create index if not exists eips_requires_gin     on public.eips using gin (requires);

drop trigger if exists trg_eips_updated_at on public.eips;
create trigger trg_eips_updated_at
  before update on public.eips
  for each row execute procedure public.touch_updated_at();

alter table public.eips enable row level security;

drop policy if exists "eips_public_read" on public.eips;
create policy "eips_public_read"
  on public.eips for select using (true);

-- ---------------------------------------------------------------------------
-- 3. public.upgrade_eips — join: which EIPs ship in which upgrade.
-- ---------------------------------------------------------------------------

create table if not exists public.upgrade_eips (
  upgrade_slug      text not null references public.network_upgrades(slug) on delete cascade,
  eip_number        integer not null references public.eips(eip_number) on delete restrict,
  inclusion_role    text not null default 'headline',
    -- one of: headline | supporting | deprecation | meta
  headline_label    text,
    -- Short tag like 'Base fee + burn', 'Blobs', 'PoS transition'.
  notes             text,
  created_at        timestamptz not null default now(),
  primary key (upgrade_slug, eip_number)
);

comment on table public.upgrade_eips is
  'M8.9 — Many-to-many: EIPs ship in upgrades, upgrades carry many EIPs. '
  'The headline_label is the human-readable summary that the UI surfaces on the upgrade card.';

create index if not exists upgrade_eips_eip_number_idx     on public.upgrade_eips (eip_number);
create index if not exists upgrade_eips_inclusion_role_idx on public.upgrade_eips (inclusion_role);

alter table public.upgrade_eips enable row level security;

drop policy if exists "upgrade_eips_public_read" on public.upgrade_eips;
create policy "upgrade_eips_public_read"
  on public.upgrade_eips for select using (true);

-- ---------------------------------------------------------------------------
-- 4. public.upgrade_impact — join: which subsector rows are affected.
--
-- This is THE killer table for the platform. It is what lets us answer cross-
-- subsector questions like "Which validator operators are affected by Pectra
-- account abstraction?" or "Show every consensus client that had to ship a
-- breaking change for Dencun." The previous M8 ingest passes (Consensus,
-- Execution, Validators, MEV) all populate public.projects with rich rows
-- but have no way to express "this row is affected by event X" without a
-- join table on the event side. That join is this table.
--
-- (upgrade_slug, affected_subsector, affected_entity_slug, impact_type) is the
-- composite primary key. Because Postgres does not allow NULL in PK columns,
-- affected_entity_slug uses '*' as a sentinel meaning "all rows in this
-- subsector" (per the v7 fields-to-add.md spec). Application code MUST treat
-- '*' as the wildcard, never insert literal asterisks elsewhere.
-- ---------------------------------------------------------------------------

create table if not exists public.upgrade_impact (
  upgrade_slug          text not null references public.network_upgrades(slug) on delete cascade,
  affected_subsector    text not null references public.subsectors(slug),
  affected_entity_slug  text not null default '*',
    -- '*' = applies to every row in the subsector. Otherwise references
    -- public.projects(slug) — but the FK is NOT enforced because the wildcard
    -- breaks it. Worker enforces referential integrity from the application side.
  impact_type           text not null,
    -- one of: breaking-change | new-capability | deprecation | performance |
    --         optional-feature | requires-coordination
  impact_summary        text not null,
    -- One-sentence description.
  notes                 text,
  created_at            timestamptz not null default now(),
  primary key (upgrade_slug, affected_subsector, affected_entity_slug, impact_type)
);

comment on table public.upgrade_impact is
  'M8.9 — Cross-subsector impact mapping. affected_entity_slug="*" means "applies to '
  'every row in the named subsector". The unique value Network Upgrades contributes to '
  'the canhav market map: the only place an upgrade event meets the per-entity rows it '
  'affects. See .cursor/skills/.../subsectors/network-upgrades.fields-to-add.md.';

create index if not exists upgrade_impact_affected_subsector_idx
  on public.upgrade_impact (affected_subsector);
create index if not exists upgrade_impact_affected_entity_slug_idx
  on public.upgrade_impact (affected_entity_slug)
  where affected_entity_slug <> '*';
create index if not exists upgrade_impact_impact_type_idx
  on public.upgrade_impact (impact_type);

alter table public.upgrade_impact enable row level security;

drop policy if exists "upgrade_impact_public_read" on public.upgrade_impact;
create policy "upgrade_impact_public_read"
  on public.upgrade_impact for select using (true);

-- ---------------------------------------------------------------------------
-- 5. public.upgrade_full_view — joined denormalized view for the frontend.
--
-- The Market Map UI generally wants "one row per upgrade with its EIPs and its
-- impacted entities". This view computes that join once. Designed for SECURITY
-- INVOKER per the M8.1 convention (anon role can SELECT everything).
-- ---------------------------------------------------------------------------

create or replace view public.upgrade_full_view
  with (security_invoker = true)
  as
select
  nu.slug,
  nu.display_name,
  nu.execution_fork_name,
  nu.consensus_fork_name,
  nu.status,
  nu.activation_date,
  nu.activation_block_number,
  nu.activation_epoch,
  nu.network,
  nu.layers_affected,
  nu.primary_change_types,
  nu.backward_compatible,
  nu.upgrade_risk_profile,
  nu.risk_rationale,
  nu.client_coordination_required,
  nu.description,
  nu.structural_significance,
  nu.practitioner_note,
  nu.practitioner_validation_check,
  nu.notable_changes,
  nu.is_provisional,
  nu.ethereum_org_url,
  nu.source_pm_issue_url,
  nu.data_confidence,
  nu.last_ingested_at,
  coalesce(
    (select jsonb_agg(
              jsonb_build_object(
                'eip_number',    e.eip_number,
                'title',          e.title,
                'eip_type',       e.eip_type,
                'eip_category',   e.eip_category,
                'status',         e.status,
                'inclusion_role', ue.inclusion_role,
                'headline_label', ue.headline_label
              )
              order by ue.inclusion_role, e.eip_number
            )
       from public.upgrade_eips ue
       join public.eips e on e.eip_number = ue.eip_number
      where ue.upgrade_slug = nu.slug),
    '[]'::jsonb
  ) as eips,
  coalesce(
    (select jsonb_agg(
              jsonb_build_object(
                'affected_subsector',   ui.affected_subsector,
                'affected_entity_slug', ui.affected_entity_slug,
                'impact_type',          ui.impact_type,
                'impact_summary',       ui.impact_summary
              )
              order by ui.affected_subsector, ui.impact_type
            )
       from public.upgrade_impact ui
      where ui.upgrade_slug = nu.slug),
    '[]'::jsonb
  ) as impact
from public.network_upgrades nu;

comment on view public.upgrade_full_view is
  'M8.9 — Denormalized join across network_upgrades + upgrade_eips + eips + upgrade_impact. '
  'Use this from the frontend for the upgrade landing page. SECURITY INVOKER per '
  'supabase/migrations/20260518_0003_views_security_invoker.sql.';

-- ---------------------------------------------------------------------------
-- 6. Replace the placeholder subsector schema with the pointer shape.
--
-- Each Network Upgrades public.projects row carries a minimal subsector_attributes
-- payload: just a pointer back to network_upgrades.slug plus the sync metadata.
-- additionalProperties: true so the worker can stash extra computed fields
-- (e.g. eips_count, impact_count) without a schema migration.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/network-upgrades.json",
  "title": "Network Upgrades — subsector_attributes",
  "description": "Network Upgrades is event-shaped. The substance lives in the dedicated public.network_upgrades / eips / upgrade_eips / upgrade_impact tables (M8.9). The projects row is a thin navigation handle with universal fields nulled and not_applicable_reason='protocol_event_not_entity'. This blob carries only a pointer + sync metadata; query upgrade_full_view for the rich payload.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "network_upgrade_slug": {
      "title": "Network upgrade slug",
      "type": "string",
      "description": "FK-shaped pointer to public.network_upgrades.slug. Identical to projects.slug by convention but stored explicitly for cross-table joins."
    },
    "status": {
      "title": "Upgrade status (mirror)",
      "type": "string",
      "description": "Mirror of network_upgrades.status for cheap filtering without a join.",
      "examples": ["activated", "scheduled", "proposed", "superseded", "cancelled"]
    },
    "activation_date": {
      "title": "Activation date (mirror)",
      "type": ["string", "null"],
      "format": "date"
    },
    "layers_affected": {
      "title": "Layers affected (mirror)",
      "type": "string",
      "examples": ["execution", "consensus", "both"]
    },
    "primary_change_types": {
      "title": "Primary change types (mirror)",
      "type": "array",
      "items": { "type": "string" }
    },
    "eips_count": {
      "title": "EIPs count (computed)",
      "type": "integer",
      "minimum": 0,
      "description": "Number of rows in public.upgrade_eips for this upgrade. Refreshed by the weekly worker."
    },
    "impact_count": {
      "title": "Impact count (computed)",
      "type": "integer",
      "minimum": 0,
      "description": "Number of rows in public.upgrade_impact for this upgrade. Refreshed by the weekly worker."
    },
    "data_refreshed_at": {
      "title": "Data refreshed at",
      "type": "string",
      "format": "date-time"
    },
    "data_confidence": {
      "title": "Data confidence",
      "type": "string",
      "examples": ["verified", "estimate", "stale"]
    }
  }
}
$json$::jsonb
 where slug = 'network-upgrades';
