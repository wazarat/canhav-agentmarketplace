-- M8.11 — Sector 2 / ZK Rollups subsector schema.
--
-- WHAT THIS MIGRATION ADDS.
--
--   1. public.subsector_memberships
--        Sector-wide m2m join table for the SSoT-with-multi-subsector pattern
--        prescribed by .cursor/skills/.../subsectors/zk-rollups.fields-to-add.md
--        §2. Each project has ONE row in public.projects (its "home" subsector
--        lives on projects.subsector_slug), and zero-or-more rows here for any
--        other subsector where the SAME real-world entity appears.
--
--        Example: zk-stack lives once in public.projects (subsector_slug =
--        'zk-rollups'), and gets two additional subsector_memberships rows
--        for 'l3-appchain-frameworks' and 'validiums-volitions-hybrid'.
--
--        This table lands in M8.11 (and not earlier in M8.10) because ZK is
--        the first subsector that requires it: zk-stack, starkex, zksync-era
--        all carry cross-subsector claims as of M8.11; op-stack/arbitrum-nitro
--        from M8.10 get backfilled as 'home' members of optimistic-rollups
--        below.
--
--   2. public.zk_rollup_attrs — 1:1 sidecar for ZK Rollup specialty fields.
--
--   3. public.zk_rollup_full_view — convenience view for the frontend.
--
--   4. Backfill of 'home' memberships for the 7 Optimistic Rollups rows from
--      M8.10 so the membership table is self-consistent.
--
-- See:
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/SKILL.md
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/
--       subsectors/zk-rollups.{md,narrative.md,data-sources.md,fields-to-add.md}
--   - docs/DECISIONS.md (M8.11 entry).

-- ---------------------------------------------------------------------------
-- 1. public.subsector_memberships — sector-wide cross-subsector join.
-- ---------------------------------------------------------------------------

create table if not exists public.subsector_memberships (
  project_id           uuid not null
    references public.projects(id) on delete cascade,
  subsector_slug       text not null
    references public.subsectors(slug) on delete restrict,

  -- 'home' (matches projects.subsector_slug), 'cross-reference', 'primary',
  -- 'secondary', 'volition-mode', 'borderline-engine', 'primary-engine',
  -- 'validium-capable', 'rollup-as-a-service', etc. Free text by design — the
  -- v8 fields-to-add docs use diverse role labels per-subsector.
  role_in_subsector    text not null,

  -- Convenience boolean: exactly one row per project should have
  -- primary_membership = true and it must equal projects.subsector_slug.
  -- The CHECK constraint below + a unique index enforce this.
  primary_membership   boolean not null default false,

  notes                text,

  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  primary key (project_id, subsector_slug)
);

comment on table public.subsector_memberships is
  'Cross-subsector membership for the SSoT pattern. Each project has ONE row in '
  'public.projects (with the "home" subsector on projects.subsector_slug) and '
  'zero-or-more rows here for additional subsectors where the same real-world '
  'entity appears. Introduced in M8.11 for zk-stack / starkex / zksync-era / '
  'polygon-cdk cross-subsector claims; backfilled with "home" rows for the '
  'M8.10 Optimistic rollups so the table is self-consistent.';

comment on column public.subsector_memberships.primary_membership is
  'True if this row corresponds to the projects.subsector_slug "home" subsector. '
  'Exactly one row per project_id should have primary_membership = true.';

create unique index if not exists subsector_memberships_one_primary_per_project_idx
  on public.subsector_memberships (project_id)
  where primary_membership;

create index if not exists subsector_memberships_subsector_idx
  on public.subsector_memberships (subsector_slug);

alter table public.subsector_memberships enable row level security;
drop policy if exists "subsector_memberships_public_read" on public.subsector_memberships;
create policy "subsector_memberships_public_read"
  on public.subsector_memberships for select using (true);

