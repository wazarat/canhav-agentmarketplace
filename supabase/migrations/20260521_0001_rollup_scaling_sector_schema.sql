-- M8.10 — Sector 2 (Rollup & Scaling Frameworks): sector-wide SSoT schema.
--
-- WHY THIS LANDS NOW INSTEAD OF SUBSECTOR BY SUBSECTOR.
-- Sector 2 is where the SSoT pattern earns its keep: 28 rows in the source
-- workbook collapse to 22 canonical entities because OP Stack, Arbitrum Nitro,
-- ZK Stack, StarkEx, Polygon CDK, and zkSync Era each appear in multiple
-- subsectors as the same real-world thing viewed through different practitioner
-- lenses. Modeling that cleanly requires typed columns + join tables that ALL
-- four subsectors (Optimistic, ZK, L3, Validiums) share. Landing those once at
-- the start of Sector 2 avoids three more migrations of the same shape during
-- M8.11/M8.12/M8.13.
--
-- The 3-tier promotion rule in .cursor/skills/market-map/SKILL.md says "promote
-- a JSONB key to a typed column once it has stabilized across 3+ sectors."
-- Sector 2 trips that rule on day one (all 4 subsectors need the same keys),
-- so we promote up-front. See docs/DECISIONS.md M8.10 entry for the rationale.
--
-- WHAT THIS MIGRATION ADDS.
--
--   1. New typed columns on public.projects (sector-2-wide):
--        entity_role, framework_subtype, instance_subtype,
--        lifecycle_status, lifecycle_status_changed_at,
--        forked_from, migrated_to_project,
--        settlement_layer, data_availability_layer,
--        withdrawal_latency_minutes.
--
--   2. New sector-2-wide join + lookup tables:
--        public.ecosystems
--        public.framework_underlying_bases
--        public.framework_ecosystem_alignment
--        public.framework_deployments
--        public.da_committees
--        public.entity_da_committee
--        public.entity_co_owners
--        public.entity_migration_history
--
--   3. New Optimistic-specific sidecar table:
--        public.optimistic_rollup_attrs   (1:1 FK to projects)
--
--   4. New convenience view:
--        public.optimistic_rollup_full_view
--
--   5. Extends the documented not_applicable_reason enum (comment-only).
--
-- See:
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/SKILL.md
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/subsectors/
--       optimistic-rollups.{md,narrative.md,data-sources.md,fields-to-add.md}
--   - docs/DECISIONS.md (M8.10 entry).

-- ---------------------------------------------------------------------------
-- 0. Document the new not_applicable_reason enum values for Sector 2.
-- ---------------------------------------------------------------------------

comment on column public.projects.not_applicable_reason is
  'When maintaining_organization is null OR universal fields are nulled, this records WHY. '
  'Enum: aggregate_category | dao_governed | protocol_specification | distributed_collective | '
  'protocol_event_not_entity | parent_org_holds_field | community_operated | data_unavailable | '
  'migrated_away. '
  '"parent_org_holds_field" added M8.10 for Sector-2 rows whose universal fields live on the '
  'org row (founded_year for op-mainnet is op-stack-era; the legal entity has its own founded_year). '
  '"migrated_away" added M8.10 for entities with lifecycle_status=migrated-away whose snapshot '
  'fields are frozen at the migration date.';

-- ---------------------------------------------------------------------------
-- 1. New typed columns on public.projects (sector-2-wide).
--
-- Constraints are CHECK-via-list (not Postgres ENUM types) for symmetry with
-- the existing M8.7 organizations.entity_type / projects.not_applicable_reason
-- approach: enums-via-CHECK can be relaxed in a future migration without the
-- ALTER TYPE rigamarole. The text+CHECK shape also makes them easy to evolve
-- when ZK / L3 / Validium subsectors discover edge cases (e.g. 'application-
-- specific-engine' was a fields-to-add finding that surfaced only after the
-- Validium narrative landed — adding it to the framework_subtype CHECK list
-- in M8.13 will be one line).
-- ---------------------------------------------------------------------------

