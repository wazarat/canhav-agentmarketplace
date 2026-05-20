-- M8.7 — Organizations table: one row per real-world company, FK from every subsector row.
--
-- WHY. The Market Map has a structural problem: the same company appears in many places.
-- Coinbase shows up in Validators (Validator Operations), and will later show up in
-- Custody, Exchanges, On/Off-Ramps, Wallets. Today each of those would be a duplicated
-- row with its own copy of hq_country, founded_year, total_funding, twitter_handle —
-- guaranteed to drift out of sync.
--
-- THE FIX. Every subsector row carries a maintaining_organization slug that FKs into a
-- single organizations table. That table holds the shared universal fields once.
-- Subsector rows hold only the attributes that are specific to what that org does
-- in that subsector.
--
-- The legacy `sector_attributes.maintaining_organization` text field is intentionally
-- LEFT IN PLACE on existing rows for now — the typed FK column is the new source of
-- truth, but cleaning up the JSONB key happens in a separate UI-cutover migration.
--
-- Aggregates (e.g. "Solo Validators") set is_aggregate=true and
-- maintaining_organization=null with not_applicable_reason='aggregate_category'.
-- DAOs (Lido DAO, Rocket Pool DAO, StakeWise DAO) get their own organizations rows
-- with entity_type='dao' so financial fields can be null without breaking validation.

-- ---------------------------------------------------------------------------
-- 1. organizations table
-- ---------------------------------------------------------------------------

