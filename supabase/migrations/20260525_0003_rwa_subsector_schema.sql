-- Market Map — Sector 6 / Real-World Assets (RWAs) sidecar.
--
-- 1:1 sidecar table for the RWA subsector. Carries the typed legal /
-- regulatory / custody columns needed for filtering plus two self-FK pointers
-- (tokenization_platform_slug, identity_provider_project_slug) so the project
-- page can render relationships between RWA primitives.
--
-- Jurisdictions, regulatory frameworks, token standards, and custodians are
-- m2m via the dedicated tables seeded in the sector-common migration.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.rwa_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Jurisdictions raw (m2m exploded into project_jurisdictions +
  -- project_regulatory_frameworks by the importer).
  jurisdictions_raw                     text,

  -- Asset class (dual-enum).
  asset_class_primary                   text,
  asset_class_secondary                 text,
  asset_issuer                          text,
  asset_issuer_as_of_date               date,
  is_dao_issuer                         boolean not null default false,
  legal_structure                       text,
  jurisdiction_legal_enforceability     text,
  redemption_rights                     text,
  investor_rights                       text,

  -- Ethereum role (dual-enum).
  ethereum_role_primary                 text,
  ethereum_role_secondary               text,

  -- Token standards raw (m2m exploded into project_token_standards).
  token_standard_raw                    text,

  -- On-chain lifecycle (dual-enum).
  on_chain_lifecycle_primary            text,
  on_chain_lifecycle_secondary          text,
  bidirectional_sync                    text,
  final_source_of_truth                 text,
    -- Off-chain registry | On-chain | Both
  kyc_aml_enforcement                   text,
  transfer_restrictions                 text,

  -- Permissioning model (dual-enum).
  permissioning_model_primary           text,
  permissioning_model_secondary         text,
  identity_provider_dependency          text,
  identity_provider_project_slug        text
    references public.projects(slug) on delete set null,

  -- Who pays fees (dual-enum).
  who_pays_fees_primary                 text,
  who_pays_fees_secondary               text,
  fee_model                             text,
  cash_flow_handling                    text,

  -- Custodians (m2m exploded into project_custodians; raw kept + as-of date).
  custodians_raw                        text,
  custodians_as_of_date                 date,
  key_trusted_parties                   text,

  -- Risk factors (dual-enum).
  primary_risk_factor_1                 text,
  primary_risk_factor_2                 text,
  dispute_resolution                    text,

  -- Censorship / freeze risk snapshot + companion date.
  censorship_freeze_risk                text,
  censorship_freeze_risk_as_of_date     date,

  primary_customers                     text,
  composable_with_defi                  text,
    -- Yes | No | Limited
  scalability_constraints               text,
  defensibility_source                  text,

  -- Sector adjacency snapshot + companion date.
  sector_adjacency_risk                 text,
  sector_adjacency_risk_as_of_date      date,

  -- Tokenization platform self-FK (e.g. BUIDL → securitize).
  tokenization_platform_slug            text
    references public.projects(slug) on delete set null,

  -- Provenance.
  data_quality_flags                    text[] not null default '{}',
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  -- Snapshot-companion enforcement.
  constraint rwa_asset_issuer_snapshot_date_check
    check (asset_issuer is null or asset_issuer_as_of_date is not null),
  constraint rwa_custodians_snapshot_date_check
    check (custodians_raw is null or custodians_as_of_date is not null),
  constraint rwa_censorship_freeze_snapshot_date_check
    check (censorship_freeze_risk is null or censorship_freeze_risk_as_of_date is not null),
  constraint rwa_sector_adjacency_snapshot_date_check
    check (sector_adjacency_risk is null or sector_adjacency_risk_as_of_date is not null),

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.rwa_details is
  '1:1 sidecar for Sector 6 / Real-World Assets (RWAs). Self-FKs to '
  'tokenization platform and identity provider; jurisdictions, custodians, '
  'regulatory frameworks, and token standards are m2m on the shared tables.';

-- Indexes (Invariant 6).
create index if not exists idx_rwa_asset_class_primary
  on public.rwa_details (asset_class_primary);
create index if not exists idx_rwa_final_source_of_truth
  on public.rwa_details (final_source_of_truth);
create index if not exists idx_rwa_composable_with_defi
  on public.rwa_details (composable_with_defi);
