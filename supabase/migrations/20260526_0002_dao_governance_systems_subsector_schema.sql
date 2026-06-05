-- Market Map — Sector 7 / DAO Governance Systems sidecar.
--
-- 1:1 sidecar table for the DAO Governance Systems subsector. Typed columns
-- are filterable and indexed; long-form prose (audit notes, known incidents)
-- is dual-written into projects.subsector_attributes by
-- enrich_governance_enterprise.py so existing prose rendering still works.
--
-- View dao_governance_systems_full_view registered in SUBSECTOR_VIEW_REGISTRY
-- in the same PR so the sidecar columns surface through the project_detail
-- endpoint.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.dao_governance_systems_details (
  project_id                       uuid primary key
    references public.projects(id) on delete cascade,

  -- Classification.
  entity_archetype                 text,

  -- Functional surface.
  primary_governance_function      text,
  secondary_governance_functions   text[] not null default '{}',
  governance_scope                 text,
  authority_origin                 text,
  decision_binding                 text,
  execution_mechanism              text,
  treasury_control                 text,
  permission_model                 text,

  -- Ethereum coupling.
  ethereum_dependency              text,
  cross_chain_support              text,

  -- Operational characteristics.
  governance_upgradeability        text,
  emergency_controls               text,
  governance_capture_risk          text,
  known_incidents                  text,
  audit_status                     text,

  -- Adoption.
  daos_using_system_examples       text[] not null default '{}',
  institutional_readiness          text,

  -- Provenance.
  data_quality_flags               text[] not null default '{}',
  data_refreshed_at                timestamptz,
  data_confidence                  text default 'estimate',

  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now()
);

comment on table public.dao_governance_systems_details is
  '1:1 sidecar for Sector 7 / DAO Governance Systems. Typed cols are '
  'filterable; long-form fields are dual-written into projects.subsector_attributes.';

-- Indexes (Invariant 6 — btree every filter/join column).
create index if not exists idx_dao_gov_entity_archetype
  on public.dao_governance_systems_details (entity_archetype);
create index if not exists idx_dao_gov_governance_scope
  on public.dao_governance_systems_details (governance_scope);
create index if not exists idx_dao_gov_ethereum_dependency
  on public.dao_governance_systems_details (ethereum_dependency);
create index if not exists idx_dao_gov_governance_capture_risk
  on public.dao_governance_systems_details (governance_capture_risk);
create index if not exists idx_dao_gov_institutional_readiness
  on public.dao_governance_systems_details (institutional_readiness);
create index if not exists idx_dao_gov_audit_status
  on public.dao_governance_systems_details (audit_status);

-- RLS.
alter table public.dao_governance_systems_details enable row level security;
drop policy if exists "dao_governance_systems_details_public_read"
  on public.dao_governance_systems_details;
create policy "dao_governance_systems_details_public_read"
  on public.dao_governance_systems_details for select using (true);

drop trigger if exists trg_dao_governance_systems_details_updated_at
  on public.dao_governance_systems_details;
create trigger trg_dao_governance_systems_details_updated_at
  before update on public.dao_governance_systems_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. dao_governance_systems_full_view — joins projects + organizations +
--    sidecar + sector/subsector schema metadata. Final 4 columns MUST be the
--    schema-passthrough block (Invariant 5).
-- ---------------------------------------------------------------------------

drop view if exists public.dao_governance_systems_full_view;

create view public.dao_governance_systems_full_view
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
    d.primary_governance_function                                     as primary_governance_function,
    d.secondary_governance_functions                                  as secondary_governance_functions,
    d.governance_scope                                                as governance_scope,
    d.authority_origin                                                as authority_origin,
    d.decision_binding                                                as decision_binding,
    d.execution_mechanism                                             as execution_mechanism,
    d.treasury_control                                                as treasury_control,
    d.permission_model                                                as permission_model,
    d.ethereum_dependency                                             as ethereum_dependency,
    d.cross_chain_support                                             as cross_chain_support,
    d.governance_upgradeability                                       as governance_upgradeability,
    d.emergency_controls                                              as emergency_controls,
    d.governance_capture_risk                                         as governance_capture_risk,
    d.known_incidents                                                 as known_incidents,
    d.audit_status                                                    as audit_status,
    d.daos_using_system_examples                                      as daos_using_system_examples,
    d.institutional_readiness                                         as institutional_readiness,
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
  left join public.organizations o                  on o.slug = p.maintaining_organization
  left join public.dao_governance_systems_details d on d.project_id = p.id
  left join public.sectors s_meta                   on s_meta.slug = p.sector_slug
  left join public.subsectors sub_meta              on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'dao-governance-systems';

comment on view public.dao_governance_systems_full_view is
  'Read-time projection for Sector 7 / DAO Governance Systems. Final 4 columns '
  'carry sector/subsector schema metadata per Invariant 5.';

-- ---------------------------------------------------------------------------
-- 3. Subsector specific_field_schema. Pins display labels and value enums so
--    the project page can humanise field keys without per-subsector logic.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/dao-governance-systems.json",
  "title": "DAO Governance Systems — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_archetype":                { "title": "Entity archetype", "type": "string" },
    "primary_governance_function":     { "title": "Primary governance function", "type": "string" },
    "secondary_governance_functions":  { "title": "Secondary governance functions", "type": "array", "items": { "type": "string" } },
    "governance_scope":                { "title": "Governance scope", "type": "string" },
    "authority_origin":                { "title": "Authority origin", "type": "string" },
    "decision_binding":                { "title": "Decision binding", "type": "string" },
    "execution_mechanism":             { "title": "Execution mechanism", "type": "string" },
    "treasury_control":                { "title": "Treasury control", "type": "string" },
    "permission_model":                { "title": "Permission model", "type": "string" },
    "ethereum_dependency":             { "title": "Ethereum dependency", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "cross_chain_support":             { "title": "Cross-chain support", "type": "string" },
    "governance_upgradeability":       { "title": "Governance upgradeability", "type": "string" },
    "emergency_controls":              { "title": "Emergency controls", "type": "string" },
    "governance_capture_risk":         { "title": "Governance capture risk", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "known_incidents":                 { "title": "Known incidents", "type": "string" },
    "audit_status":                    { "title": "Audit status", "type": "string" },
    "daos_using_system_examples":      { "title": "DAOs using system (examples)", "type": "array", "items": { "type": "string" } },
    "institutional_readiness":         { "title": "Institutional readiness", "type": "string", "enum": ["High", "Conditional", "Low-Conditional", "Low", "No"] }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'dao-governance-systems';
