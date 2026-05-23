-- Market Map — Sector 6 / DePIN (Physical Infrastructure) sidecar.
--
-- 1:1 sidecar table for the DePIN subsector. Note the source sheet tab is
-- misspelled "Infrastruture" (missing 'c'); the canonical slug uses the
-- corrected "infrastructure" spelling everywhere in code.
--
-- v1 models the *full* decentralization axis per ISS-S6-008 (Cursor decision
-- 2026-05-23): hardware_ownership_model + coordinator_topology +
-- slashing_or_penalty_mechanism_{bool,detail} + governance_control_dimension
-- are stored together so the project page can render the axis as a
-- multi-dimensional facet rather than collapsing it onto hardware ownership.
--
-- Helium sub-networks (IoT, Mobile, IOT-token derivatives) use
-- projects.parent_project_slug = 'helium' once the sheet has separate rows.
-- For now only the canonical Helium row exists; see data_gaps.md ISS-S6-004.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.depin_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Primary participants (dual-enum).
  primary_participants_primary          text,
  primary_participants_secondary        text,

  -- Physical asset type (dual-enum).
  physical_asset_type_primary           text,
  physical_asset_type_secondary         text,

  -- Decentralization axis (v1 full axis — ISS-S6-008).
  hardware_ownership_model              text,
    -- Operators | Network-owned | Hybrid
  coordinator_topology                  text,
    -- single-foundation | multi-operator-coordinated | permissionless
    -- single-sequencer | rotating-committee | hybrid
  governance_control_dimension          text,
    -- foundation | token-holder-dao | multisig | operator-quorum | hybrid
  slashing_or_penalty_mechanism_bool    boolean,
  slashing_or_penalty_mechanism_detail  text,

  -- Geographic distribution snapshot + companion date + detail.
  geographic_distribution_value         text,
    -- Global | Regional | Concentrated | Single-jurisdiction
  geographic_distribution_as_of_date    date,
  geographic_distribution_detail        text,
  minimum_physical_requirements         text,

  -- Ethereum role (dual-enum).
  ethereum_role_primary                 text,
  ethereum_role_secondary               text,
  on_chain_settlement_scope             text,
  reward_distribution                   text,

  -- Physical activity measured (dual-enum).
  physical_activity_primary             text,
  physical_activity_secondary           text,

  -- Verification method (dual-enum).
  verification_method_primary           text,
  verification_method_secondary         text,
  anti_cheating                         text,
  trusted_components                    text,

  -- Who pays (dual-enum).
  who_pays_primary                      text,
  who_pays_secondary                    text,
  token_incentive_model                 text,
  cost_structure_operators              text,

  governance_model                      text,
  upgrade_control                       text,

  -- Centralized dependency tri-state.
  centralized_dependency_value          text,
  centralized_dependency_detail         text,

  -- Risk factors (dual-enum).
  primary_risk_factor_1                 text,
  primary_risk_factor_2                 text,
  scalability_constraints               text,

  -- Censorship / geographic risk snapshot + companion date.
  censorship_geographic_risk            text,
  censorship_geographic_risk_as_of_date date,

  composable_with_raw                   text,
  defensibility_source                  text,

  -- Sector adjacency snapshot + companion date.
  sector_adjacency_risk                 text,
  sector_adjacency_risk_as_of_date      date,

  -- Provenance.
  data_quality_flags                    text[] not null default '{}',
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  -- Snapshot-companion enforcement.
  constraint depin_geographic_distribution_snapshot_date_check
    check (geographic_distribution_value is null or geographic_distribution_as_of_date is not null),
  constraint depin_censorship_geographic_snapshot_date_check
    check (censorship_geographic_risk is null or censorship_geographic_risk_as_of_date is not null),
  constraint depin_sector_adjacency_snapshot_date_check
    check (sector_adjacency_risk is null or sector_adjacency_risk_as_of_date is not null),

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.depin_details is
  '1:1 sidecar for Sector 6 / DePIN (Physical Infrastructure). v1 models the '
  'full decentralization axis (hardware_ownership_model + coordinator_topology + '
  'slashing booleans + governance_control_dimension) per ISS-S6-008.';

-- Indexes (Invariant 6).
create index if not exists idx_depin_physical_asset_type_primary
  on public.depin_details (physical_asset_type_primary);
