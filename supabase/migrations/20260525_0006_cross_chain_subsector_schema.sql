-- Market Map — Sector 6 / Cross-Chain Compute sidecar.
--
-- 1:1 sidecar table for Cross-Chain Compute. The key UI filter axis is
-- verification_strength_tier (derived at import from verification_mechanism_primary,
-- see enrich_advanced_compute.py) — btree indexed so the listing page can pivot
-- on tier without a sequential scan.
--
-- Five projects in this subsector carry a verbatim scope_annotation on
-- projects.scope_annotation (LayerZero, Wormhole, EigenLayer, Arbitrum,
-- Optimism). RISC Zero and Axiom additionally appear with
-- subsector_slug = 'cross-chain-compute' and subsector_slug_secondary =
-- 'ai-agents-and-autonomous-systems'; the importer writes sidecar rows for
-- them in both ai_agents_details and cross_chain_details.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.cross_chain_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  primary_users                         text,

  -- Execution location (dual-enum).
  execution_location_primary            text,
  execution_location_secondary          text,

  -- Execution type (dual-enum).
  execution_type_primary                text,
  execution_type_secondary              text,

  -- Supported chains (m2m via project_chains; raw kept for traceability).
  supported_chains_raw                  text,

  -- Verification mechanism (dual-enum).
  verification_mechanism_primary        text,
  verification_mechanism_secondary      text,
  verification_strength_tier            text,
    -- zk | optimistic | committee | multisig | tee | hybrid | other
    -- derived at import time from verification_mechanism_primary

  -- Who verifies execution (dual-enum).
  who_verifies_execution_primary        text,
  who_verifies_execution_secondary      text,

  dispute_resolution_model              text,
  finality_anchor                       text,
  finality_anchor_project_slug          text
    references public.projects(slug) on delete set null,

  -- Ethereum role (dual-enum).
  ethereum_role_primary                 text,
  ethereum_role_secondary               text,

  -- Tri-state.
  on_chain_verifiability_value          text,
  on_chain_verifiability_detail         text,

  failure_handling                      text,
  trust_assumptions                     text,

  slashing_bool                         boolean,
  slashing_detail                       text,

  key_trusted_parties                   text,

  -- Who pays fees (dual-enum).
  who_pays_fees_primary                 text,
  who_pays_fees_secondary               text,
  fee_model                             text,
  incentive_alignment                   text,

  composable_with_raw                   text,
  scalability_constraints               text,
  defensibility_source                  text,

  -- Sector adjacency snapshot + companion date.
  sector_adjacency_risk                 text,
  sector_adjacency_risk_as_of_date      date,

  -- Provenance.
  data_quality_flags                    text[] not null default '{}',
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  -- Snapshot-companion enforcement.
  constraint cross_chain_sector_adjacency_snapshot_date_check
    check (sector_adjacency_risk is null or sector_adjacency_risk_as_of_date is not null),

  -- Tier whitelist (matches enrich_advanced_compute derive_verification_tier()).
  constraint cross_chain_verification_strength_tier_check
    check (
      verification_strength_tier is null
      or verification_strength_tier in (
        'zk', 'optimistic', 'committee', 'multisig', 'tee', 'hybrid', 'other'
      )
    ),

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.cross_chain_details is
  '1:1 sidecar for Sector 6 / Cross-Chain Compute. verification_strength_tier '
  'is derived at import from verification_mechanism_primary and is the primary '
  'UI filter axis. finality_anchor_project_slug is a self-FK back to projects.';

-- Indexes (Invariant 6).
create index if not exists idx_cross_chain_verification_strength_tier
  on public.cross_chain_details (verification_strength_tier);
create index if not exists idx_cross_chain_execution_type_primary
  on public.cross_chain_details (execution_type_primary);
create index if not exists idx_cross_chain_execution_location_primary
  on public.cross_chain_details (execution_location_primary);
create index if not exists idx_cross_chain_finality_anchor
  on public.cross_chain_details (finality_anchor);
create index if not exists idx_cross_chain_finality_anchor_project_slug
  on public.cross_chain_details (finality_anchor_project_slug)
  where finality_anchor_project_slug is not null;
create index if not exists idx_cross_chain_on_chain_verifiability_value
  on public.cross_chain_details (on_chain_verifiability_value);

-- RLS.
alter table public.cross_chain_details enable row level security;
drop policy if exists "cross_chain_details_public_read" on public.cross_chain_details;
create policy "cross_chain_details_public_read"
  on public.cross_chain_details for select using (true);

drop trigger if exists trg_cross_chain_details_updated_at on public.cross_chain_details;
create trigger trg_cross_chain_details_updated_at
  before update on public.cross_chain_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. cross_chain_full_view.
-- ---------------------------------------------------------------------------

drop view if exists public.cross_chain_full_view;

create view public.cross_chain_full_view
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

    a.primary_users                                                   as primary_users,
    a.execution_location_primary                                      as execution_location_primary,
    a.execution_location_secondary                                    as execution_location_secondary,
    a.execution_type_primary                                          as execution_type_primary,
    a.execution_type_secondary                                        as execution_type_secondary,
    a.supported_chains_raw                                            as supported_chains_raw,
    a.verification_mechanism_primary                                  as verification_mechanism_primary,
    a.verification_mechanism_secondary                                as verification_mechanism_secondary,
    a.verification_strength_tier                                      as verification_strength_tier,
    a.who_verifies_execution_primary                                  as who_verifies_execution_primary,
    a.who_verifies_execution_secondary                                as who_verifies_execution_secondary,
    a.dispute_resolution_model                                        as dispute_resolution_model,
    a.finality_anchor                                                 as finality_anchor,
    a.finality_anchor_project_slug                                    as finality_anchor_project_slug,
    a.ethereum_role_primary                                           as ethereum_role_primary,
    a.ethereum_role_secondary                                         as ethereum_role_secondary,
    a.on_chain_verifiability_value                                    as on_chain_verifiability_value,
    a.on_chain_verifiability_detail                                   as on_chain_verifiability_detail,
    a.failure_handling                                                as failure_handling,
    a.trust_assumptions                                               as trust_assumptions,
    a.slashing_bool                                                   as slashing_bool,
    a.slashing_detail                                                 as slashing_detail,
    a.key_trusted_parties                                             as key_trusted_parties,
    a.who_pays_fees_primary                                           as who_pays_fees_primary,
    a.who_pays_fees_secondary                                         as who_pays_fees_secondary,
    a.fee_model                                                       as fee_model,
    a.incentive_alignment                                             as incentive_alignment,
    a.composable_with_raw                                             as composable_with_raw,
    a.scalability_constraints                                         as scalability_constraints,
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
  left join public.organizations o          on o.slug    = p.maintaining_organization
  left join public.cross_chain_details a    on a.project_id = p.id
  left join public.sectors s_meta           on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta      on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'cross-chain-compute';

comment on view public.cross_chain_full_view is
  'Read-time projection for Sector 6 / Cross-Chain Compute. Final 4 columns '
  'carry sector/subsector schema metadata per Invariant 5.';
