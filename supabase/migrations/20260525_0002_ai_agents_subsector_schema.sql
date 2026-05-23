-- Market Map — Sector 6 / AI Agents & Autonomous Systems sidecar.
--
-- 1:1 sidecar table for the AI Agents subsector. Typed columns are filterable
-- and indexed; the long-form practitioner narrative is dual-written into
-- projects.subsector_attributes by enrich_advanced_compute.py so existing
-- prose/list rendering on the project page still works.
--
-- View ai_agents_full_view registered in SUBSECTOR_VIEW_REGISTRY in the same
-- PR so the sidecar columns surface through the project_detail endpoint.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.ai_agents_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Functional classification.
  primary_use_case                      text,
  target_users                          text,
  primary_agent_function                text,

  -- Ethereum role (dual-enum at import).
  ethereum_role_primary                 text,
  ethereum_role_secondary               text,

  -- Chains supported (m2m via project_chains; raw value kept for traceability).
  chains_supported_raw                  text,

  -- On-chain execution scope (dual-enum).
  on_chain_execution_scope_primary      text,
  on_chain_execution_scope_secondary    text,

  -- Boolean / tri-state.
  autonomous_on_chain_actions_bool      boolean,
  autonomous_on_chain_actions_detail    text,

  autonomy_level                        text,
    -- Goal-Driven | Reactive | Supervised | Limited

  -- Off-chain compute location (dual-enum).
  off_chain_compute_location_primary    text,
  off_chain_compute_location_secondary  text,

  inference_planning_method             text,

  -- State persistence model (dual-enum).
  state_persistence_model_primary       text,
  state_persistence_model_secondary     text,

  human_override_capability             text,

  -- Verification model (dual-enum).
  verification_model_primary            text,
  verification_model_secondary          text,

  -- Auditability snapshot + companion date.
  auditability                          text,
  auditability_as_of_date               date,

  replayability                         text,
  failure_handling                      text,
  agent_identity_model                  text,
  permissioning_model                   text,
  role_based_controls_bool              boolean,
  sybil_resistance                      text,

  -- Who pays (dual-enum).
  who_pays_primary                      text,
  who_pays_secondary                    text,
  fee_incentive_model                   text,

  slashing_bool                         boolean,
  slashing_detail                       text,

  -- Value accrual (dual-enum).
  value_accrual_primary                 text,
  value_accrual_secondary               text,

  -- External dependencies (dual-enum).
  external_dependencies_primary         text,
  external_dependencies_secondary       text,

  -- Risk factors (dual-enum).
  primary_risk_factor_1                 text,
  primary_risk_factor_2                 text,

  -- Censorship resistance snapshot + companion date.
  censorship_resistance                 text,
  censorship_resistance_as_of_date      date,

  upgrade_governance_control            text,
  composable_with_raw                   text,
  defensibility_source                  text,

  -- Sector adjacency snapshot + companion date.
  sector_adjacency_risk                 text,
  sector_adjacency_risk_as_of_date      date,

  -- Provenance.
  data_quality_flags                    text[] not null default '{}',
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  -- Snapshot-companion enforcement (Invariant per Section B.5).
  constraint ai_agents_auditability_snapshot_date_check
    check (auditability is null or auditability_as_of_date is not null),
  constraint ai_agents_censorship_resistance_snapshot_date_check
    check (censorship_resistance is null or censorship_resistance_as_of_date is not null),
  constraint ai_agents_sector_adjacency_snapshot_date_check
    check (sector_adjacency_risk is null or sector_adjacency_risk_as_of_date is not null),

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.ai_agents_details is
  '1:1 sidecar for Sector 6 / AI Agents & Autonomous Systems. Typed cols are '
  'filterable; long-form fields are dual-written into projects.subsector_attributes.';

-- Indexes (Invariant 6 — btree every filter/join column).
create index if not exists idx_ai_agents_autonomy_level
  on public.ai_agents_details (autonomy_level);
create index if not exists idx_ai_agents_verification_model_primary
  on public.ai_agents_details (verification_model_primary);
create index if not exists idx_ai_agents_ethereum_role_primary
  on public.ai_agents_details (ethereum_role_primary);
create index if not exists idx_ai_agents_on_chain_execution_scope_primary
  on public.ai_agents_details (on_chain_execution_scope_primary);
create index if not exists idx_ai_agents_auditability
  on public.ai_agents_details (auditability);

-- RLS.
alter table public.ai_agents_details enable row level security;
drop policy if exists "ai_agents_details_public_read" on public.ai_agents_details;
create policy "ai_agents_details_public_read"
  on public.ai_agents_details for select using (true);

drop trigger if exists trg_ai_agents_details_updated_at on public.ai_agents_details;
create trigger trg_ai_agents_details_updated_at
  before update on public.ai_agents_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. ai_agents_full_view — joins projects + organizations + sidecar +
--    sector/subsector schema metadata. Final 4 columns MUST be the
--    schema-passthrough block (Invariant 5).
-- ---------------------------------------------------------------------------

drop view if exists public.ai_agents_full_view;

