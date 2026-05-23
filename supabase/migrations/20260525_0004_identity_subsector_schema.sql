-- Market Map — Sector 6 / Identity & Social Graphs sidecar.
--
-- 1:1 sidecar table for the Identity subsector. Identifier and credential
-- standards are m2m via the shared project_identifier_standards /
-- project_credential_standards tables. The Worldcoin dual-subsector linkage
-- (identity primary, DePIN secondary) lives in
-- projects.subsector_slug_secondary; the view also surfaces rows whose
-- secondary is Identity so the frontend can show Worldcoin from the Identity
-- subsector page even when its primary subsector is something else.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.identity_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  primary_users                         text,

  -- Identity type (dual-enum).
  identity_type_primary                 text,
  identity_type_secondary               text,

  identifier_standard_raw               text,
  reputation_attestation_type           text,
  social_graph_model                    text,

  -- State persistence layer (dual-enum).
  state_persistence_layer_primary       text,
  state_persistence_layer_secondary     text,

  -- Ethereum role (dual-enum).
  ethereum_role_primary                 text,
  ethereum_role_secondary               text,

  -- Tri-state coercions (Yes / No / Partial / NULL + free text detail).
  on_chain_verifiability_value          text,
  on_chain_verifiability_detail         text,
  smart_contract_composability_value    text,
  smart_contract_composability_detail   text,

  cross_protocol_reusability            text,
    -- High | Medium | Low

  credential_standard_raw               text,
  who_can_issue_credentials             text,
  revocation_mechanism                  text,
  role_permission_enforcement           text,

  -- Sybil resistance (dual-enum).
  sybil_resistance_primary              text,
  sybil_resistance_secondary            text,

  -- Verification model (dual-enum).
  verification_model_primary            text,
  verification_model_secondary          text,
  key_trusted_parties                   text,

  -- Censorship / freeze risk snapshot + companion date.
  censorship_freeze_risk                text,
  censorship_freeze_risk_as_of_date     date,

  upgrade_governance_control            text,

  centralized_dependency_value          text,
  centralized_dependency_detail         text,

  scalability_constraints               text,
  primary_use_cases                     text,
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
  constraint identity_censorship_freeze_snapshot_date_check
    check (censorship_freeze_risk is null or censorship_freeze_risk_as_of_date is not null),
  constraint identity_sector_adjacency_snapshot_date_check
    check (sector_adjacency_risk is null or sector_adjacency_risk_as_of_date is not null),

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.identity_details is
  '1:1 sidecar for Sector 6 / Identity & Social Graphs. Identifier and '
  'credential standards live in shared m2m tables; tri-state value/detail '
  'pairs preserve nuance from the source sheet.';

-- Indexes (Invariant 6).
create index if not exists idx_identity_identity_type_primary
  on public.identity_details (identity_type_primary);
create index if not exists idx_identity_smart_contract_composability_value
  on public.identity_details (smart_contract_composability_value);
create index if not exists idx_identity_cross_protocol_reusability
  on public.identity_details (cross_protocol_reusability);
create index if not exists idx_identity_on_chain_verifiability_value
  on public.identity_details (on_chain_verifiability_value);
create index if not exists idx_identity_censorship_freeze_risk
  on public.identity_details (censorship_freeze_risk);

-- RLS.
alter table public.identity_details enable row level security;
drop policy if exists "identity_details_public_read" on public.identity_details;
create policy "identity_details_public_read"
  on public.identity_details for select using (true);

drop trigger if exists trg_identity_details_updated_at on public.identity_details;
create trigger trg_identity_details_updated_at
  before update on public.identity_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. identity_full_view.
-- ---------------------------------------------------------------------------

drop view if exists public.identity_full_view;

create view public.identity_full_view
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
    a.identity_type_primary                                           as identity_type_primary,
    a.identity_type_secondary                                         as identity_type_secondary,
    a.identifier_standard_raw                                         as identifier_standard_raw,
    a.reputation_attestation_type                                     as reputation_attestation_type,
    a.social_graph_model                                              as social_graph_model,
    a.state_persistence_layer_primary                                 as state_persistence_layer_primary,
    a.state_persistence_layer_secondary                               as state_persistence_layer_secondary,
    a.ethereum_role_primary                                           as ethereum_role_primary,
    a.ethereum_role_secondary                                         as ethereum_role_secondary,
    a.on_chain_verifiability_value                                    as on_chain_verifiability_value,
    a.on_chain_verifiability_detail                                   as on_chain_verifiability_detail,
    a.smart_contract_composability_value                              as smart_contract_composability_value,
    a.smart_contract_composability_detail                             as smart_contract_composability_detail,
    a.cross_protocol_reusability                                      as cross_protocol_reusability,
    a.credential_standard_raw                                         as credential_standard_raw,
    a.who_can_issue_credentials                                       as who_can_issue_credentials,
    a.revocation_mechanism                                            as revocation_mechanism,
    a.role_permission_enforcement                                     as role_permission_enforcement,
    a.sybil_resistance_primary                                        as sybil_resistance_primary,
    a.sybil_resistance_secondary                                      as sybil_resistance_secondary,
    a.verification_model_primary                                      as verification_model_primary,
    a.verification_model_secondary                                    as verification_model_secondary,
    a.key_trusted_parties                                             as key_trusted_parties,
    a.censorship_freeze_risk                                          as censorship_freeze_risk,
    a.censorship_freeze_risk_as_of_date                               as censorship_freeze_risk_as_of_date,
    a.upgrade_governance_control                                      as upgrade_governance_control,
    a.centralized_dependency_value                                    as centralized_dependency_value,
    a.centralized_dependency_detail                                   as centralized_dependency_detail,
    a.scalability_constraints                                         as scalability_constraints,
    a.primary_use_cases                                               as primary_use_cases,
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
  left join public.identity_details a   on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'identity-and-social-graphs';

comment on view public.identity_full_view is
  'Read-time projection for Sector 6 / Identity & Social Graphs. Final 4 '
  'columns carry sector/subsector schema metadata per Invariant 5.';