create index if not exists idx_depin_verification_method_primary
  on public.depin_details (verification_method_primary);
create index if not exists idx_depin_geographic_distribution_value
  on public.depin_details (geographic_distribution_value);
create index if not exists idx_depin_hardware_ownership_model
  on public.depin_details (hardware_ownership_model);
create index if not exists idx_depin_coordinator_topology
  on public.depin_details (coordinator_topology);
create index if not exists idx_depin_governance_control_dimension
  on public.depin_details (governance_control_dimension);
create index if not exists idx_depin_centralized_dependency_value
  on public.depin_details (centralized_dependency_value);

-- RLS.
alter table public.depin_details enable row level security;
drop policy if exists "depin_details_public_read" on public.depin_details;
create policy "depin_details_public_read"
  on public.depin_details for select using (true);

drop trigger if exists trg_depin_details_updated_at on public.depin_details;
create trigger trg_depin_details_updated_at
  before update on public.depin_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. depin_full_view.
--
-- Includes rows whose subsector_slug_secondary = 'depin-physical-infrastructure'
-- so Worldcoin (Identity primary) and Bittensor (AI Agents primary) appear on
-- the DePIN subsector listing as well as their primary subsector listing.
-- ---------------------------------------------------------------------------

drop view if exists public.depin_full_view;

create view public.depin_full_view
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

    a.primary_participants_primary                                    as primary_participants_primary,
    a.primary_participants_secondary                                  as primary_participants_secondary,
    a.physical_asset_type_primary                                     as physical_asset_type_primary,
    a.physical_asset_type_secondary                                   as physical_asset_type_secondary,
    a.hardware_ownership_model                                        as hardware_ownership_model,
    a.coordinator_topology                                            as coordinator_topology,
    a.governance_control_dimension                                    as governance_control_dimension,
    a.slashing_or_penalty_mechanism_bool                              as slashing_or_penalty_mechanism_bool,
    a.slashing_or_penalty_mechanism_detail                            as slashing_or_penalty_mechanism_detail,
    a.geographic_distribution_value                                   as geographic_distribution_value,
    a.geographic_distribution_as_of_date                              as geographic_distribution_as_of_date,
    a.geographic_distribution_detail                                  as geographic_distribution_detail,
    a.minimum_physical_requirements                                   as minimum_physical_requirements,
    a.ethereum_role_primary                                           as ethereum_role_primary,
    a.ethereum_role_secondary                                         as ethereum_role_secondary,
    a.on_chain_settlement_scope                                       as on_chain_settlement_scope,
    a.reward_distribution                                             as reward_distribution,
    a.physical_activity_primary                                       as physical_activity_primary,
    a.physical_activity_secondary                                     as physical_activity_secondary,
    a.verification_method_primary                                     as verification_method_primary,
    a.verification_method_secondary                                   as verification_method_secondary,
    a.anti_cheating                                                   as anti_cheating,
    a.trusted_components                                              as trusted_components,
    a.who_pays_primary                                                as who_pays_primary,
    a.who_pays_secondary                                              as who_pays_secondary,
    a.token_incentive_model                                           as token_incentive_model,
    a.cost_structure_operators                                        as cost_structure_operators,
    a.governance_model                                                as governance_model,
    a.upgrade_control                                                 as upgrade_control,
    a.centralized_dependency_value                                    as centralized_dependency_value,
    a.centralized_dependency_detail                                   as centralized_dependency_detail,
    a.primary_risk_factor_1                                           as primary_risk_factor_1,
    a.primary_risk_factor_2                                           as primary_risk_factor_2,
    a.scalability_constraints                                         as scalability_constraints,
    a.censorship_geographic_risk                                      as censorship_geographic_risk,
    a.censorship_geographic_risk_as_of_date                           as censorship_geographic_risk_as_of_date,
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
  left join public.depin_details a      on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'depin-physical-infrastructure'
     or p.subsector_slug_secondary = 'depin-physical-infrastructure';

comment on view public.depin_full_view is
  'Read-time projection for Sector 6 / DePIN. Final 4 columns carry '
  'sector/subsector schema metadata per Invariant 5. Includes dual-subsector '
  'projects (Worldcoin from Identity, Bittensor from AI Agents) via '
  'subsector_slug_secondary.';