create table if not exists public.organizations (
  slug                text primary key,
  display_name        text not null,
  legal_name          text,
  entity_type         text not null default 'company',
    -- one of: company | dao | foundation | aggregate | individual
  website_url         text,
  twitter_handle      text,
  logo_url            text,
  hq_country          text,
  founded_year        integer,
  team_size_range     text,
  total_funding_usd   bigint,
  last_funding_round  text,
  last_funding_date   date,
  stage               text,
  funding_model       text,
  status              text default 'active',
    -- one of: active | acquired | defunct | dormant
  acquired_by_slug    text references public.organizations(slug)
                      deferrable initially deferred,
  notes               text,
  attributes          jsonb default '{}'::jsonb,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

comment on table public.organizations is
  'Single source of truth for organization-level universal fields. One row per real-world '
  'company / DAO / foundation. Subsector rows reference this via projects.maintaining_organization. '
  'See docs/DECISIONS.md 2026-05-20 (organizations table introduction) for the rationale.';

create index if not exists organizations_entity_type_idx on public.organizations (entity_type);
create index if not exists organizations_acquired_by_slug_idx on public.organizations (acquired_by_slug);

alter table public.organizations enable row level security;

create policy "organizations are publicly readable"
  on public.organizations
  for select
  using (true);

-- Writes go through the service role (ingest scripts) only.

-- Trigger helper (idempotent; may already exist from prior migrations).
create or replace function public.tg__set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists organizations_set_updated_at on public.organizations;
create trigger organizations_set_updated_at
  before update on public.organizations
  for each row execute procedure public.tg__set_updated_at();

-- ---------------------------------------------------------------------------
-- 2. projects: new typed columns for FK + aggregate handling
-- ---------------------------------------------------------------------------

alter table public.projects
  add column if not exists maintaining_organization text
    references public.organizations(slug) deferrable initially deferred,
  add column if not exists is_aggregate boolean not null default false,
  add column if not exists not_applicable_reason text;
    -- one of: aggregate_category | dao_governed | protocol_specification | distributed_collective | null

comment on column public.projects.maintaining_organization is
  'FK to organizations.slug. Nullable when the row is an aggregate (is_aggregate=true) '
  'or when the entity is genuinely a distributed collective with no single legal owner. '
  'In both cases, set not_applicable_reason to explain why.';

comment on column public.projects.is_aggregate is
  'true when the row represents an aggregate category (e.g. Solo Validators) rather than '
  'a single entity. Aggregates are not enriched via per-entity APIs.';

comment on column public.projects.not_applicable_reason is
  'When maintaining_organization is null, this records WHY. Enum: aggregate_category | '
  'dao_governed | protocol_specification | distributed_collective.';

create index if not exists projects_maintaining_organization_idx
  on public.projects (maintaining_organization);

-- ---------------------------------------------------------------------------
-- 3. Backfill organizations from the 8 distinct maintaining_organization values
--    currently sitting in sector_attributes on consensus-layer + execution-layer rows.
--
--    Universal fields curated per the data-sources docs for each subsector and
--    cross-verified against LinkedIn / Crunchbase / org websites. These are
--    point-in-time estimates; the org row is the place to keep them fresh.
-- ---------------------------------------------------------------------------

insert into public.organizations (
  slug, display_name, legal_name, entity_type, website_url, twitter_handle,
  hq_country, founded_year, team_size_range, total_funding_usd, last_funding_round,
  last_funding_date, stage, funding_model, status, notes
) values
  ('ethereum-foundation', 'Ethereum Foundation', 'Ethereum Foundation',
   'foundation', 'https://ethereum.foundation/', 'ethereum',
   'Switzerland', 2014, '100+', null, null, null, 'n/a', 'foundation-internal',
   'active',
   'Swiss non-profit that anchors Ethereum protocol R&D. Owns the Yellow Paper, the consensus + execution specifications, and ships Geth via the go-ethereum team.'),
  ('sigma-prime', 'Sigma Prime', 'Sigma Prime Pty Ltd',
   'company', 'https://sigmaprime.io/', 'sigp_io',
   'Australia', 2016, '5-20', null, 'ecosystem-grant', null, 'n/a', 'grants-plus-services',
   'active',
   'Information security and blockchain engineering firm. Builds Lighthouse.'),
  ('chainsafe', 'ChainSafe', 'ChainSafe Systems Inc.',
   'company', 'https://chainsafe.io/', 'chainsafeth',
   'Canada', 2017, '50-100', null, 'ecosystem-grant', null, 'n/a', 'grants-plus-services',
   'active',
   'Toronto-based blockchain R&D firm. Builds Lodestar and ships infrastructure services.'),
  ('status', 'Status', 'Status Research & Development GmbH',
   'company', 'https://status.app/', 'ethstatus',
   'Switzerland', 2017, '50-100', null, 'token-launch', '2017-06-20', 'n/a', 'community',
   'active',
   'Status / IFT umbrella. Builds the Nimbus consensus client alongside the Status messenger.'),
  ('offchain-labs', 'Offchain Labs', 'Offchain Labs, Inc.',
   'company', 'https://offchainlabs.com/', 'OffchainLabs',
   'United States', 2018, '100+', 124000000, 'series-b', '2021-08-31', 'series-b', 'venture',
   'active',
   'Builds the Arbitrum rollup and (since the Jan 2022 acquisition of Prysmatic Labs) the Prysm consensus client.'),
  ('consensys', 'Consensys', 'Consensys Software Inc.',
   'company', 'https://consensys.io/', 'ConsenSys',
   'United States', 2014, '100+', 725000000, 'series-d', '2022-03-15', 'series-d', 'venture',
   'active',
   'Ethereum-focused product company. Builds Teku and Besu, plus MetaMask, Infura, and Linea.'),
  ('erigon', 'Erigon', 'Erigon Technologies AG',
   'company', 'https://erigon.tech/', 'ErigonEth',
   'Switzerland', 2020, '5-20', null, 'ecosystem-grant', null, 'n/a', 'grants-plus-services',
   'active',
   'Distributed contributor base; legal entity Erigon Technologies AG. Builds the Erigon execution client.'),
  ('nethermind', 'Nethermind', 'Demerzel Solutions Ltd.',
   'company', 'https://nethermind.io/', 'nethermindeth',
   'United Kingdom', 2017, '100+', 8000000, 'series-a', '2022-01-01', 'series-a', 'venture',
   'active',
   'London-based Ethereum infrastructure firm. Builds the Nethermind execution client plus validator and DeFi infra.')
on conflict (slug) do update set
  display_name = excluded.display_name,
  legal_name = excluded.legal_name,
  entity_type = excluded.entity_type,
  website_url = excluded.website_url,
  twitter_handle = excluded.twitter_handle,
  hq_country = excluded.hq_country,
  founded_year = excluded.founded_year,
  team_size_range = excluded.team_size_range,
  total_funding_usd = excluded.total_funding_usd,
  last_funding_round = excluded.last_funding_round,
  last_funding_date = excluded.last_funding_date,
  stage = excluded.stage,
  funding_model = excluded.funding_model,
  status = excluded.status,
  notes = excluded.notes,
  updated_at = now();

-- ---------------------------------------------------------------------------
-- 4. Backfill projects.maintaining_organization from the existing free-text
--    sector_attributes value. The mapping is hand-verified against the data above.
-- ---------------------------------------------------------------------------

update public.projects p
   set maintaining_organization = m.org_slug
  from (values
    ('ethereum-consensus-specifications', 'ethereum-foundation'),
    ('lighthouse', 'sigma-prime'),
    ('lodestar', 'chainsafe'),
    ('nimbus', 'status'),
    ('prysm', 'offchain-labs'),  -- Prysmatic Labs was acquired by Offchain Labs in Jan 2022
    ('teku', 'consensys'),
    ('besu', 'consensys'),
    ('erigon', 'erigon'),
    ('execution-eips-execution-layer-ethereum-improvement-proposals', 'ethereum-foundation'),
    ('geth-go-ethereum', 'ethereum-foundation'),
    ('nethermind', 'nethermind'),
    ('yellow-paper-ethereum-execution-specification', 'ethereum-foundation')
  ) as m(project_slug, org_slug)
 where p.slug = m.project_slug;
