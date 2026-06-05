-- Market Map — Sector 7 / Enterprise Blockchain Adoption sidecar.
--
-- 1:1 sidecar table; dual-write pattern identical to the DAO Governance sidecar.
-- View registered in SUBSECTOR_VIEW_REGISTRY in the same PR.

create table if not exists public.enterprise_blockchain_adoption_details (
  project_id                          uuid primary key
    references public.projects(id) on delete cascade,

  entity_archetype                    text,

  primary_enterprise_function         text,
  secondary_functions                 text[] not null default '{}',
  enterprise_use_case_category        text[] not null default '{}',
  target_customer                     text,
  deployment_model                    text,

  ethereum_dependency                 text,
  ethereum_role                       text,
  supported_ethereum_environments     text[] not null default '{}',
  cross_chain_interop                 text,

  integration_systems_compatibility   text,
  identity_permissioning              text,
  privacy_confidentiality_model       text,
  compliance_enablement               text,
  governance_change_mgmt              text,
  security_key_mgmt_model             text,
  audit_status                        text,

  enterprise_clients_examples         text[] not null default '{}',
  production_readiness                text,
  vendor_lock_in_risk                 text,

  data_quality_flags                  text[] not null default '{}',
  data_refreshed_at                   timestamptz,
  data_confidence                     text default 'estimate',

  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

comment on table public.enterprise_blockchain_adoption_details is
  '1:1 sidecar for Sector 7 / Enterprise Blockchain Adoption. Typed cols filterable; '
  'long-form fields dual-written into projects.subsector_attributes.';

create index if not exists idx_ent_bc_target_customer
  on public.enterprise_blockchain_adoption_details (target_customer);
create index if not exists idx_ent_bc_deployment_model
  on public.enterprise_blockchain_adoption_details (deployment_model);
create index if not exists idx_ent_bc_ethereum_dependency
  on public.enterprise_blockchain_adoption_details (ethereum_dependency);
create index if not exists idx_ent_bc_production_readiness
  on public.enterprise_blockchain_adoption_details (production_readiness);
create index if not exists idx_ent_bc_vendor_lock_in_risk
  on public.enterprise_blockchain_adoption_details (vendor_lock_in_risk);
create index if not exists idx_ent_bc_audit_status
  on public.enterprise_blockchain_adoption_details (audit_status);
create index if not exists idx_ent_bc_entity_archetype
  on public.enterprise_blockchain_adoption_details (entity_archetype);

alter table public.enterprise_blockchain_adoption_details enable row level security;
drop policy if exists "enterprise_blockchain_adoption_details_public_read"
  on public.enterprise_blockchain_adoption_details;
create policy "enterprise_blockchain_adoption_details_public_read"
  on public.enterprise_blockchain_adoption_details for select using (true);

drop trigger if exists trg_enterprise_blockchain_adoption_details_updated_at
  on public.enterprise_blockchain_adoption_details;
create trigger trg_enterprise_blockchain_adoption_details_updated_at
  before update on public.enterprise_blockchain_adoption_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- View.
-- ---------------------------------------------------------------------------

drop view if exists public.enterprise_blockchain_adoption_full_view;

create view public.enterprise_blockchain_adoption_full_view
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
    d.primary_enterprise_function                                     as primary_enterprise_function,
    d.secondary_functions                                             as secondary_functions,
    d.enterprise_use_case_category                                    as enterprise_use_case_category,
    d.target_customer                                                 as target_customer,
    d.deployment_model                                                as deployment_model,
    d.ethereum_dependency                                             as ethereum_dependency,
    d.ethereum_role                                                   as ethereum_role,
    d.supported_ethereum_environments                                 as supported_ethereum_environments,
    d.cross_chain_interop                                             as cross_chain_interop,
    d.integration_systems_compatibility                               as integration_systems_compatibility,
    d.identity_permissioning                                          as identity_permissioning,
    d.privacy_confidentiality_model                                   as privacy_confidentiality_model,
    d.compliance_enablement                                           as compliance_enablement,
    d.governance_change_mgmt                                          as governance_change_mgmt,
    d.security_key_mgmt_model                                         as security_key_mgmt_model,
    d.audit_status                                                    as audit_status,
    d.enterprise_clients_examples                                     as enterprise_clients_examples,
    d.production_readiness                                            as production_readiness,
    d.vendor_lock_in_risk                                             as vendor_lock_in_risk,
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
  left join public.organizations o                                on o.slug = p.maintaining_organization
  left join public.enterprise_blockchain_adoption_details d        on d.project_id = p.id
  left join public.sectors s_meta                                  on s_meta.slug = p.sector_slug
  left join public.subsectors sub_meta                             on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'enterprise-blockchain-adoption';

comment on view public.enterprise_blockchain_adoption_full_view is
  'Read-time projection for Sector 7 / Enterprise Blockchain Adoption.';

-- ---------------------------------------------------------------------------
-- Subsector specific_field_schema.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/enterprise-blockchain-adoption.json",
  "title": "Enterprise Blockchain Adoption — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_archetype":                  { "title": "Entity archetype", "type": "string" },
    "primary_enterprise_function":       { "title": "Primary enterprise function", "type": "string" },
    "secondary_functions":               { "title": "Secondary functions", "type": "array", "items": { "type": "string" } },
    "enterprise_use_case_category":      { "title": "Enterprise use case category", "type": "array", "items": { "type": "string" } },
    "target_customer":                   { "title": "Target customer", "type": "string", "enum": ["Enterprise", "Bank", "Gov", "Hybrid"] },
    "deployment_model":                  { "title": "Deployment model", "type": "string", "enum": ["SaaS", "Managed", "Self-Hosted", "Hybrid"] },
    "ethereum_dependency":               { "title": "Ethereum dependency", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "ethereum_role":                     { "title": "Ethereum role", "type": "string" },
    "supported_ethereum_environments":   { "title": "Supported Ethereum environments", "type": "array", "items": { "type": "string" } },
    "cross_chain_interop":               { "title": "Cross-chain / interop", "type": "string", "enum": ["Yes", "Limited", "No"] },
    "integration_systems_compatibility": { "title": "Integration & systems compatibility", "type": "string" },
    "identity_permissioning":            { "title": "Identity / permissioning", "type": "string" },
    "privacy_confidentiality_model":     { "title": "Privacy / confidentiality model", "type": "string" },
    "compliance_enablement":             { "title": "Compliance enablement", "type": "string" },
    "governance_change_mgmt":            { "title": "Governance & change mgmt", "type": "string" },
    "security_key_mgmt_model":           { "title": "Security / key mgmt model", "type": "string" },
    "audit_status":                      { "title": "Audit status", "type": "string" },
    "enterprise_clients_examples":       { "title": "Enterprise clients (examples)", "type": "array", "items": { "type": "string" } },
    "production_readiness":              { "title": "Production readiness", "type": "string", "enum": ["High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "vendor_lock_in_risk":               { "title": "Vendor lock-in risk", "type": "string", "enum": ["High", "Medium-High", "Medium", "Low-Medium", "Low"] }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'enterprise-blockchain-adoption';
