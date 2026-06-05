-- Market Map — Sector 7 / Compliance & Regulatory Intelligence sidecar.
--
-- Trailing ' (<vendor>)' attribution tokens in source cells are stripped at
-- ingest (ISS-S7-014) and preserved in projects.sector_attributes.value_source_attribution
-- per the sector common schema.
--
-- View registered in SUBSECTOR_VIEW_REGISTRY in the same PR.

create table if not exists public.compliance_and_regulatory_intelligence_details (
  project_id                          uuid primary key
    references public.projects(id) on delete cascade,

  entity_archetype                    text,

  primary_compliance_function         text,
  secondary_compliance_functions      text[] not null default '{}',
  supported_compliance_domains        text[] not null default '{}',
  target_users                        text[] not null default '{}',

  ethereum_dependency                 text,
  ethereum_data_coverage              text,
  real_time_vs_historical             text,
  cross_chain_coverage                text,

  address_attribution_methodology     text,
  risk_scoring_model                  text,
  explainability                      text,
  sanctions_watchlist_integration     text,
  travel_rule_support                 text,
  case_management_investigations      text,
  reporting_audit_outputs             text,
  access_controls_permissions         text,
  institutional_regulator_adoption    text,

  data_quality_flags                  text[] not null default '{}',
  data_refreshed_at                   timestamptz,
  data_confidence                     text default 'estimate',

  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

comment on table public.compliance_and_regulatory_intelligence_details is
  '1:1 sidecar for Sector 7 / Compliance & Regulatory Intelligence. Trailing '
  '(<vendor>) tokens stripped from free-text fields at ingest per ISS-S7-014; '
  'preserved in projects.sector_attributes.value_source_attribution.';

create index if not exists idx_compliance_ethereum_dependency
  on public.compliance_and_regulatory_intelligence_details (ethereum_dependency);
create index if not exists idx_compliance_primary_function
  on public.compliance_and_regulatory_intelligence_details (primary_compliance_function);
create index if not exists idx_compliance_travel_rule_support
  on public.compliance_and_regulatory_intelligence_details (travel_rule_support);
create index if not exists idx_compliance_real_time_vs_historical
  on public.compliance_and_regulatory_intelligence_details (real_time_vs_historical);
create index if not exists idx_compliance_institutional_regulator_adoption
  on public.compliance_and_regulatory_intelligence_details (institutional_regulator_adoption);
create index if not exists idx_compliance_explainability
  on public.compliance_and_regulatory_intelligence_details (explainability);
create index if not exists idx_compliance_entity_archetype
  on public.compliance_and_regulatory_intelligence_details (entity_archetype);

alter table public.compliance_and_regulatory_intelligence_details enable row level security;
drop policy if exists "compliance_and_regulatory_intelligence_details_public_read"
  on public.compliance_and_regulatory_intelligence_details;
create policy "compliance_and_regulatory_intelligence_details_public_read"
  on public.compliance_and_regulatory_intelligence_details for select using (true);

drop trigger if exists trg_compliance_and_regulatory_intelligence_details_updated_at
  on public.compliance_and_regulatory_intelligence_details;
create trigger trg_compliance_and_regulatory_intelligence_details_updated_at
  before update on public.compliance_and_regulatory_intelligence_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- View.
-- ---------------------------------------------------------------------------

drop view if exists public.compliance_and_regulatory_intelligence_full_view;

create view public.compliance_and_regulatory_intelligence_full_view
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
    d.primary_compliance_function                                     as primary_compliance_function,
    d.secondary_compliance_functions                                  as secondary_compliance_functions,
    d.supported_compliance_domains                                    as supported_compliance_domains,
    d.target_users                                                    as target_users,
    d.ethereum_dependency                                             as ethereum_dependency,
    d.ethereum_data_coverage                                          as ethereum_data_coverage,
    d.real_time_vs_historical                                         as real_time_vs_historical,
    d.cross_chain_coverage                                            as cross_chain_coverage,
    d.address_attribution_methodology                                 as address_attribution_methodology,
    d.risk_scoring_model                                              as risk_scoring_model,
    d.explainability                                                  as explainability,
    d.sanctions_watchlist_integration                                 as sanctions_watchlist_integration,
    d.travel_rule_support                                             as travel_rule_support,
    d.case_management_investigations                                  as case_management_investigations,
    d.reporting_audit_outputs                                         as reporting_audit_outputs,
    d.access_controls_permissions                                     as access_controls_permissions,
    d.institutional_regulator_adoption                                as institutional_regulator_adoption,
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
  left join public.organizations o                                      on o.slug = p.maintaining_organization
  left join public.compliance_and_regulatory_intelligence_details d     on d.project_id = p.id
  left join public.sectors s_meta                                       on s_meta.slug = p.sector_slug
  left join public.subsectors sub_meta                                  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'compliance-and-regulatory-intelligence';

comment on view public.compliance_and_regulatory_intelligence_full_view is
  'Read-time projection for Sector 7 / Compliance & Regulatory Intelligence.';

-- ---------------------------------------------------------------------------
-- Subsector specific_field_schema.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/compliance-and-regulatory-intelligence.json",
  "title": "Compliance & Regulatory Intelligence — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_archetype":                  { "title": "Entity archetype", "type": "string" },
    "primary_compliance_function":       { "title": "Primary compliance function", "type": "string" },
    "secondary_compliance_functions":    { "title": "Secondary compliance functions", "type": "array", "items": { "type": "string" } },
    "supported_compliance_domains":      { "title": "Supported compliance domains", "type": "array", "items": { "type": "string" } },
    "target_users":                      { "title": "Target users", "type": "array", "items": { "type": "string" } },
    "ethereum_dependency":               { "title": "Ethereum dependency", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "ethereum_data_coverage":            { "title": "Ethereum data coverage", "type": "string" },
    "real_time_vs_historical":           { "title": "Real-time vs historical", "type": "string" },
    "cross_chain_coverage":              { "title": "Cross-chain coverage (Ethereum-relative)", "type": "string" },
    "address_attribution_methodology":   { "title": "Address attribution methodology", "type": "string" },
    "risk_scoring_model":                { "title": "Risk scoring model", "type": "string" },
    "explainability":                    { "title": "Explainability", "type": "string", "enum": ["High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "sanctions_watchlist_integration":   { "title": "Sanctions & watchlist integration", "type": "string" },
    "travel_rule_support":               { "title": "Travel rule support", "type": "string" },
    "case_management_investigations":    { "title": "Case management & investigations", "type": "string" },
    "reporting_audit_outputs":           { "title": "Reporting & audit outputs", "type": "string" },
    "access_controls_permissions":       { "title": "Access controls & permissions", "type": "string" },
    "institutional_regulator_adoption":  { "title": "Institutional / regulator adoption", "type": "string" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'compliance-and-regulatory-intelligence';
