-- Market Map — Sector 7 / Institutional Custody & Security sidecar.
--
-- NOTE: This subsector uses 'Primary Archetype' (NOT 'Entity Archetype') in
-- the source tab. The sidecar column is named primary_archetype. The importer
-- also copies the same value into projects.entity_archetype so the universal
-- facet keeps working uniformly across all 5 Sector-7 subsectors. See ISS-S7-003.
--
-- NOTE: This subsector tab has NO 'Year Launched' column and NO 'One-Line
-- Description' column. Importer leaves year_launched_int NULL and falls back
-- to Reason for Inclusion when populating projects.tagline / one_line_description.
--
-- View registered in SUBSECTOR_VIEW_REGISTRY in the same PR.

create table if not exists public.institutional_custody_and_security_details (
  project_id                            uuid primary key
    references public.projects(id) on delete cascade,

  -- Primary Archetype (sheet column name; ISS-S7-003).
  primary_archetype                     text,

  custody_model                         text,
  key_management_architecture           text,
  ethereum_asset_coverage               text,
  transaction_signing_model             text,
  key_recovery_loss_mitigation          text,
  approval_workflows                    text,
  policy_engine_capabilities            text,
  emergency_controls                    text,
  insurance_coverage                    text,
  regulatory_licensing_trust_status     text,

  ethereum_dependency                   text,
  ethereum_role                         text,
  l1_l2_support                         text,
  smart_contract_interaction_support    text,
  mev_gas_policy_controls               text,
  api_automation                        text,
  compliance_tool_integrations          text,
  institutional_adoption                text,

  data_quality_flags                    text[] not null default '{}',
  data_refreshed_at                     timestamptz,
  data_confidence                       text default 'estimate',

  created_at                            timestamptz not null default now(),
  updated_at                            timestamptz not null default now()
);

comment on table public.institutional_custody_and_security_details is
  '1:1 sidecar for Sector 7 / Institutional Custody & Security. NOTE: this tab '
  'uses primary_archetype (not entity_archetype). Source tab column is '
  '"Primary Archetype". See ISS-S7-003. The importer copies the same value '
  'into projects.entity_archetype so the universal facet keeps working.';

create index if not exists idx_custody_custody_model
  on public.institutional_custody_and_security_details (custody_model);
create index if not exists idx_custody_ethereum_dependency
  on public.institutional_custody_and_security_details (ethereum_dependency);
create index if not exists idx_custody_institutional_adoption
  on public.institutional_custody_and_security_details (institutional_adoption);
create index if not exists idx_custody_regulatory_licensing_trust_status
  on public.institutional_custody_and_security_details (regulatory_licensing_trust_status);
create index if not exists idx_custody_insurance_coverage
  on public.institutional_custody_and_security_details (insurance_coverage);
create index if not exists idx_custody_key_management_architecture
  on public.institutional_custody_and_security_details (key_management_architecture);
create index if not exists idx_custody_primary_archetype
  on public.institutional_custody_and_security_details (primary_archetype);

alter table public.institutional_custody_and_security_details enable row level security;
drop policy if exists "institutional_custody_and_security_details_public_read"
  on public.institutional_custody_and_security_details;
create policy "institutional_custody_and_security_details_public_read"
  on public.institutional_custody_and_security_details for select using (true);

drop trigger if exists trg_institutional_custody_and_security_details_updated_at
  on public.institutional_custody_and_security_details;
create trigger trg_institutional_custody_and_security_details_updated_at
  before update on public.institutional_custody_and_security_details
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- View.
-- ---------------------------------------------------------------------------

drop view if exists public.institutional_custody_and_security_full_view;

create view public.institutional_custody_and_security_full_view
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

    d.primary_archetype                                               as primary_archetype,
    d.custody_model                                                   as custody_model,
    d.key_management_architecture                                     as key_management_architecture,
    d.ethereum_asset_coverage                                         as ethereum_asset_coverage,
    d.transaction_signing_model                                       as transaction_signing_model,
    d.key_recovery_loss_mitigation                                    as key_recovery_loss_mitigation,
    d.approval_workflows                                              as approval_workflows,
    d.policy_engine_capabilities                                      as policy_engine_capabilities,
    d.emergency_controls                                              as emergency_controls,
    d.insurance_coverage                                              as insurance_coverage,
    d.regulatory_licensing_trust_status                               as regulatory_licensing_trust_status,
    d.ethereum_dependency                                             as ethereum_dependency,
    d.ethereum_role                                                   as ethereum_role,
    d.l1_l2_support                                                   as l1_l2_support,
    d.smart_contract_interaction_support                              as smart_contract_interaction_support,
    d.mev_gas_policy_controls                                         as mev_gas_policy_controls,
    d.api_automation                                                  as api_automation,
    d.compliance_tool_integrations                                    as compliance_tool_integrations,
    d.institutional_adoption                                          as institutional_adoption,
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
  left join public.organizations o                                        on o.slug = p.maintaining_organization
  left join public.institutional_custody_and_security_details d           on d.project_id = p.id
  left join public.sectors s_meta                                          on s_meta.slug = p.sector_slug
  left join public.subsectors sub_meta                                     on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'institutional-custody-and-security';

comment on view public.institutional_custody_and_security_full_view is
  'Read-time projection for Sector 7 / Institutional Custody & Security. '
  'Uses primary_archetype (per ISS-S7-003).';

-- ---------------------------------------------------------------------------
-- Subsector specific_field_schema.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/institutional-custody-and-security.json",
  "title": "Institutional Custody & Security — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "primary_archetype":                  { "title": "Primary archetype", "type": "string", "description": "Source column 'Primary Archetype' (not 'Entity Archetype'). ISS-S7-003." },
    "custody_model":                      { "title": "Custody model", "type": "string" },
    "key_management_architecture":        { "title": "Key management architecture", "type": "string" },
    "ethereum_asset_coverage":            { "title": "Ethereum asset coverage", "type": "string" },
    "transaction_signing_model":          { "title": "Transaction signing model", "type": "string" },
    "key_recovery_loss_mitigation":       { "title": "Key recovery & loss mitigation", "type": "string" },
    "approval_workflows":                 { "title": "Approval workflows", "type": "string" },
    "policy_engine_capabilities":         { "title": "Policy engine capabilities", "type": "string" },
    "emergency_controls":                 { "title": "Emergency controls", "type": "string" },
    "insurance_coverage":                 { "title": "Insurance coverage", "type": "string" },
    "regulatory_licensing_trust_status":  { "title": "Regulatory licensing / trust status", "type": "string" },
    "ethereum_dependency":                { "title": "Ethereum dependency", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] },
    "ethereum_role":                      { "title": "Ethereum role", "type": "string" },
    "l1_l2_support":                      { "title": "L1 / L2 support", "type": "string" },
    "smart_contract_interaction_support": { "title": "Smart contract interaction support", "type": "string" },
    "mev_gas_policy_controls":            { "title": "MEV / gas policy controls", "type": "string" },
    "api_automation":                     { "title": "API & automation", "type": "string" },
    "compliance_tool_integrations":       { "title": "Compliance tool integrations", "type": "string" },
    "institutional_adoption":             { "title": "Institutional adoption", "type": "string", "enum": ["Very High", "High", "Medium-High", "Medium", "Low-Medium", "Low"] }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'institutional-custody-and-security';