create view public.ai_agents_full_view
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

    p.subsector_slug_secondary                                        as subsector_slug_secondary,
    p.is_pattern                                                      as is_pattern,
    p.entity_type                                                     as entity_type,
    p.entity_archetype                                                as entity_archetype,
    p.maintaining_organization                                        as maintaining_organization,
    p.maintaining_organization_raw                                    as maintaining_organization_raw,
    p.year_launched_text                                              as year_launched_text,
    p.year_launched_int                                               as year_launched_int,
    p.mainnet_status                                                  as mainnet_status,
    p.mainnet_status_as_of_date                                       as mainnet_status_as_of_date,
    p.one_line_description                                            as one_line_description,
    p.practitioner_note                                               as practitioner_note,
    p.practitioner_validation_check                                   as practitioner_validation_check,
    p.parent_project_slug                                             as parent_project_slug,
    p.scope_annotation                                                as scope_annotation,
    p.description_long                                                as description_long,
    p.reason_for_inclusion                                            as reason_for_inclusion,

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
    o.last_funding_round                                              as org_last_funding_round,
    o.last_funding_date                                               as org_last_funding_date,

    a.primary_use_case                                                as primary_use_case,
    a.target_users                                                    as target_users,
    a.primary_agent_function                                          as primary_agent_function,
    a.ethereum_role_primary                                           as ethereum_role_primary,
    a.ethereum_role_secondary                                         as ethereum_role_secondary,
    a.chains_supported_raw                                            as chains_supported_raw,
    a.on_chain_execution_scope_primary                                as on_chain_execution_scope_primary,
    a.on_chain_execution_scope_secondary                              as on_chain_execution_scope_secondary,
    a.autonomous_on_chain_actions_bool                                as autonomous_on_chain_actions_bool,
    a.autonomous_on_chain_actions_detail                              as autonomous_on_chain_actions_detail,
    a.autonomy_level                                                  as autonomy_level,
    a.off_chain_compute_location_primary                              as off_chain_compute_location_primary,
    a.off_chain_compute_location_secondary                            as off_chain_compute_location_secondary,
    a.inference_planning_method                                       as inference_planning_method,
    a.state_persistence_model_primary                                 as state_persistence_model_primary,
    a.state_persistence_model_secondary                               as state_persistence_model_secondary,
    a.human_override_capability                                       as human_override_capability,
    a.verification_model_primary                                      as verification_model_primary,
    a.verification_model_secondary                                    as verification_model_secondary,
    a.auditability                                                    as auditability,
    a.auditability_as_of_date                                         as auditability_as_of_date,
    a.replayability                                                   as replayability,
    a.failure_handling                                                as failure_handling,
    a.agent_identity_model                                            as agent_identity_model,
    a.permissioning_model                                             as permissioning_model,
    a.role_based_controls_bool                                        as role_based_controls_bool,
    a.sybil_resistance                                                as sybil_resistance,
    a.who_pays_primary                                                as who_pays_primary,
    a.who_pays_secondary                                              as who_pays_secondary,
    a.fee_incentive_model                                             as fee_incentive_model,
    a.slashing_bool                                                   as slashing_bool,
    a.slashing_detail                                                 as slashing_detail,
    a.value_accrual_primary                                           as value_accrual_primary,
    a.value_accrual_secondary                                         as value_accrual_secondary,
    a.external_dependencies_primary                                   as external_dependencies_primary,
    a.external_dependencies_secondary                                 as external_dependencies_secondary,
    a.primary_risk_factor_1                                           as primary_risk_factor_1,
    a.primary_risk_factor_2                                           as primary_risk_factor_2,
    a.censorship_resistance                                           as censorship_resistance,
    a.censorship_resistance_as_of_date                                as censorship_resistance_as_of_date,
    a.upgrade_governance_control                                      as upgrade_governance_control,
    a.composable_with_raw                                             as composable_with_raw,
    a.defensibility_source                                            as defensibility_source,
    a.sector_adjacency_risk                                           as sector_adjacency_risk,
    a.sector_adjacency_risk_as_of_date                                as sector_adjacency_risk_as_of_date,
    a.data_quality_flags                                              as data_quality_flags,
    a.data_refreshed_at                                               as data_refreshed_at,
    a.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at,

    s_meta.name                                                       as sector_name,
    sub_meta.name                                                     as subsector_name,
    s_meta.common_field_schema                                        as sector_common_field_schema,
    sub_meta.specific_field_schema                                    as subsector_specific_field_schema
  from public.projects p
  left join public.organizations o      on o.slug    = p.maintaining_organization
  left join public.ai_agents_details a  on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'ai-agents-and-autonomous-systems'
     or p.subsector_slug_secondary = 'ai-agents-and-autonomous-systems';

comment on view public.ai_agents_full_view is
  'Read-time projection for Sector 6 / AI Agents & Autonomous Systems. Final 4 '
  'columns carry sector/subsector schema metadata per Invariant 5. Includes '
  'dual-subsector projects (Bittensor, RISC Zero, Axiom) by also matching on '
  'subsector_slug_secondary.';
