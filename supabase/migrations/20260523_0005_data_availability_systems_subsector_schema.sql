-- Market Map — Sector 5 / Data Availability Systems sidecar.

create table if not exists public.da_commitments (
  project_id                       uuid primary key
    references public.projects(id) on delete cascade,

  da_type                          text,
    -- monolithic-l1 | da-layer-blob | da-committee | data-availability-sampling
    -- restaked-da | validium-committee
  primary_da_consumer              text,
  execution_coupling               text,
  data_publication_method          text,
  availability_guarantee_model     text,
  verification_mechanism           text,
  who_can_withhold_data            text,
  who_detects_withholding          text,
  primary_failure_mode             text,
  time_to_detect_failure           text,
  recovery_path                    text,
  impact_of_da_failure             text,
  cost_model                       text,
  cost_vs_ethereum_da              text,
  scaling_characteristics          text,
  typical_protocol_dependencies    text,
  centralization_risk_note         text,
  known_incidents_or_risks         text,

  -- Snapshots.
  throughput_bytes_per_sec_snapshot   bigint,
  throughput_bytes_per_sec_as_of_date date,
  active_consumers_snapshot           integer,
  active_consumers_as_of_date         date,

  description                      text,
  reason_for_inclusion             text,
  practitioner_note                text,
  practitioner_validation_check    text,
  replaceability_score             text,
  da_dependency_criticality        text,
  long_term_viability_risk         text,

  data_quality_flags               text[] not null default '{}',
  data_refreshed_at                timestamptz,
  data_confidence                  text default 'estimate',

  constraint da_commitments_throughput_date_check
    check (throughput_bytes_per_sec_snapshot is null or throughput_bytes_per_sec_as_of_date is not null),
  constraint da_commitments_consumers_date_check
    check (active_consumers_snapshot is null or active_consumers_as_of_date is not null),

  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now()
);

comment on table public.da_commitments is
  '1:1 sidecar for Sector 5 / Data Availability Systems.';

create index if not exists idx_da_commitments_da_type
  on public.da_commitments (da_type);
create index if not exists idx_da_commitments_execution_coupling
  on public.da_commitments (execution_coupling);
create index if not exists idx_da_commitments_da_dependency_criticality
  on public.da_commitments (da_dependency_criticality);
create index if not exists idx_da_commitments_throughput
  on public.da_commitments (throughput_bytes_per_sec_snapshot);

alter table public.da_commitments enable row level security;
drop policy if exists "da_commitments_public_read" on public.da_commitments;
create policy "da_commitments_public_read"
  on public.da_commitments for select using (true);

drop trigger if exists trg_da_commitments_updated_at on public.da_commitments;
create trigger trg_da_commitments_updated_at
  before update on public.da_commitments
  for each row execute procedure public.touch_updated_at();

drop view if exists public.da_commitments_full_view;

create view public.da_commitments_full_view
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

    p.data_infra_archetype                                            as data_infra_archetype,
    p.trust_model                                                     as trust_model,
    p.centralization_risk_score                                       as centralization_risk_score,
    p.centralization_risk_evidence_quality                            as centralization_risk_evidence_quality,

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

    a.da_type                                                         as da_type,
    a.primary_da_consumer                                             as primary_da_consumer,
    a.execution_coupling                                              as execution_coupling,
    a.data_publication_method                                         as data_publication_method,
    a.availability_guarantee_model                                    as availability_guarantee_model,
    a.verification_mechanism                                          as verification_mechanism,
    a.who_can_withhold_data                                           as who_can_withhold_data,
    a.who_detects_withholding                                         as who_detects_withholding,
    a.primary_failure_mode                                            as primary_failure_mode,
    a.time_to_detect_failure                                          as time_to_detect_failure,
    a.recovery_path                                                   as recovery_path,
    a.impact_of_da_failure                                            as impact_of_da_failure,
    a.cost_model                                                      as cost_model,
    a.cost_vs_ethereum_da                                             as cost_vs_ethereum_da,
    a.scaling_characteristics                                         as scaling_characteristics,
    a.typical_protocol_dependencies                                   as typical_protocol_dependencies,
    a.centralization_risk_note                                        as centralization_risk_note,
    a.known_incidents_or_risks                                        as known_incidents_or_risks,
    a.throughput_bytes_per_sec_snapshot                               as throughput_bytes_per_sec_snapshot,
    a.throughput_bytes_per_sec_as_of_date                             as throughput_bytes_per_sec_as_of_date,
    a.active_consumers_snapshot                                       as active_consumers_snapshot,
    a.active_consumers_as_of_date                                     as active_consumers_as_of_date,
    a.reason_for_inclusion                                            as reason_for_inclusion,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.replaceability_score                                            as replaceability_score,
    a.da_dependency_criticality                                       as da_dependency_criticality,
    a.long_term_viability_risk                                        as long_term_viability_risk,
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
  left join public.da_commitments a     on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'data-availability-systems';

comment on view public.da_commitments_full_view is
  'Read-time projection for Sector 5 / Data Availability Systems.';
