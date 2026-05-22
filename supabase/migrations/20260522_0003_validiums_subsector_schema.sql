-- M8.13 — Sector 2 / Validiums, Volitions & Hybrid Rollups subsector schema.
--
-- Adds public.validium_attrs (sidecar) + public.validium_full_view.
--
-- 4 of the 6 source rows are cross-subsector members whose canonical home
-- lives elsewhere (starkex/zksync-era → zk-rollups; polygon-cdk →
-- l3-appchain-frameworks; zk-stack → zk-rollups). Only `immutable-x` and
-- `dydx-ethereum-anchored` are NEW projects.
--
-- The sidecar covers Tier 1 enums (rollup_variant, execution_proof_type,
-- da_location, da_mode_switching, ethereum_verification_scope, …), Tier 2
-- snapshot fields with as_of_date companions, free-text preserves, and the
-- data_quality_flags audit array.
--
-- See:
--   - .cursor/skills/market-map/sectors/rollup-scaling-frameworks/
--       subsectors/validiums-volitions-hybrid.{md,narrative.md,data-sources.md,fields-to-add.md}
--   - docs/DECISIONS.md (M8.13 entry).

create table if not exists public.validium_attrs (
  project_id uuid primary key references public.projects(id) on delete cascade,

  -- Tier 1 — dual-enum splits (paired with _text free-text companions).
  rollup_variant text,
    -- rollup | validium | volition | hybrid | validium-with-rollup-mode | hybrid-framework-configurable
  rollup_variant_text text,
  execution_proof_type text,
    -- stark | snark | optimistic-fraud | hybrid
  execution_proof_type_text text,
  da_location text,
    -- ethereum-l1-calldata | ethereum-l1-blobs | off-chain-committee |
    -- off-chain-operator-managed | configurable | decentralized-da-layer
  da_location_text text,
  da_mode_switching text,
    -- static | deployment-level | protocol-controlled | user-selectable-per-tx | app-selectable
  da_mode_switching_text text,
  da_provider_type text,
    -- vendor-curated-committee | operator-curated-committee | operator-managed-service |
    -- decentralized-da-layer | configurable
  da_provider_type_text text,
  da_withholding_risk_bool boolean,
  da_withholding_risk_text text,
  recovery_guarantees_text text,
  who_controls_da_text text,
  settlement_layer_enum text,
    -- ethereum-l1-direct | ethereum-l1-via-l2 | configurable
  settlement_layer_text text,
  ethereum_verification_scope text,
    -- execution-only | execution-with-da-attestation | execution-and-da | configurable
    -- NOTE: per fields-to-add §I.6, this column must NEVER equal
    -- 'execution-and-da' inside the Validiums subsector (would mean full
    -- rollup, belongs in optimistic-rollups or zk-rollups instead).
  ethereum_verification_scope_text text,
  security_lost_vs_rollup_text text,
  failure_blast_radius text,
    -- single-app | multiple-apps-same-engine | entire-ecosystem
  failure_blast_radius_text text,
  cost_reduction_text text,
  throughput_improvements_text text,
  latency_characteristics_text text,
  use_case_fit_text text,
  protocol_ownership_text text,
  da_committee_governance text,
    -- vendor-curated-committee | operator-curated-committee | operator-managed-service |
    -- configurable | decentralized-da-layer | dao-governed
  da_committee_governance_text text,
  upgrade_authority_level text,
    -- framework-controlled | chain-controlled | hybrid | dao-governed
  upgrade_authority_text text,
  emergency_intervention_text text,
  data_unavailability_scenarios_text text,
  censorship_risk_text text,
  ops_complexity_level text,
    -- minimal | low | moderate | high
  ops_complexity_text text,
  user_exit_risk_level text,
    -- low-eth-l1-guaranteed-exit | moderate-da-attested-exit |
    -- high-trust-required-for-exit | extreme-no-exit-mechanism
  user_exit_risk_text text,

  -- Tier 2 — snapshot fields (each carries an as_of_date companion).
  production_status text,
    -- pre-production | early-production | mature-production | migrated-away | decommissioned
  production_status_text text,
  production_status_as_of_date date,
  primary_user_type_text text,
  ecosystem_lock_in_level text,
    -- low | moderate | high
  ecosystem_lock_in_text text,
  longevity_migration_risk_text text,

  -- Composability / integration.
  composability_with_ethereum_text text,
  compatibility_with_rollup_text text,
  bridge_required_bool boolean,
  bridge_dependency_text text,
  migration_path_available text,
    -- yes-documented | yes-undocumented | no-architectural-blocker | n-a-already-rollup-mode
  migration_path_text text,

  -- Free-text identity.
  inclusion_rationale text,
  inclusion_qualifier_note text,
  practitioner_note text,
  practitioner_validation_check text,

  -- Provenance + data quality.
  data_quality_flags text[] not null default '{}',
  not_applicable_reason text,
  data_refreshed_at timestamptz,
  data_confidence text default 'estimate',

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.validium_attrs is
  '1:1 sidecar for Validiums, Volitions & Hybrid Rollups subsector. 4 of 6 source rows '
  'reuse existing projects rows (cross-subsector members); only immutable-x and '
  'dydx-ethereum-anchored are NEW. ethereum_verification_scope must never equal '
  'execution-and-da in this subsector per fields-to-add.md §I.6.';

create index if not exists validium_attrs_production_status_idx
  on public.validium_attrs (production_status);
create index if not exists validium_attrs_rollup_variant_idx
  on public.validium_attrs (rollup_variant);
create index if not exists validium_attrs_da_location_idx
  on public.validium_attrs (da_location);

alter table public.validium_attrs enable row level security;
drop policy if exists "validium_attrs_public_read" on public.validium_attrs;
create policy "validium_attrs_public_read"
  on public.validium_attrs for select using (true);

drop trigger if exists trg_validium_attrs_updated_at on public.validium_attrs;
create trigger trg_validium_attrs_updated_at
  before update on public.validium_attrs
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- public.validium_full_view — convenience view for the frontend.
--
-- INNER JOIN against validium_attrs so the view surfaces every entity that
-- participates in this subsector regardless of where its home subsector is.
-- The home subsector is preserved on projects.subsector_slug; this view
-- reads via the sidecar membership, so cross-subsector entities surface here.
-- ---------------------------------------------------------------------------

drop view if exists public.validium_full_view;

create view public.validium_full_view
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
    p.subsector_slug                                                  as home_subsector_slug,

    p.entity_role                                                     as entity_role,
    p.framework_subtype                                               as framework_subtype,
    p.instance_subtype                                                as instance_subtype,
    p.lifecycle_status                                                as lifecycle_status,
    p.lifecycle_status_changed_at                                     as lifecycle_status_changed_at,
    p.settlement_layer                                                as settlement_layer,
    p.data_availability_layer                                         as data_availability_layer,
    p.withdrawal_latency_minutes                                      as withdrawal_latency_minutes,
    p.is_aggregate                                                    as is_aggregate,
    p.not_applicable_reason                                           as project_not_applicable_reason,

    o.slug                                                            as org_slug,
    o.display_name                                                    as org_display_name,
    o.legal_name                                                      as org_legal_name,
    o.entity_type                                                     as org_entity_type,

    fp.slug                                                           as forked_from_slug,
    fp.name                                                           as forked_from_display_name,

    mp.slug                                                           as migrated_to_slug,
    mp.name                                                           as migrated_to_display_name,

    m.role_in_subsector                                               as role_in_subsector,
    m.primary_membership                                              as is_primary_member,

    a.rollup_variant                                                  as rollup_variant,
    a.rollup_variant_text                                             as rollup_variant_text,
    a.execution_proof_type                                            as execution_proof_type,
    a.execution_proof_type_text                                       as execution_proof_type_text,
    a.da_location                                                     as da_location,
    a.da_location_text                                                as da_location_text,
    a.da_mode_switching                                               as da_mode_switching,
    a.da_provider_type                                                as da_provider_type,
    a.da_withholding_risk_bool                                        as da_withholding_risk_bool,
    a.da_withholding_risk_text                                        as da_withholding_risk_text,
    a.who_controls_da_text                                            as who_controls_da_text,
    a.settlement_layer_enum                                           as settlement_layer_enum,
    a.ethereum_verification_scope                                     as ethereum_verification_scope,
    a.failure_blast_radius                                            as failure_blast_radius,
    a.protocol_ownership_text                                         as protocol_ownership_text,
    a.da_committee_governance                                         as da_committee_governance,
    a.upgrade_authority_level                                         as upgrade_authority_level,
    a.ops_complexity_level                                            as ops_complexity_level,
    a.user_exit_risk_level                                            as user_exit_risk_level,
    a.production_status                                               as production_status,
    a.production_status_as_of_date                                    as production_status_as_of_date,
    a.ecosystem_lock_in_level                                         as ecosystem_lock_in_level,
    a.bridge_required_bool                                            as bridge_required_bool,
    a.migration_path_available                                        as migration_path_available,
    a.inclusion_rationale                                             as inclusion_rationale,
    a.inclusion_qualifier_note                                        as inclusion_qualifier_note,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.data_quality_flags                                              as data_quality_flags,
    a.not_applicable_reason                                           as sidecar_not_applicable_reason,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at
  from public.subsector_memberships m
  join public.projects p on p.id = m.project_id
  left join public.organizations o on o.slug = p.maintaining_organization
  left join public.projects fp on fp.id = p.forked_from
  left join public.projects mp on mp.id = p.migrated_to_project
  left join public.validium_attrs a on a.project_id = p.id
  where m.subsector_slug = 'validiums-volitions-hybrid';

comment on view public.validium_full_view is
  'Frontend convenience view: drives off subsector_memberships so cross-subsector entities '
  '(starkex / zk-stack / polygon-cdk / zksync-era) surface here alongside the 2 NEW rows. '
  'Joins projects + organizations + sidecar + forked_from + migrated_to lineage.';