alter table public.projects
  add column if not exists entity_role text
    check (entity_role is null or entity_role in (
      'instance', 'framework', 'engine', 'both'
    )),
  add column if not exists framework_subtype text
    check (framework_subtype is null or framework_subtype in (
      'engine', 'chain-launch-sdk', 'rollup-as-a-service', 'application-specific-engine'
    )),
  add column if not exists instance_subtype text,
  add column if not exists lifecycle_status text not null default 'active'
    check (lifecycle_status in (
      'active', 'deprecated', 'migrated-away', 'decommissioned', 'proposed-not-launched'
    )),
  add column if not exists lifecycle_status_changed_at date,
  add column if not exists forked_from uuid
    references public.projects(id) deferrable initially deferred,
  add column if not exists migrated_to_project uuid
    references public.projects(id) deferrable initially deferred,
  add column if not exists settlement_layer text,
  add column if not exists data_availability_layer text,
  add column if not exists withdrawal_latency_minutes integer
    check (withdrawal_latency_minutes is null or withdrawal_latency_minutes >= 0);

comment on column public.projects.entity_role is
  'Sector-2 role classifier. instance = live execution environment users transact on; '
  'framework = reusable stack that defines how a class of rollups work; engine = upstream '
  'building block (EVM, Geth fork, prover); both = entity plays both roles (rare).';

comment on column public.projects.framework_subtype is
  'Required when entity_role IN (framework, engine, both). engine = pure execution stack; '
  'chain-launch-sdk = pre-packaged chain-launch SDK; rollup-as-a-service = managed RaaS; '
  'application-specific-engine = engine tuned for a single app (StarkEx originally).';

comment on column public.projects.instance_subtype is
  'Optional free-form qualifier for instance rows (e.g. application-specific-validium). '
  'Promote to enum if it stabilizes across subsectors.';

comment on column public.projects.lifecycle_status is
  'Operational lifecycle. Default active. migrated-away requires migrated_to_project AND '
  'lifecycle_status_changed_at to be non-null (enforced at app-tier; CHECK constraint added '
  'in M8.13 once Validiums lands the first migrated-away row, dydx-ethereum-anchored).';

comment on column public.projects.forked_from is
  'Self-FK encoding engine/framework lineage. E.g. base.forked_from = op-stack.id. '
  'Frameworks themselves carry null. Deferred FK so two-pass insert works.';

comment on column public.projects.migrated_to_project is
  'Self-FK for entities that have migrated to a different chain/stack. Empty in v1; will '
  'populate when M8.13 ingests dYdX-Ethereum-anchored with successor dYdX-Cosmos.';

comment on column public.projects.settlement_layer is
  'Where state roots are posted. Free-text rather than enum so future sectors (Bitcoin L2s, '
  'Solana L2s) drop in cleanly. Optimistic v1: ethereum-l1 for all 7 rows.';

comment on column public.projects.data_availability_layer is
  'Where transaction data is published. Free-text. Optimistic v1: ethereum-l1-blobs '
  '(post-Dencun) for all 7 rows. Validiums add proprietary-validium / eigenda / celestia / etc.';

comment on column public.projects.withdrawal_latency_minutes is
  'Unified across optimistic challenge windows and ZK exit windows. Pre-empts unit '
  'confusion across Optimistic (days, ~7) vs ZK (hours, varies). Multiply by 1440 to '
  'convert days; divide by 60 to convert hours. Null for framework rows.';

create index if not exists projects_entity_role_idx        on public.projects (entity_role);
create index if not exists projects_lifecycle_status_idx   on public.projects (lifecycle_status);
create index if not exists projects_forked_from_idx        on public.projects (forked_from);
create index if not exists projects_settlement_layer_idx   on public.projects (settlement_layer);
create index if not exists projects_da_layer_idx           on public.projects (data_availability_layer);

