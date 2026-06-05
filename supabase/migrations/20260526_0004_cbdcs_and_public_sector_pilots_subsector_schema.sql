-- Market Map — Sector 7 / CBDCs & Public Sector Pilots sidecar.
--
-- NOTE: This subsector tab has NO 'Year Launched' column and NO 'Mainnet Status'
-- column. The temporal status is 'Pilot vs Production' (stored verbatim in the
-- sidecar as pilot_vs_production for filtering, and ALSO mapped into
-- projects.mainnet_status: Pilot→'pilot', Production→'live',
-- 'Selective production'→'pilot', Concluded→'concluded'). See ISS-S7-004.
--
-- View registered in SUBSECTOR_VIEW_REGISTRY in the same PR.

create table if not exists public.cbdcs_and_public_sector_pilots_details (
  project_id                             uuid primary key
    references public.projects(id) on delete cascade,

  entity_archetype                       text,
  jurisdiction_authority                 text,
  program_classification                 text,
  pilot_vs_production                    text,

  primary_public_sector_function         text,
  target_participants                    text[] not null default '{}',

  ethereum_dependency                    text,
  ethereum_role                          text,
  ethereum_environment_used              text,
  public_vs_permissioned_design          text,

  issuance_authority                     text,
  governance_model                       text,
  privacy_model                          text,
  aml_kyc_layer                          text,
  interoperability_with_legacy_systems   text,
  key_partners                           text[] not null default '{}',
  compliance_legal_status                text,
  pilot_outcomes_status                  text,
  production_readiness                   text,

  data_quality_flags                     text[] not null default '{}',
  data_refreshed_at                      timestamptz,
  data_confidence                        text default 'estimate',

  created_at                             timestamptz not null default now(),
  updated_at                             timestamptz not null default now()
);

comment on table public.cbdcs_and_public_sector_pilots_details is
  '1:1 sidecar for Sector 7 / CBDCs & Public Sector Pilots. Note: this subsector '
  'has no Year Launched or Mainnet Status columns in the source sheet; '
  'pilot_vs_production is the temporal status marker, dual-mapped into '
  'projects.mainnet_status at ingest. See ISS-S7-004.';

create index if not exists idx_cbdc_pilot_vs_production
  on public.cbdcs_and_public_sector_pilots_details (pilot_vs_production);
create index if not exists idx_cbdc_jurisdiction_authority
  on public.cbdcs_and_public_sector_pilots_details (jurisdiction_authority);
create index if not exists idx_cbdc_ethereum_dependency
  on public.cbdcs_and_public_sector_pilots_details (ethereum_dependency);
create index if not exists idx_cbdc_production_readiness
  on public.cbdcs_and_public_sector_pilots_details (production_readiness);
create index if not exists idx_cbdc_issuance_authority
  on public.cbdcs_and_public_sector_pilots_details (issuance_authority);
create index if not exists idx_cbdc_governance_model
  on public.cbdcs_and_public_sector_pilots_details (governance_model);
create index if not exists idx_cbdc_public_vs_permissioned_design
  on public.cbdcs_and_public_sector_pilots_details (public_vs_permissioned_design);

alter table public.cbdcs_and_public_sector_pilots_details enable row level security;
drop policy if exists "cbdcs_and_public_sector_pilots_details_public_read"
  on public.cbdcs_and_public_sector_pilots_details;
create policy "cbdcs_and_public_sector_pilots_details_public_read"
  on public.cbdcs_and_public_sector_pilots_details for select using (true);

drop trigger if exists trg_cbdcs_and_public_sector_pilots_details_updated_at
  on public.cbdcs_and_public_sector_pilots_details;
create trigger trg_cbdcs_and_public_sector_pilots_details_updated_at
  before update on public.cbdcs_and_public_sector_pilots_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- View.
-- ---------------------------------------------------------------------------

drop view if exists public.cbdcs_and_public_sector_pilots_full_view;

