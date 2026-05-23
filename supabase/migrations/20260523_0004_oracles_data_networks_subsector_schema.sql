-- Market Map — Sector 5 / Oracles & Data Networks sidecar + oracle_products m2m.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.oracle_feeds (
  project_id                              uuid primary key
    references public.projects(id) on delete cascade,

  oracle_type                             text,
    -- push-aggregated | pull-on-demand | optimistic-with-dispute
    -- zk-attested | committee-attested | first-party
  primary_data_domain                     text,
  on_chain_footprint                      text,
  data_source_model                       text,
  verification_mechanism                  text,
  who_can_submit_data                     text,
  who_can_challenge_data                  text,
  freshness_guarantees                    text,
  correctness_guarantees                  text,
  availability_guarantees                 text,
  failure_handling_dispute_resolution     text,
  security_model                          text,
  cost_model                              text,
  value_at_risk_alignment                 text,
  typical_protocol_dependencies           text,
  downstream_economic_impact_if_incorrect text,
  centralization_risk_note                text,
  known_exploits_or_incidents             text,

  -- Snapshots (each pair: value + companion date).
  feed_count_snapshot                     integer,
  feed_count_as_of_date                   date,
  secured_tvs_usd_snapshot                numeric,
  secured_tvs_usd_as_of_date              date,
  freshness_seconds_snapshot              integer,
  freshness_seconds_as_of_date            date,
  signer_count_snapshot                   integer,
  signer_count_as_of_date                 date,

  description                             text,
  reason_for_inclusion                    text,
  practitioner_note                       text,
  practitioner_validation_check           text,
  typical_users                           text,
  replaceability_score                    text,
  oracle_dependency_criticality           text,

  data_quality_flags                      text[] not null default '{}',
  data_refreshed_at                       timestamptz,
  data_confidence                         text default 'estimate',

  constraint oracle_feeds_feed_count_date_check
    check (feed_count_snapshot is null or feed_count_as_of_date is not null),
  constraint oracle_feeds_secured_tvs_date_check
    check (secured_tvs_usd_snapshot is null or secured_tvs_usd_as_of_date is not null),
  constraint oracle_feeds_freshness_date_check
    check (freshness_seconds_snapshot is null or freshness_seconds_as_of_date is not null),
  constraint oracle_feeds_signer_count_date_check
    check (signer_count_snapshot is null or signer_count_as_of_date is not null),

  created_at                              timestamptz not null default now(),
  updated_at                              timestamptz not null default now()
);

comment on table public.oracle_feeds is
  '1:1 sidecar for Sector 5 / Oracles & Data Networks.';

create index if not exists idx_oracle_feeds_oracle_type
  on public.oracle_feeds (oracle_type);
create index if not exists idx_oracle_feeds_primary_data_domain
  on public.oracle_feeds (primary_data_domain);
create index if not exists idx_oracle_feeds_verification_mechanism
  on public.oracle_feeds (verification_mechanism);
create index if not exists idx_oracle_feeds_secured_tvs
  on public.oracle_feeds (secured_tvs_usd_snapshot);
create index if not exists idx_oracle_feeds_oracle_dependency_criticality
  on public.oracle_feeds (oracle_dependency_criticality);

alter table public.oracle_feeds enable row level security;
drop policy if exists "oracle_feeds_public_read" on public.oracle_feeds;
create policy "oracle_feeds_public_read"
  on public.oracle_feeds for select using (true);

drop trigger if exists trg_oracle_feeds_updated_at on public.oracle_feeds;
create trigger trg_oracle_feeds_updated_at
  before update on public.oracle_feeds
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. oracle_products m2m — for multi-product oracle entities (Chainlink x6).
-- ---------------------------------------------------------------------------

create table if not exists public.oracle_products (
  id                       uuid primary key default gen_random_uuid(),
  project_id               uuid not null
    references public.projects(id) on delete cascade,
  product_slug             text not null,
  product_name             text not null,
  oracle_type              text,
  primary_data_domain      text,
  verification_mechanism   text,
  product_url              text,
  notes                    text,
  display_order            smallint not null default 0,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  constraint oracle_products_project_product_unique
    unique (project_id, product_slug)
);

comment on table public.oracle_products is
  'Multi-product unification for oracle entities (Chainlink Price Feeds, CCIP, '
  'VRF, Functions, Data Streams, Proof of Reserve). One project_id, many rows.';

create index if not exists idx_oracle_products_project_id
  on public.oracle_products (project_id);
create index if not exists idx_oracle_products_oracle_type
  on public.oracle_products (oracle_type);

alter table public.oracle_products enable row level security;
drop policy if exists "oracle_products_public_read" on public.oracle_products;
create policy "oracle_products_public_read"
  on public.oracle_products for select using (true);

drop trigger if exists trg_oracle_products_updated_at on public.oracle_products;
create trigger trg_oracle_products_updated_at
  before update on public.oracle_products
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 3. *_full_view.
-- ---------------------------------------------------------------------------

drop view if exists public.oracle_feeds_full_view;

create view public.oracle_feeds_full_view
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

    a.oracle_type                                                     as oracle_type,
    a.primary_data_domain                                             as primary_data_domain,
    a.on_chain_footprint                                              as on_chain_footprint,
    a.data_source_model                                               as data_source_model,
    a.verification_mechanism                                          as verification_mechanism,
    a.who_can_submit_data                                             as who_can_submit_data,
    a.who_can_challenge_data                                          as who_can_challenge_data,
    a.freshness_guarantees                                            as freshness_guarantees,
    a.correctness_guarantees                                          as correctness_guarantees,
    a.availability_guarantees                                         as availability_guarantees,
    a.failure_handling_dispute_resolution                             as failure_handling_dispute_resolution,
    a.security_model                                                  as security_model,
    a.cost_model                                                      as cost_model,
    a.value_at_risk_alignment                                         as value_at_risk_alignment,
    a.typical_protocol_dependencies                                   as typical_protocol_dependencies,
    a.downstream_economic_impact_if_incorrect                         as downstream_economic_impact_if_incorrect,
    a.centralization_risk_note                                        as centralization_risk_note,
    a.known_exploits_or_incidents                                     as known_exploits_or_incidents,
    a.feed_count_snapshot                                             as feed_count_snapshot,
    a.feed_count_as_of_date                                           as feed_count_as_of_date,
    a.secured_tvs_usd_snapshot                                        as secured_tvs_usd_snapshot,
    a.secured_tvs_usd_as_of_date                                      as secured_tvs_usd_as_of_date,
    a.freshness_seconds_snapshot                                      as freshness_seconds_snapshot,
    a.freshness_seconds_as_of_date                                    as freshness_seconds_as_of_date,
    a.signer_count_snapshot                                           as signer_count_snapshot,
    a.signer_count_as_of_date                                         as signer_count_as_of_date,
    a.reason_for_inclusion                                            as reason_for_inclusion,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.typical_users                                                   as typical_users,
    a.replaceability_score                                            as replaceability_score,
    a.oracle_dependency_criticality                                   as oracle_dependency_criticality,
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
  left join public.oracle_feeds a       on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'oracles-data-networks';

comment on view public.oracle_feeds_full_view is
  'Read-time projection for Sector 5 / Oracles & Data Networks.';