drop trigger if exists trg_subsector_memberships_updated_at on public.subsector_memberships;
create trigger trg_subsector_memberships_updated_at
  before update on public.subsector_memberships
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. Backfill 'home' memberships for existing rows.
--
-- Every project that's already in public.projects gets a primary_membership
-- row matching projects.subsector_slug. This keeps the table self-consistent
-- with the (project_id) -> (its home subsector) invariant. Future Sector-2
-- ingests will add additional (non-primary) rows.
-- ---------------------------------------------------------------------------

insert into public.subsector_memberships (project_id, subsector_slug, role_in_subsector, primary_membership)
select
  p.id,
  p.subsector_slug,
  case
    when p.entity_role = 'instance'             then 'primary'
    when p.entity_role in ('framework','engine','both') then 'primary'
    else 'primary'
  end,
  true
from public.projects p
where p.subsector_slug is not null
  and not exists (
    select 1 from public.subsector_memberships m
    where m.project_id = p.id and m.subsector_slug = p.subsector_slug
  );

-- ---------------------------------------------------------------------------
-- 3. public.zk_rollup_attrs — 1:1 sidecar table.
--
-- Mirrors the shape of public.optimistic_rollup_attrs (M8.10). Tier 1 + Tier 2
-- structured fields, free-text summaries preserved verbatim, plus the
-- ZK-specific extras (proof_system, prover_decentralization, verifier address,
-- l2beat_stage with the extended set, custom-vm-cairo evm_equivalence_level).
--
-- Why a sidecar instead of subsector_attributes JSONB:
--   * 30+ structured fields → JSONB GIN scans don't help typed-column filters.
--   * Snapshot fields all carry an _as_of_date companion; pairing them as
--     typed columns lets the ingest assertion check easily.
--   * Free-text summaries are large; pulling them out of `projects` keeps the
--     hot table narrow.
-- ---------------------------------------------------------------------------