-- ---------------------------------------------------------------------------
-- 2. public.ecosystems — lookup table for ecosystem brands.
--
-- Superchain (OP Stack), Orbit (Arbitrum Nitro), ZK Stack (zkSync), Elastic
-- Chain (zkSync rebrand), AggLayer (Polygon CDK), Hyperchain (StarkEx). These
-- aren't projects in the canhav sense — they're umbrella brands a framework
-- ecosystem aligns with. Validators / MEV don't need this; we model only what
-- Sector 2 actually uses.
-- ---------------------------------------------------------------------------

create table if not exists public.ecosystems (
  slug          text primary key,
  display_name  text not null,
  description   text,
  parent_project uuid references public.projects(id),
    -- The framework that owns this ecosystem brand (op-stack -> superchain).
    -- Null for ecosystems without a single owning framework (rare).
  homepage_url  text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.ecosystems is
  'Sector-2 ecosystem brand registry. One row per umbrella brand (Superchain, Orbit, AggLayer, '
  'Elastic Chain, Hyperchain). Frameworks align with ecosystems via framework_ecosystem_alignment.';

create index if not exists ecosystems_parent_project_idx on public.ecosystems (parent_project);

alter table public.ecosystems enable row level security;
drop policy if exists "ecosystems_public_read" on public.ecosystems;
create policy "ecosystems_public_read" on public.ecosystems for select using (true);

drop trigger if exists trg_ecosystems_updated_at on public.ecosystems;
create trigger trg_ecosystems_updated_at before update on public.ecosystems
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3. public.framework_underlying_bases — m2m: framework -> upstream engine.
--
-- OP Stack -> "Geth EVM" (the upstream engine is not a project in the canhav
-- sense yet, so upstream_project_id is null and upstream_label carries the
-- text plus a not_applicable_reason). When we later track EVM implementations
-- as their own projects, the FK gets populated.
-- ---------------------------------------------------------------------------

create table if not exists public.framework_underlying_bases (
  id                       uuid primary key default gen_random_uuid(),
  framework_project        uuid not null references public.projects(id) on delete cascade,
  upstream_project_id      uuid references public.projects(id),
  upstream_label           text not null,
    -- Free-text fallback when the upstream engine isn't (yet) a project row.
  relationship_type        text not null default 'forks',
    -- one of: forks | builds-on | derives-from | bundles
  not_applicable_reason    text,
    -- Set when upstream_project_id is null because the engine isn't tracked
    -- as a project (e.g. 'data_unavailable' for OP Stack -> Geth EVM in v1).
  notes                    text,
  created_at               timestamptz not null default now(),
  unique (framework_project, upstream_label)
);

comment on table public.framework_underlying_bases is
  'Many-to-many: framework -> upstream engine. Captures lineage that does NOT fit forked_from '
  '(which is for direct project-to-project lineage). E.g. OP Stack builds on the Geth EVM, '
  'which is not itself a canhav project row in v1.';

create index if not exists fub_framework_idx on public.framework_underlying_bases (framework_project);
create index if not exists fub_upstream_idx  on public.framework_underlying_bases (upstream_project_id);

alter table public.framework_underlying_bases enable row level security;
drop policy if exists "fub_public_read" on public.framework_underlying_bases;
create policy "fub_public_read" on public.framework_underlying_bases for select using (true);

-- ---------------------------------------------------------------------------
-- 4. public.framework_ecosystem_alignment — m2m: framework -> ecosystem.
--
-- OP Stack -> Superchain, Arbitrum Nitro -> Orbit, ZK Stack -> Elastic Chain,
-- Polygon CDK -> AggLayer. Many frameworks align with exactly one ecosystem,
-- but the schema supports many-to-many so cross-ecosystem alignment (rare but
-- possible) is expressible.
-- ---------------------------------------------------------------------------

create table if not exists public.framework_ecosystem_alignment (
  id                  uuid primary key default gen_random_uuid(),
  framework_project   uuid not null references public.projects(id) on delete cascade,
  ecosystem_slug      text not null references public.ecosystems(slug) on delete cascade,
  alignment_type      text not null default 'primary',
    -- one of: primary | secondary | historical
  notes               text,
  created_at          timestamptz not null default now(),
  unique (framework_project, ecosystem_slug, alignment_type)
);

create index if not exists fea_framework_idx on public.framework_ecosystem_alignment (framework_project);
create index if not exists fea_ecosystem_idx on public.framework_ecosystem_alignment (ecosystem_slug);

alter table public.framework_ecosystem_alignment enable row level security;
drop policy if exists "fea_public_read" on public.framework_ecosystem_alignment;
create policy "fea_public_read" on public.framework_ecosystem_alignment for select using (true);

-- ---------------------------------------------------------------------------
-- 5. public.framework_deployments — chains built on a framework.
--
-- Empty in v1 per data_gaps.md G-8 (deferred to v2). Schema lands now so the
-- L3 subsector ingest doesn't need a schema change to start writing.
-- ---------------------------------------------------------------------------

create table if not exists public.framework_deployments (
  id                  uuid primary key default gen_random_uuid(),
  framework_project   uuid not null references public.projects(id) on delete cascade,
  deployment_project  uuid references public.projects(id),
    -- The chain built on the framework. Null when the chain isn't a project
    -- row yet (the long-tail of OP Stack chains we won't enumerate in v1).
  deployment_label    text not null,
  deployment_type     text default 'production',
    -- one of: production | testnet | abandoned
  launched_at         date,
  notes               text,
  created_at          timestamptz not null default now()
);

create index if not exists fd_framework_idx  on public.framework_deployments (framework_project);
create index if not exists fd_deployment_idx on public.framework_deployments (deployment_project);

alter table public.framework_deployments enable row level security;
drop policy if exists "fd_public_read" on public.framework_deployments;
create policy "fd_public_read" on public.framework_deployments for select using (true);

-- ---------------------------------------------------------------------------
-- 6. public.da_committees + public.entity_da_committee — DA committee registry.
--
-- Used heavily by M8.13 (Validiums). Created here so all four Sector-2
-- subsectors share the schema. Empty in v1 for Optimistic (no rollup in this
-- subsector uses an off-chain DA committee).
-- ---------------------------------------------------------------------------

create table if not exists public.da_committees (
  slug              text primary key,
  display_name      text not null,
  description       text,
  committee_size    integer,
  governance_model  text,
  homepage_url      text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

alter table public.da_committees enable row level security;
drop policy if exists "da_committees_public_read" on public.da_committees;
create policy "da_committees_public_read" on public.da_committees for select using (true);

drop trigger if exists trg_da_committees_updated_at on public.da_committees;
create trigger trg_da_committees_updated_at before update on public.da_committees
  for each row execute procedure public.touch_updated_at();

create table if not exists public.entity_da_committee (
  id                   uuid primary key default gen_random_uuid(),
  project_id           uuid not null references public.projects(id) on delete cascade,
  committee_slug       text not null references public.da_committees(slug) on delete cascade,
  membership_role      text default 'consumer',
    -- one of: consumer | operator | both
  notes                text,
  created_at           timestamptz not null default now(),
  unique (project_id, committee_slug)
);

create index if not exists edc_project_idx   on public.entity_da_committee (project_id);
create index if not exists edc_committee_idx on public.entity_da_committee (committee_slug);

alter table public.entity_da_committee enable row level security;
drop policy if exists "edc_public_read" on public.entity_da_committee;
create policy "edc_public_read" on public.entity_da_committee for select using (true);

-- ---------------------------------------------------------------------------
-- 7. public.entity_co_owners — composite ownership audit.
--
-- For entities where the maintaining_organization FK alone is insufficient
-- (Immutable X is operated by Immutable X Pte Ltd but the engine is StarkEx
-- by StarkWare; dYdX-Ethereum-anchored is operated by dYdX Trading but the
-- engine is StarkEx). Empty in v1 per data_gaps.md G-10.
-- ---------------------------------------------------------------------------

create table if not exists public.entity_co_owners (
  id                 uuid primary key default gen_random_uuid(),
  project_id         uuid not null references public.projects(id) on delete cascade,
  organization_slug  text not null references public.organizations(slug)
                     deferrable initially deferred,
  ownership_role     text not null,
    -- one of: operator | engine-vendor | governance | infrastructure | other
  ownership_share_pct numeric(5,2),
    -- 0–100. Null when not meaningfully apportionable.
  notes              text,
  created_at         timestamptz not null default now(),
  unique (project_id, organization_slug, ownership_role)
);

create index if not exists eco_project_idx on public.entity_co_owners (project_id);
create index if not exists eco_org_idx     on public.entity_co_owners (organization_slug);

alter table public.entity_co_owners enable row level security;
drop policy if exists "eco_public_read" on public.entity_co_owners;
create policy "eco_public_read" on public.entity_co_owners for select using (true);

-- ---------------------------------------------------------------------------
-- 8. public.entity_migration_history — append-only lifecycle audit trail.
--
-- Every change to projects.lifecycle_status writes a row here. v1 expectation:
-- empty for Optimistic Rollups (no migrations); first rows arrive in M8.13
-- when dydx-ethereum-anchored lands.
-- ---------------------------------------------------------------------------

create table if not exists public.entity_migration_history (
  id                      uuid primary key default gen_random_uuid(),
  project_id              uuid not null references public.projects(id) on delete cascade,
  previous_status         text,
  new_status              text not null,
  changed_at              date not null,
  migrated_to_project     uuid references public.projects(id),
  migrated_to_label       text,
    -- Free-text fallback (e.g. 'dydx-cosmos' before that becomes a project row).
  reason                  text,
  evidence_url            text,
  recorded_at             timestamptz not null default now()
);

create index if not exists emh_project_idx     on public.entity_migration_history (project_id);
create index if not exists emh_changed_at_idx  on public.entity_migration_history (changed_at);

alter table public.entity_migration_history enable row level security;
drop policy if exists "emh_public_read" on public.entity_migration_history;
create policy "emh_public_read" on public.entity_migration_history for select using (true);

-- ---------------------------------------------------------------------------
-- 9. public.optimistic_rollup_attrs — 1:1 sidecar table.
--
-- Why a sidecar instead of subsector_attributes JSONB:
--   * 30+ structured fields → JSONB GIN scans don't help typed-column filters.
--   * Snapshot fields all carry an _as_of_date companion; pairing them as
--     typed columns lets the ingest assertion check easily.
--   * Free-text summaries are large; pulling them out of `projects` keeps the
--     hot table narrow.
--
-- Sidecar pattern follows the M8.9 4-table-schema decision documented in
-- docs/DECISIONS.md (when a subsector has >10 specialty fields, prefer a
-- sidecar over fat JSONB).
-- ---------------------------------------------------------------------------

create table if not exists public.optimistic_rollup_attrs (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Tier 1 — required for every non-aggregate row.
  sequencer_model                       text,
    -- single-sequencer | permissioned-set | shared-sequencer-network | based-rollup
  sequencer_decentralization_roadmap    text,
    -- shipped | committed-with-timeline | aspirational | not-stated
  fault_proof_status                    text,
    -- permissionless | permissioned-whitelist | security-council-only | not-yet-deployed
  challenge_window_days                 integer,
  l2beat_stage                          text,
    -- stage-0 | stage-1 | stage-2 | not-classified | not-applicable
  upgrade_governance_type               text,
    -- security-council | dao-governed | multisig | committed-immutable | hybrid
  upgrade_timelock_days                 integer,
  security_council_size                 integer,
  evm_equivalence_level                 text,
    -- evm-equivalent | evm-compatible | custom-vm

  -- Tier 2 — snapshot fields (every value requires a *_as_of_date companion).
  mev_policy_type                       text,
    -- none-stated | mev-share | sequencer-auction | priority-gas-auction | inactive
  fee_revenue_band_usd_annual           text,
    -- >100M | 10M-100M | 1M-10M | <1M | not-applicable
  fee_as_of_date                        date,
  tvl_usd_band                          text,
    -- >10B | 1B-10B | 100M-1B | 10M-100M | <10M | not-applicable
  tvl_as_of_date                        date,
  daily_tx_count_band                   text,
  daily_tx_as_of_date                   date,
  native_token_ticker                   text,
  governance_token_ticker               text,
  superchain_member                     boolean default false,
  orbit_chain                           boolean default false,

  -- Tier 3 — nice to have.
  batch_posting_frequency_seconds       integer,
  fast_bridge_partner_count             integer,
  ecosystem_grant_program_active        boolean default false,
  upgrade_history_count                 integer,

  -- Free-text summaries preserved from the source sheet.
  inclusion_rationale                   text,
  security_model_summary                text,
  execution_model_summary               text,
  settlement_summary                    text,
  governance_summary                    text,
  ownership_summary                     text,
  roadmap_summary                       text,
  operational_risk_summary              text,
  framework_architecture_summary        text,
  deployment_model_summary              text,
  interoperability_summary              text,
  practitioner_note                     text,
  practitioner_validation_check         text,

  -- Provenance + data quality.
  data_quality_flags                    text[] not null default '{}',
    -- e.g. {'practitioner_check_swap_unconfirmed'} for OP Stack and Nitro
    -- per fields-to-add.md §3d.3 (Option A: flag-and-skip).
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',
    -- estimate | verified | stale

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.optimistic_rollup_attrs is
  '1:1 sidecar for Optimistic Rollups subsector. Tier 1 + Tier 2 + Tier 3 + free-text. '
  'Snapshot fields (tvl, fee_revenue, daily_tx) each carry a _as_of_date companion that the '
  'enrich_optimistic_rollups.py importer enforces via inline assertion.';

alter table public.optimistic_rollup_attrs enable row level security;
drop policy if exists "optimistic_rollup_attrs_public_read" on public.optimistic_rollup_attrs;
create policy "optimistic_rollup_attrs_public_read"
  on public.optimistic_rollup_attrs for select using (true);

drop trigger if exists trg_optimistic_rollup_attrs_updated_at on public.optimistic_rollup_attrs;
create trigger trg_optimistic_rollup_attrs_updated_at
  before update on public.optimistic_rollup_attrs
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 10. public.optimistic_rollup_full_view — convenience view for the frontend.
--
-- Pulls together projects + organizations + sidecar + forked_from self-join.
-- The frontend page at /market-map/rollup-scaling-frameworks/optimistic-rollups
-- will read from this view once M8 UI loop reaches Sector 2.
-- ---------------------------------------------------------------------------

drop view if exists public.optimistic_rollup_full_view;

create view public.optimistic_rollup_full_view
  with (security_invoker = true)
as
  select
    p.id                                                              as project_id,
    p.slug                                                            as slug,
    p.name                                                            as display_name,
    p.description                                                     as description,
    p.website_url                                                     as website_url,
    p.logo_url                                                        as logo_url,
    p.twitter_handle                                                  as twitter_handle,
    p.github_url                                                      as github_url,
    p.status                                                          as status,
    p.sector_slug                                                     as sector_slug,
    p.subsector_slug                                                  as subsector_slug,

    p.entity_role                                                     as entity_role,
    p.framework_subtype                                               as framework_subtype,
    p.instance_subtype                                                as instance_subtype,
    p.lifecycle_status                                                as lifecycle_status,
    p.lifecycle_status_changed_at                                     as lifecycle_status_changed_at,
    p.settlement_layer                                                as settlement_layer,
    p.data_availability_layer                                         as data_availability_layer,
    p.withdrawal_latency_minutes                                      as withdrawal_latency_minutes,

    p.is_aggregate                                                    as is_aggregate,
    p.not_applicable_reason                                           as not_applicable_reason,

    -- Maintaining organization (FK -> public.organizations).
    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,
    o.website_url                                                     as org_website_url,
    o.twitter_handle                                                  as org_twitter_handle,
    o.hq_country                                                      as org_hq_country,
    o.founded_year                                                    as org_founded_year,
    o.total_funding_usd                                               as org_total_funding_usd,
    o.last_funding_round                                              as org_last_funding_round,
    o.last_funding_date                                               as org_last_funding_date,

    -- Self-join: lineage.
    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,
    fp.entity_role                                                    as forked_from_role,

    -- Sidecar.
    a.sequencer_model                                                 as sequencer_model,
    a.sequencer_decentralization_roadmap                              as sequencer_decentralization_roadmap,
    a.fault_proof_status                                              as fault_proof_status,
    a.challenge_window_days                                           as challenge_window_days,
    a.l2beat_stage                                                    as l2beat_stage,
    a.upgrade_governance_type                                         as upgrade_governance_type,
    a.upgrade_timelock_days                                           as upgrade_timelock_days,
    a.security_council_size                                           as security_council_size,
    a.evm_equivalence_level                                           as evm_equivalence_level,
    a.mev_policy_type                                                 as mev_policy_type,
    a.fee_revenue_band_usd_annual                                     as fee_revenue_band_usd_annual,
    a.fee_as_of_date                                                  as fee_as_of_date,
    a.tvl_usd_band                                                    as tvl_usd_band,
    a.tvl_as_of_date                                                  as tvl_as_of_date,
    a.daily_tx_count_band                                             as daily_tx_count_band,
    a.daily_tx_as_of_date                                             as daily_tx_as_of_date,
    a.native_token_ticker                                             as native_token_ticker,
    a.governance_token_ticker                                         as governance_token_ticker,
    a.superchain_member                                               as superchain_member,
    a.orbit_chain                                                     as orbit_chain,
    a.batch_posting_frequency_seconds                                 as batch_posting_frequency_seconds,
    a.fast_bridge_partner_count                                       as fast_bridge_partner_count,
    a.ecosystem_grant_program_active                                  as ecosystem_grant_program_active,
    a.upgrade_history_count                                           as upgrade_history_count,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.security_model_summary                                          as security_model_summary,
    a.execution_model_summary                                         as execution_model_summary,
    a.settlement_summary                                              as settlement_summary,
    a.governance_summary                                              as governance_summary,
    a.ownership_summary                                               as ownership_summary,
    a.roadmap_summary                                                 as roadmap_summary,
    a.operational_risk_summary                                        as operational_risk_summary,
    a.framework_architecture_summary                                  as framework_architecture_summary,
    a.deployment_model_summary                                        as deployment_model_summary,
    a.interoperability_summary                                        as interoperability_summary,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at
  from public.projects p
  left join public.organizations o
    on o.slug = p.maintaining_organization
  left join public.projects fp
    on fp.id = p.forked_from
  left join public.optimistic_rollup_attrs a
    on a.project_id = p.id
  where p.subsector_slug = 'optimistic-rollups';

comment on view public.optimistic_rollup_full_view is
  'Frontend convenience view for /market-map/rollup-scaling-frameworks/optimistic-rollups. '
  'Joins projects + organizations + optimistic_rollup_attrs + forked_from self-lineage. '
  'security_invoker so RLS is enforced at the caller.';
