-- Market Map — Sector 5 / RPC & Node Providers sidecar.
--
-- 1:1 sidecar table holding typed columns the project page wants indexed
-- (entity_type, decentralization_model, pricing_model, archive_node_support,
-- snapshot fields). The full text fields stay in subsector_attributes JSONB
-- because the importer dual-writes; the sidecar exists to be queryable.

-- ---------------------------------------------------------------------------
-- 1. Sidecar table.
-- ---------------------------------------------------------------------------

create table if not exists public.rpc_endpoints (
  project_id                       uuid primary key
    references public.projects(id) on delete cascade,

  -- Functional classification.
  entity_type                      text,
    -- centralized-saas | developer-platform-rpc-adjunct | permissionless-network
    -- validator-operator-with-rpc | block-explorer | self-hosted-framework
    -- hybrid-rpc | hyperscaler-cloud-rpc
  primary_role_in_stack            text,
  decentralization_model           text,
    -- centralized-saas | permissioned-network | permissionless-network
    -- multi-operator-coordinated | self-hosted-only

  -- Technical capabilities.
  rpc_interfaces_text              text,
  rpc_interfaces_enum              text[] not null default '{}',
    -- subset of: json-rpc, websocket, graphql, grpc, rest
  ethereum_clients_text            text,
  clients_supported_enum           text[] not null default '{}',
  execution_consensus_coverage     text,
  transaction_submission_supported text,
  archive_node_support             text,
  historical_depth                 text,

  -- Operational reliability snapshots (each pair: snapshot + companion date).
  uptime_sla_pct_snapshot          numeric(5,2),
  uptime_sla_pct_as_of_date        date,
  geographic_distribution          text,
  geographic_pop_count_snapshot    integer,
  geographic_pop_count_as_of_date  date,
  known_outages_or_incidents       text,
  censorship_resistance_text       text,
  client_diversity_risk            text,

  -- Economics.
  pricing_model                    text,
    -- free-tier | pay-per-call | subscription | usage-based
    -- enterprise-contract | staking-based | freemium
  cost_sensitivity_at_scale        text,
  rate_limits_throttling_model     text,
  rate_limit_rps_snapshot          integer,
  rate_limit_rps_as_of_date        date,

  -- Practitioner interpretation.
  description                      text,
  reason_for_inclusion             text,
  practitioner_note                text,
  practitioner_validation_check    text,
  typical_users                    text,
  downstream_dependency_risk       text,
  replaceability_score             text,

  -- Permissionless-network only.
  stake_token_symbol               text,

  -- Provenance.
  data_quality_flags               text[] not null default '{}',
  data_refreshed_at                timestamptz,
  data_confidence                  text default 'estimate',

  -- Snapshot/date companion enforcement: any snapshot column without its
  -- _as_of_date is rejected at insert/update time.
  constraint rpc_endpoints_uptime_snapshot_date_check
    check (uptime_sla_pct_snapshot is null or uptime_sla_pct_as_of_date is not null),
  constraint rpc_endpoints_geo_snapshot_date_check
    check (geographic_pop_count_snapshot is null or geographic_pop_count_as_of_date is not null),
  constraint rpc_endpoints_rate_limit_snapshot_date_check
    check (rate_limit_rps_snapshot is null or rate_limit_rps_as_of_date is not null),

  created_at                       timestamptz not null default now(),
  updated_at                       timestamptz not null default now()
);

comment on table public.rpc_endpoints is
  '1:1 sidecar for Sector 5 / RPC & Node Providers. Typed cols are filterable; '
  'long-form practitioner narrative is dual-written into projects.subsector_attributes.';

-- Indexes (Invariant 6 — btree every filter/join column).
create index if not exists idx_rpc_endpoints_entity_type
  on public.rpc_endpoints (entity_type);
create index if not exists idx_rpc_endpoints_decentralization_model
  on public.rpc_endpoints (decentralization_model);
create index if not exists idx_rpc_endpoints_pricing_model
  on public.rpc_endpoints (pricing_model);
create index if not exists idx_rpc_endpoints_client_diversity_risk
  on public.rpc_endpoints (client_diversity_risk);
create index if not exists idx_rpc_endpoints_uptime_snapshot
  on public.rpc_endpoints (uptime_sla_pct_snapshot);

-- RLS.
alter table public.rpc_endpoints enable row level security;
drop policy if exists "rpc_endpoints_public_read" on public.rpc_endpoints;
create policy "rpc_endpoints_public_read"
  on public.rpc_endpoints for select using (true);

drop trigger if exists trg_rpc_endpoints_updated_at on public.rpc_endpoints;
create trigger trg_rpc_endpoints_updated_at
  before update on public.rpc_endpoints
  for each row execute procedure public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- 2. *_full_view — joins projects + organizations + sidecar + sector/subsector
--    schema metadata. Final 4 cols MUST be the schema-passthrough block.
-- ---------------------------------------------------------------------------

drop view if exists public.rpc_endpoints_full_view;

create view public.rpc_endpoints_full_view
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

    a.entity_type                                                     as entity_type,
    a.primary_role_in_stack                                           as primary_role_in_stack,
    a.decentralization_model                                          as decentralization_model,
    a.rpc_interfaces_text                                             as rpc_interfaces_text,
    a.rpc_interfaces_enum                                             as rpc_interfaces_enum,
    a.ethereum_clients_text                                           as ethereum_clients_text,
    a.clients_supported_enum                                          as clients_supported_enum,
    a.execution_consensus_coverage                                    as execution_consensus_coverage,
    a.transaction_submission_supported                                as transaction_submission_supported,
    a.archive_node_support                                            as archive_node_support,
    a.historical_depth                                                as historical_depth,
    a.uptime_sla_pct_snapshot                                         as uptime_sla_pct_snapshot,
    a.uptime_sla_pct_as_of_date                                       as uptime_sla_pct_as_of_date,
    a.geographic_distribution                                         as geographic_distribution,
    a.geographic_pop_count_snapshot                                   as geographic_pop_count_snapshot,
    a.geographic_pop_count_as_of_date                                 as geographic_pop_count_as_of_date,
    a.known_outages_or_incidents                                      as known_outages_or_incidents,
    a.censorship_resistance_text                                      as censorship_resistance_text,
    a.client_diversity_risk                                           as client_diversity_risk,
    a.pricing_model                                                   as pricing_model,
    a.cost_sensitivity_at_scale                                       as cost_sensitivity_at_scale,
    a.rate_limits_throttling_model                                    as rate_limits_throttling_model,
    a.rate_limit_rps_snapshot                                         as rate_limit_rps_snapshot,
    a.rate_limit_rps_as_of_date                                       as rate_limit_rps_as_of_date,
    a.reason_for_inclusion                                            as reason_for_inclusion,
    a.practitioner_note                                               as practitioner_note,
    a.practitioner_validation_check                                   as practitioner_validation_check,
    a.typical_users                                                   as typical_users,
    a.downstream_dependency_risk                                      as downstream_dependency_risk,
    a.replaceability_score                                            as replaceability_score,
    a.stake_token_symbol                                              as stake_token_symbol,
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
  left join public.rpc_endpoints a      on a.project_id = p.id
  left join public.sectors s_meta       on s_meta.slug   = p.sector_slug
  left join public.subsectors sub_meta  on sub_meta.slug = p.subsector_slug
  where p.subsector_slug = 'rpc-node-providers';

comment on view public.rpc_endpoints_full_view is
  'Read-time projection for Sector 5 / RPC & Node Providers. Final 4 columns '
  'carry sector/subsector schema metadata per Invariant 5.';