create table if not exists public.zk_rollup_attrs (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Tier 1 — required for every non-aggregate row.
  proof_system                          text,
    -- stark | plonk | groth16 | halo2 | hybrid | custom
  proof_system_summary                  text,
  trusted_setup_required                boolean,
  proof_aggregation_strategy            text,
    -- none | aggregated | recursive | aggregated-and-recursive
  prover_decentralization               text,
    -- single-prover | permissioned-multi | permissionless | planned-permissionless
  sequencer_model                       text,
    -- single-sequencer | permissioned-set | shared-sequencer-network | based-rollup
  sequencer_decentralization_roadmap    text,
    -- shipped | committed-with-timeline | aspirational | not-stated
  evm_equivalence_level                 text,
    -- evm-equivalent | evm-compatible | custom-vm-cairo | custom-vm-other
  vm_name                               text,
    -- 'EVM' | 'EraVM' | 'Cairo VM' | …
  verifier_address_l1                   text,
    -- 20-byte hex, lowercased, null for framework/engine without fixed chain
  verifier_kind                         text,
    -- on-chain-contract | recursive-aggregator | proprietary-prover-vendor | …
  withdrawal_latency_minutes            integer
    check (withdrawal_latency_minutes is null or withdrawal_latency_minutes >= 0),
  l2beat_stage                          text,
    -- stage-0 | stage-1 | stage-2 | not-classified | not-applicable
  upgrade_governance_type               text,
    -- security-council | dao-governed | multisig | committed-immutable | hybrid

  -- Tier 2 — snapshot fields (every value requires an _as_of_date companion).
  recursion_depth_typical               integer,
  batch_size_typical_tx                 integer,
  prover_hardware_requirement           text,
    -- cpu-feasible | gpu-feasible | gpu-required | specialized-asic
  cryptographic_finality_minutes_min    integer,
  cryptographic_finality_minutes_max    integer,
  tvl_usd_band                          text,
  tvl_as_of_date                        date,
  fee_revenue_band_usd_annual           text,
  fee_as_of_date                        date,
  daily_tx_count_band                   text,
  daily_tx_as_of_date                   date,
  based_rollup                          boolean default false,
  volition_mode_supported               boolean default false,
  zkchain_registry_count                integer,

  -- Tier 3 — proving economics (mostly null at v1).
  prover_hardware_cost_usd_estimate     integer,
  prover_throughput_tx_per_second       integer,
  trusted_setup_ceremony_url            text,
  trusted_setup_participant_count       integer,
  verifier_gas_per_proof                integer,
  audit_report_urls                     text[],

  -- Dual-enum split companions (free text preserved from XLSX).
  security_inheritance_level            text,
    -- full-l1 | partial-l1 | inherited-upstream | configurable
  trust_assumptions_summary             text,
  state_transition_definition_summary   text,
  settlement_path_summary               text,
  reorg_failure_model_summary           text,
  proving_cost_summary                  text,
  proving_cost_type                     text,
    -- high-fixed-with-scale-amortization | linear-with-usage | …
  prover_bottleneck_summary             text,
  throughput_constraints_summary        text,
  cost_sensitivity_summary              text,
  ownership_summary                     text,
  upgrade_summary                       text,
  emergency_controls_present            boolean,
  emergency_controls_summary            text,
  decentralization_roadmap_credibility  text,
    -- low | moderate | high
  developer_adoption_summary            text,
  mainnet_maturity_band                 text,
    -- early-mainnet | maturing | mature | declining
  enterprise_orientation_band           text,
    -- low | moderate | high
  ecosystem_dependency_summary          text,
  is_reusable_framework                 boolean,
  shared_prover_sequencer_summary       text,
  design_philosophy                     text,
    -- opinionated | modular | mixed
  is_single_canonical                   boolean,
  multi_rollup_capable                  boolean,
  deployment_permissioning              text,
    -- permissioned | permissionless | mixed
  native_cross_rollup_support           boolean,
  cross_rollup_support_summary          text,
  ethereum_composability_model          text,
    -- synchronous | asynchronous
  external_bridge_dependency            text,
    -- yes | partial | no
  external_bridge_summary               text,

  -- Free-text identity/context.
  inclusion_rationale                   text,
  practitioner_note                     text,
  practitioner_validation_check         text,

  -- Provenance + data quality.
  data_quality_flags                    text[] not null default '{}',
    -- e.g. {'zk_duplicate_header_practitioner_note_missing'} per
    -- zk-rollups.fields-to-add.md §3d.1.
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.zk_rollup_attrs is
  '1:1 sidecar for ZK Rollups subsector. Tier 1 (proof_system, prover_decentralization, '
  'sequencer_model, evm_equivalence_level) + Tier 2 (snapshot bands with as_of_date) + Tier 3 '
  '(proving economics) + dual-enum splits + free-text summaries preserved from the source sheet.';

alter table public.zk_rollup_attrs enable row level security;
drop policy if exists "zk_rollup_attrs_public_read" on public.zk_rollup_attrs;
create policy "zk_rollup_attrs_public_read"
  on public.zk_rollup_attrs for select using (true);

drop trigger if exists trg_zk_rollup_attrs_updated_at on public.zk_rollup_attrs;
create trigger trg_zk_rollup_attrs_updated_at
  before update on public.zk_rollup_attrs
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 4. public.zk_rollup_full_view — convenience view for the frontend.
-- ---------------------------------------------------------------------------

drop view if exists public.zk_rollup_full_view;

create view public.zk_rollup_full_view
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

    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,
    o.website_url                                                     as org_website_url,
    o.twitter_handle                                                  as org_twitter_handle,
    o.hq_country                                                      as org_hq_country,
    o.founded_year                                                    as org_founded_year,
    o.total_funding_usd                                               as org_total_funding_usd,

    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,
    fp.entity_role                                                    as forked_from_role,

    a.proof_system                                                    as proof_system,
    a.proof_system_summary                                            as proof_system_summary,
    a.trusted_setup_required                                          as trusted_setup_required,
    a.proof_aggregation_strategy                                      as proof_aggregation_strategy,
    a.prover_decentralization                                         as prover_decentralization,
    a.sequencer_model                                                 as sequencer_model,
    a.sequencer_decentralization_roadmap                              as sequencer_decentralization_roadmap,
    a.evm_equivalence_level                                           as evm_equivalence_level,
    a.vm_name                                                         as vm_name,
    a.verifier_address_l1                                             as verifier_address_l1,
    a.verifier_kind                                                   as verifier_kind,
    a.l2beat_stage                                                    as l2beat_stage,
    a.upgrade_governance_type                                         as upgrade_governance_type,
    a.recursion_depth_typical                                         as recursion_depth_typical,
    a.batch_size_typical_tx                                           as batch_size_typical_tx,
    a.prover_hardware_requirement                                     as prover_hardware_requirement,
    a.cryptographic_finality_minutes_min                              as cryptographic_finality_minutes_min,
    a.cryptographic_finality_minutes_max                              as cryptographic_finality_minutes_max,
    a.tvl_usd_band                                                    as tvl_usd_band,
    a.tvl_as_of_date                                                  as tvl_as_of_date,
    a.fee_revenue_band_usd_annual                                     as fee_revenue_band_usd_annual,
    a.fee_as_of_date                                                  as fee_as_of_date,
    a.daily_tx_count_band                                             as daily_tx_count_band,
    a.daily_tx_as_of_date                                             as daily_tx_as_of_date,
    a.based_rollup                                                    as based_rollup,
    a.volition_mode_supported                                         as volition_mode_supported,
    a.zkchain_registry_count                                          as zkchain_registry_count,
    a.security_inheritance_level                                      as security_inheritance_level,
    a.trust_assumptions_summary                                       as trust_assumptions_summary,
    a.state_transition_definition_summary                             as state_transition_definition_summary,
    a.settlement_path_summary                                         as settlement_path_summary,
    a.reorg_failure_model_summary                                     as reorg_failure_model_summary,
    a.proving_cost_summary                                            as proving_cost_summary,
    a.proving_cost_type                                               as proving_cost_type,
    a.prover_bottleneck_summary                                       as prover_bottleneck_summary,
    a.throughput_constraints_summary                                  as throughput_constraints_summary,
    a.cost_sensitivity_summary                                        as cost_sensitivity_summary,
    a.ownership_summary                                               as ownership_summary,
    a.upgrade_summary                                                 as upgrade_summary,
    a.emergency_controls_present                                      as emergency_controls_present,
    a.emergency_controls_summary                                      as emergency_controls_summary,
    a.decentralization_roadmap_credibility                            as decentralization_roadmap_credibility,
    a.developer_adoption_summary                                      as developer_adoption_summary,
    a.mainnet_maturity_band                                           as mainnet_maturity_band,
    a.enterprise_orientation_band                                     as enterprise_orientation_band,
    a.ecosystem_dependency_summary                                    as ecosystem_dependency_summary,
    a.is_reusable_framework                                           as is_reusable_framework,
    a.shared_prover_sequencer_summary                                 as shared_prover_sequencer_summary,
    a.design_philosophy                                               as design_philosophy,
    a.is_single_canonical                                             as is_single_canonical,
    a.multi_rollup_capable                                            as multi_rollup_capable,
    a.deployment_permissioning                                        as deployment_permissioning,
    a.native_cross_rollup_support                                     as native_cross_rollup_support,
    a.cross_rollup_support_summary                                    as cross_rollup_support_summary,
    a.ethereum_composability_model                                    as ethereum_composability_model,
    a.external_bridge_dependency                                      as external_bridge_dependency,
    a.external_bridge_summary                                         as external_bridge_summary,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at
  from public.projects p
  left join public.organizations o on o.slug = p.maintaining_organization
  left join public.projects fp on fp.id = p.forked_from
  left join public.zk_rollup_attrs a on a.project_id = p.id
  where p.subsector_slug = 'zk-rollups';

comment on view public.zk_rollup_full_view is
  'Frontend convenience view: projects + organizations + forked_from lineage + zk_rollup_attrs '
  'sidecar joined for the ZK Rollups subsector. Created in M8.11 alongside the sidecar table.';