create index if not exists idx_rwa_tokenization_platform_slug
  on public.rwa_details (tokenization_platform_slug)
  where tokenization_platform_slug is not null;
create index if not exists idx_rwa_identity_provider_project_slug
  on public.rwa_details (identity_provider_project_slug)
  where identity_provider_project_slug is not null;
create index if not exists idx_rwa_is_dao_issuer
  on public.rwa_details (is_dao_issuer)
  where is_dao_issuer;
create index if not exists idx_rwa_censorship_freeze_risk
  on public.rwa_details (censorship_freeze_risk);

-- RLS.
alter table public.rwa_details enable row level security;
drop policy if exists "rwa_details_public_read" on public.rwa_details;
create policy "rwa_details_public_read"
  on public.rwa_details for select using (true);

drop trigger if exists trg_rwa_details_updated_at on public.rwa_details;
create trigger trg_rwa_details_updated_at
  before update on public.rwa_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. rwa_full_view.
-- ---------------------------------------------------------------------------

drop view if exists public.rwa_full_view;

create view public.rwa_full_view
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

    a.jurisdictions_raw                                               as jurisdictions_raw,
    a.asset_class_primary                                             as asset_class_primary,
    a.asset_class_secondary                                           as asset_class_secondary,
    a.asset_issuer                                                    as asset_issuer,
    a.asset_issuer_as_of_date                                         as asset_issuer_as_of_date,
    a.is_dao_issuer                                                   as is_dao_issuer,
    a.legal_structure                                                 as legal_structure,
    a.jurisdiction_legal_enforceability                               as jurisdiction_legal_enforceability,
    a.redemption_rights                                               as redemption_rights,
    a.investor_rights                                                 as investor_rights,
    a.ethereum_role_primary                                           as ethereum_role_primary,
    a.ethereum_role_secondary                                         as ethereum_role_secondary,
    a.token_standard_raw                                              as token_standard_raw,
    a.on_chain_lifecycle_primary                                      as on_chain_lifecycle_primary,
    a.on_chain_lifecycle_secondary                                    as on_chain_lifecycle_secondary,
    a.bidirectional_sync                                              as bidirectional_sync,
    a.final_source_of_truth                                           as final_source_of_truth,
    a.kyc_aml_enforcement                                             as kyc_aml_enforcement,
    a.transfer_restrictions                                           as transfer_restrictions,
    a.permissioning_model_primary                                     as permissioning_model_primary,
    a.permissioning_model_secondary                                   as permissioning_model_secondary,
    a.identity_provider_dependency                                    as identity_provider_dependency,
    a.identity_provider_project_slug                                  as identity_provider_project_slug,
    a.who_pays_fees_primary                                           as who_pays_fees_primary,
    a.who_pays_fees_secondary                                         as who_pays_fees_secondary,
    a.fee_model                                                       as fee_model,
    a.cash_flow_handling                                              as cash_flow_handling,
    a.custodians_raw                                                  as custodians_raw,
    a.custodians_as_of_date                                           as custodians_as_of_date,
    a.key_trusted_parties                                             as key_trusted_parties,
    a.primary_risk_factor_1                                           as primary_risk_factor_1,
    a.primary_risk_factor_2                                           as primary_risk_factor_2,
    a.dispute_resolution                                              as dispute_resolution,
    a.censorship_freeze_risk                                          as censorship_freeze_risk,
    a.censorship_freeze_risk_as_of_date                               as censorship_freeze_risk_as_of_date,
    a.primary_customers                                               as primary_customers,
    a.composable_with_defi                                            as composable_with_defi,
    a.scalability_constraints                                         as scalability_constraints,
    a.defensibility_source                                            as defensibility_source,
    a.sector_adjacency_risk                                           as sector_adjacency_risk,
    a.sector_adjacency_risk_as_of_date                                as sector_adjacency_risk_as_of_date,
    a.tokenization_platform_slug                                      as tokenization_platform_slug,
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
  left join public.organizations o    on o.slug    = p.maintaining_organization
  left join public.rwa_details a      on a.project_id = p.id
  left join public.sectors s_meta     on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'real-world-assets-rwas';

comment on view public.rwa_full_view is
  'Read-time projection for Sector 6 / Real-World Assets (RWAs). Final 4 '
  'columns carry sector/subsector schema metadata per Invariant 5.';
