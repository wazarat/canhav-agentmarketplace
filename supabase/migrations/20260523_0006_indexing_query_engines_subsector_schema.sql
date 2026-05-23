-- Market Map — Sector 5 / Indexing & Query Engines sidecar + entity_product_scope m2m.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.indexer_datasets (
  project_id                       uuid primary key
    references public.projects(id) on delete cascade,

  indexer_type                     text,
    -- block-explorer-decoded | subgraph-network | hosted-data-api
    -- streaming-pipeline | decoded-warehouse | self-hosted-framework
  primary_data_coverage            text,
  primary_users                    text,
  execution_coupling               text,
  indexing_model                   text,
  query_interface                  text,
  real_time_support                text,
  reorg_handling_strategy          text,
  data_freshness_guarantees        text,
  historical_depth                 text,
  backfill_capability              text,
  failure_modes                    text,
  pricing_model                    text,
  cost_sensitivity_at_scale        text,
  rate_limits_quotas               text,
  typical_protocol_dependencies    text,
  centralization_risk_note         text,
  known_incidents_or_gaps          text,

  -- Snapshots.
  active_subgraphs_snapshot        integer,
  active_subgraphs_as_of_date      date,
  chains_indexed_snapshot          integer,
  chains_indexed_as_of_date        date,

  description                      text,
  reason_for_inclusion             text,
  practitioner_note                text,
  practitioner_validation_check    text,
  replaceability_score             text,
  indexing_dependency_criticality  text,
  operational_complexity           text,

  data_quality_flags               text[] not null default '{}',
  data_refreshed_at                timestamptz,
  data_confidence                  text default 'estimate',

  constraint indexer_datasets_subgraphs_date_check
    check (active_subgraphs_snapshot is null or active_subgraphs_as_of_date is not null),
  constraint indexer_datasets_chains_date_check
    check (chains_indexed_snapshot is null or chains_indexed_as_of_date is not null),

  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now()
);

comment on table public.indexer_datasets is
  '1:1 sidecar for Sector 5 / Indexing & Query Engines.';

create index if not exists idx_indexer_datasets_indexer_type
  on public.indexer_datasets (indexer_type);
create index if not exists idx_indexer_datasets_pricing_model
  on public.indexer_datasets (pricing_model);
create index if not exists idx_indexer_datasets_real_time_support
  on public.indexer_datasets (real_time_support);
create index if not exists idx_indexer_datasets_indexing_dependency_criticality
  on public.indexer_datasets (indexing_dependency_criticality);

alter table public.indexer_datasets enable row level security;
drop policy if exists "indexer_datasets_public_read" on public.indexer_datasets;
create policy "indexer_datasets_public_read"
  on public.indexer_datasets for select using (true);

drop trigger if exists trg_indexer_datasets_updated_at on public.indexer_datasets;
create trigger trg_indexer_datasets_updated_at
  before update on public.indexer_datasets
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. entity_product_scope — generic multi-product table.
--    Used by Alchemy/QuickNode/Moralis (RPC + Indexing), Dune/Flipside
--    (Indexing + Analytics), Etherscan/Blockscout (RPC + Indexing + Analytics).
-- ---------------------------------------------------------------------------

create table if not exists public.entity_product_scope (
  id                       uuid primary key default gen_random_uuid(),
  project_id               uuid not null
    references public.projects(id) on delete cascade,
  product_slug             text not null,
  product_name             text not null,
  subsector_slug           text
    references public.subsectors(slug),
  notes                    text,
  display_order            smallint not null default 0,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint entity_product_scope_project_product_unique
    unique (project_id, product_slug)
);

comment on table public.entity_product_scope is
  'Generic multi-product scope table. One project_id, many rows — each row '
  'captures one product line of a multi-product entity (e.g. Alchemy RPC '
  'vs Alchemy Subgraphs).';

create index if not exists idx_entity_product_scope_project_id
  on public.entity_product_scope (project_id);
create index if not exists idx_entity_product_scope_subsector_slug
  on public.entity_product_scope (subsector_slug);

alter table public.entity_product_scope enable row level security;
drop policy if exists "entity_product_scope_public_read" on public.entity_product_scope;
create policy "entity_product_scope_public_read"
  on public.entity_product_scope for select using (true);

drop trigger if exists trg_entity_product_scope_updated_at on public.entity_product_scope;
create trigger trg_entity_product_scope_updated_at
  before update on public.entity_product_scope
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3. *_full_view.
-- ---------------------------------------------------------------------------

drop view if exists public.indexer_datasets_full_view;

create view public.indexer_datasets_full_view
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

    a.indexer_type                                                    as indexer_type,
    a.primary_data_coverage                                           as primary_data_coverage,
    a.primary_users                                                   as primary_users,
    a.execution_coupling                                              as execution_coupling,
    a.indexing_model                                                  as indexing_model,
    a.query_interface                                                 as query_interface,
    a.real_time_support                                               as real_time_support,
    a.reorg_handling_strategy                                         as reorg_handling_strategy,
    a.data_freshness_guarantees                                       as data_freshness_guarantees,
    a.historical_depth                                                as historical_depth,
    a.backfill_capability                                             as backfill_capability,
    a.failure_modes                                                   as failure_modes,
    a.pricing_model                                                   as pricing_model,
    a.cost_sensitivity_at_scale                                       as cost_sensitivity_at_scale,
    a.rate_limits_quotas                                              as rate_limits_quotas,
    a.typical_protocol_dependencies                                   as typical_protocol_dependencies,
    a.centralization_risk_note                                        as centralization_risk_note,
    a.known_incidents_or_gaps                                         as known_incidents_or_gaps,
    a.active_subgraphs_snapshot                                       as active_subgraphs_snapshot,
    a.active_subgraphs_as_of_date                                     as active_subgraphs_as_of_date,
    a.chains_indexed_snapshot                                         as chains_indexed_snapshot,
    a.chains_indexed_as_of_date                                       as chains_indexed_as_of_date,
    a.reason_for_inclusion                                            as reason_for_inclusion,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.replaceability_score                                            as replaceability_score,
    a.indexing_dependency_criticality                                 as indexing_dependency_criticality,
    a.operational_complexity                                          as operational_complexity,
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
  left join public.indexer_datasets a   on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'indexing-query-engines';

comment on view public.indexer_datasets_full_view is
  'Read-time projection for Sector 5 / Indexing & Query Engines.';
