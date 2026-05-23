-- Market Map — Sector 5 / Analytics & Intelligence sidecar.

create table if not exists public.analytics_dashboards (
  project_id                       uuid primary key
    references public.projects(id) on delete cascade,

  analytics_type                   text,
    -- on-chain-research | quant-monitoring | risk-steward
    -- compliance-tracking | community-dashboards | macro-intelligence
  primary_audience                 text,
  primary_inputs                   text,
  core_models_used                 text,
  time_horizon                     text,
  explainability_level             text,
  data_freshness_dependence        text,
  assumption_sensitivity           text,
  known_biases_blind_spots         text,
  failure_modes                    text,
  pricing_model                    text,
  cost_sensitivity_at_scale        text,
  typical_decision_impact          text,
  narrative_influence_level        text,
  centralization_risk_note         text,

  -- Snapshots.
  customer_count_snapshot          integer,
  customer_count_as_of_date        date,
  annual_revenue_usd_snapshot      numeric,
  annual_revenue_usd_as_of_date    date,

  description                      text,
  reason_for_inclusion             text,
  practitioner_note                text,
  practitioner_validation_check    text,
  replaceability_score             text,
  decision_dependency_criticality  text,
  epistemic_risk_level             text,

  data_quality_flags               text[] not null default '{}',
  data_refreshed_at                timestamptz,
  data_confidence                  text default 'estimate',

  constraint analytics_dashboards_customer_count_date_check
    check (customer_count_snapshot is null or customer_count_as_of_date is not null),
  constraint analytics_dashboards_revenue_date_check
    check (annual_revenue_usd_snapshot is null or annual_revenue_usd_as_of_date is not null),

  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now()
);

comment on table public.analytics_dashboards is
  '1:1 sidecar for Sector 5 / Analytics & Intelligence.';

create index if not exists idx_analytics_dashboards_analytics_type
  on public.analytics_dashboards (analytics_type);
create index if not exists idx_analytics_dashboards_primary_audience
  on public.analytics_dashboards (primary_audience);
create index if not exists idx_analytics_dashboards_pricing_model
  on public.analytics_dashboards (pricing_model);
create index if not exists idx_analytics_dashboards_decision_dependency_criticality
  on public.analytics_dashboards (decision_dependency_criticality);

alter table public.analytics_dashboards enable row level security;
drop policy if exists "analytics_dashboards_public_read" on public.analytics_dashboards;
create policy "analytics_dashboards_public_read"
  on public.analytics_dashboards for select using (true);

drop trigger if exists trg_analytics_dashboards_updated_at on public.analytics_dashboards;
create trigger trg_analytics_dashboards_updated_at
  before update on public.analytics_dashboards
  for each row execute procedure public.touch_updated_at();

drop view if exists public.analytics_dashboards_full_view;

create view public.analytics_dashboards_full_view
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

    a.analytics_type                                                  as analytics_type,
    a.primary_audience                                                as primary_audience,
    a.primary_inputs                                                  as primary_inputs,
    a.core_models_used                                                as core_models_used,
    a.time_horizon                                                    as time_horizon,
    a.explainability_level                                            as explainability_level,
    a.data_freshness_dependence                                       as data_freshness_dependence,
    a.assumption_sensitivity                                          as assumption_sensitivity,
    a.known_biases_blind_spots                                        as known_biases_blind_spots,
    a.failure_modes                                                   as failure_modes,
    a.pricing_model                                                   as pricing_model,
    a.cost_sensitivity_at_scale                                       as cost_sensitivity_at_scale,
    a.typical_decision_impact                                         as typical_decision_impact,
    a.narrative_influence_level                                       as narrative_influence_level,
    a.centralization_risk_note                                        as centralization_risk_note,
    a.customer_count_snapshot                                         as customer_count_snapshot,
    a.customer_count_as_of_date                                       as customer_count_as_of_date,
    a.annual_revenue_usd_snapshot                                     as annual_revenue_usd_snapshot,
    a.annual_revenue_usd_as_of_date                                   as annual_revenue_usd_as_of_date,
    a.reason_for_inclusion                                            as reason_for_inclusion,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.replaceability_score                                            as replaceability_score,
    a.decision_dependency_criticality                                 as decision_dependency_criticality,
    a.epistemic_risk_level                                            as epistemic_risk_level,
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
  left join public.analytics_dashboards a   on a.project_id = p.id
  left join public.sectors s_meta           on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta      on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'analytics-intelligence';

comment on view public.analytics_dashboards_full_view is
  'Read-time projection for Sector 5 / Analytics & Intelligence.';