create view public.cbdcs_and_public_sector_pilots_full_view
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

    p.entity_type                                                     as entity_type,
    p.entity_archetype                                                as entity_archetype_universal,
    p.maintaining_organization                                        as maintaining_organization,
    p.maintaining_organization_raw                                    as maintaining_organization_raw,
    p.year_launched_int                                               as year_launched_int,
    p.year_launched_text                                              as year_launched_text,
    p.mainnet_status                                                  as mainnet_status,
    p.mainnet_status_as_of_date                                       as mainnet_status_as_of_date,
    p.deprecation_note                                                as deprecation_note,
    p.one_line_description                                            as one_line_description,
    p.practitioner_note                                               as practitioner_note,
    p.practitioner_validation_check                                   as practitioner_validation_check,
    p.subsector_scope_of                                              as subsector_scope_of,
    p.scope_annotation                                                as scope_annotation,
    p.parent_project_slug                                             as parent_project_slug,
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

    d.entity_archetype                                                as entity_archetype,
    d.jurisdiction_authority                                          as jurisdiction_authority,
    d.program_classification                                          as program_classification,
    d.pilot_vs_production                                             as pilot_vs_production,
    d.primary_public_sector_function                                  as primary_public_sector_function,
    d.target_participants                                             as target_participants,
    d.ethereum_dependency                                             as ethereum_dependency,
    d.ethereum_role                                                   as ethereum_role,
    d.ethereum_environment_used                                       as ethereum_environment_used,
    d.public_vs_permissioned_design                                   as public_vs_permissioned_design,
    d.issuance_authority                                              as issuance_authority,
    d.governance_model                                                as governance_model,
    d.privacy_model                                                   as privacy_model,
    d.aml_kyc_layer                                                   as aml_kyc_layer,
    d.interoperability_with_legacy_systems                            as interoperability_with_legacy_systems,
    d.key_partners                                                    as key_partners,
    d.compliance_legal_status                                         as compliance_legal_status,
    d.pilot_outcomes_status                                           as pilot_outcomes_status,
    d.production_readiness                                            as production_readiness,
    d.data_quality_flags                                              as data_quality_flags,
    d.data_refreshed_at                                               as data_refreshed_at,
    d.data_confidence                                                 as data_confidence,

    p.created_at                                                      as created_at,
    p.updated_at                                                      as updated_at,

    s_meta.name                                                       as sector_name,
    sub_meta.name                                                     as subsector_name,
    s_meta.common_field_schema                                        as sector_common_field_schema,
    sub_meta.specific_field_schema                                    as subsector_specific_field_schema
  from public.projects p
  left join public.organizations o                                  on o.slug = p.maintaining_organization
  left join public.cbdcs_and_public_sector_pilots_details d         on d.project_id = p.id
  left join public.sectors s_meta                                    on s_meta.slug = p.sector_slug
  left join public.subsectors sub_meta                               on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'cbdcs-and-public-sector-pilots';

comment on view public.cbdcs_and_public_sector_pilots_full_view is
  'Read-time projection for Sector 7 / CBDCs & Public Sector Pilots.';

-- ---------------------------------------------------------------------------
-- Subsector specific_field_schema.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/cbdcs-and-public-sector-pilots.json",
  "title": "CBDCs & Public Sector Pilots — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_archetype":                       { "title": "Entity archetype", "type": "string" },
    "jurisdiction_authority":                 { "title": "Jurisdiction / authority", "type": "string" },
    "program_classification":                 { "title": "Program classification", "type": "string" },
    "pilot_vs_production":                    { "title": "Pilot vs production", "type": "string", "description": "Replaces year_launched/mainnet_status for this subsector. Also dual-written to projects.mainnet_status." },
    "primary_public_sector_function":         { "title": "Primary public-sector function", "type": "string" },
    "target_participants":                    { "title": "Target participants", "type": "array", "items": { "type": "string" } },
    "ethereum_dependency":                    { "title": "Ethereum dependency", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "ethereum_role":                          { "title": "Ethereum role", "type": "string" },
    "ethereum_environment_used":              { "title": "Ethereum environment used", "type": "string" },
    "public_vs_permissioned_design":          { "title": "Public vs permissioned design", "type": "string" },
    "issuance_authority":                     { "title": "Issuance authority", "type": "string" },
    "governance_model":                       { "title": "Governance model", "type": "string" },
    "privacy_model":                          { "title": "Privacy model", "type": "string" },
    "aml_kyc_layer":                          { "title": "AML / KYC layer", "type": "string" },
    "interoperability_with_legacy_systems":   { "title": "Interoperability with legacy systems", "type": "string" },
    "key_partners":                           { "title": "Key partners", "type": "array", "items": { "type": "string" } },
    "compliance_legal_status":                { "title": "Compliance & legal status", "type": "string" },
    "pilot_outcomes_status":                  { "title": "Pilot outcomes / status", "type": "string" },
    "production_readiness":                   { "title": "Production readiness", "type": "string", "enum": ["High", "Medium-High", "Medium", "Low-Medium", "Low"] }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'cbdcs-and-public-sector-pilots';
