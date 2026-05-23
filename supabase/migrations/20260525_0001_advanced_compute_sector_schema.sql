-- Market Map — Sector 6 (Advanced Compute & Integration) sector-wide schema.
--
-- WHAT THIS LANDS.
--   1. Rewrites the 5 Sector 6 subsector rows so their slugs match the v12
--      canonical spelling (the original seed used short forms that don't match
--      the field-spec docs the next agent reads). No projects depend on these
--      slugs yet, so a DELETE+INSERT is safe.
--   2. Promotes 16 Sector-6 columns onto public.projects so the project page
--      can render them via the universal columns + the SUBSECTOR_VIEW_REGISTRY
--      merge. Sidecar tables for the per-subsector long tail are created in
--      the sibling 0002-0006 migrations.
--   3. Adds a snapshot-companion check constraint mirroring the Sector 5
--      pattern: mainnet_status without mainnet_status_as_of_date is rejected.
--   4. Creates the 8 shared m2m tables Sector 6 uses (project_chains is
--      reused across sectors; the others are new):
--        - project_chains
--        - project_composes_with
--        - project_aliases
--        - project_jurisdictions
--        - project_regulatory_frameworks
--        - project_token_standards
--        - project_custodians
--        - project_identifier_standards
--        - project_credential_standards
--   5. Seeds the 4 project_aliases entries documented in the v12 spec:
--      Polygon ID → privado-id, Fetch.ai → asi-alliance-fetch-ai, Autonolas
--      (canonical), OLAS → autonolas. parent_project_slug captures the
--      OLAS-as-economic-layer hierarchy.
--   6. Updates sectors.common_field_schema and each Sector 6 subsector's
--      specific_field_schema JSONB so humanLabel rendering on the project
--      page picks up the new keys without a frontend change.
--
-- WHY THIS PATTERN.
--   Sector 6 ships sidecars for every subsector (every one exceeds 10 typed
--   columns per Invariant 5), so it mirrors the Sector 5 layout but lifts
--   maintenance columns that recur across every Sector 6 subsector onto
--   public.projects to avoid duplication. The SUBSECTOR_VIEW_REGISTRY in
--   backend/app/routes/market_map.py is extended in the same PR — without
--   that wiring the project page would only render the universal columns
--   plus what the importer dual-writes into the JSONB blobs (the Sector 2
--   regression class documented in data_gaps.md ISS-S6-014).

-- ---------------------------------------------------------------------------
-- 1. Canonical subsector slugs.
-- ---------------------------------------------------------------------------

delete from public.subsectors
 where sector_slug = 'advanced-compute-integration'
   and slug in (
     'ai-agents-autonomous-systems',
     'real-world-assets',
     'identity-social-graphs',
     'depin',
     'cross-chain-compute'
   );

insert into public.subsectors
  (slug, sector_slug, name, description, display_order, source_sheet_id, source_sheet_gid)
values
  ('ai-agents-and-autonomous-systems', 'advanced-compute-integration',
   'AI Agents & Autonomous Systems',
   'Persistent, goal-driven agents using Ethereum as a coordination, settlement, and economic enforcement layer.',
   1, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1608239665'),
  ('real-world-assets-rwas', 'advanced-compute-integration',
   'Real-World Assets (RWAs)',
   'Off-chain legal, financial, or physical assets anchored to Ethereum-settled representations.',
   2, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1894391559'),
  ('identity-and-social-graphs', 'advanced-compute-integration',
   'Identity & Social Graphs',
   'Persistent, reusable identity, reputation, and relationship state consumable by smart contracts and agents.',
   3, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '341534256'),
  ('depin-physical-infrastructure', 'advanced-compute-integration',
   'DePIN (Physical Infrastructure)',
   'Real-world physical infrastructure coordinated by Ethereum-settled cryptoeconomic incentives. Source sheet tab is misspelled "Infrastruture"; canonical slug uses the corrected spelling.',
   4, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1254628628'),
  ('cross-chain-compute', 'advanced-compute-integration',
   'Cross-Chain Compute',
   'Execution, verification, or coordination across multiple chains/VMs with Ethereum as finality and dispute anchor.',
   5, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '403856203')
on conflict (slug) do update
  set sector_slug      = excluded.sector_slug,
      name             = excluded.name,
      description      = excluded.description,
      display_order    = excluded.display_order,
      source_sheet_id  = excluded.source_sheet_id,
      source_sheet_gid = excluded.source_sheet_gid,
      updated_at       = now();

-- ---------------------------------------------------------------------------
-- 2. Sector-6 promotions onto public.projects.
--    Every column is sector-scoped at the value level (only Sector 6 rows
--    populate them) but typed at the table level so the universal-column
--    read path picks them up automatically.
-- ---------------------------------------------------------------------------

alter table public.projects
  add column if not exists subsector_slug_secondary text
    references public.subsectors(slug) on delete set null,
  add column if not exists is_pattern boolean not null default false,
  add column if not exists entity_type text,
  add column if not exists entity_archetype text,
  add column if not exists maintaining_organization_raw text,
  add column if not exists year_launched_text text,
  add column if not exists year_launched_int integer,
  add column if not exists mainnet_status text,
  add column if not exists mainnet_status_as_of_date date,
  add column if not exists one_line_description text,
  add column if not exists practitioner_note text,
  add column if not exists practitioner_validation_check text,
  add column if not exists parent_project_slug text
    references public.projects(slug) on delete set null,
  add column if not exists scope_annotation text,
  add column if not exists description_long text,
  add column if not exists reason_for_inclusion text;

-- Snapshot+companion enforcement (mirrors the Sector 5 rpc_endpoints pattern).
alter table public.projects
  drop constraint if exists projects_mainnet_status_snapshot_date_check;
alter table public.projects
  add constraint projects_mainnet_status_snapshot_date_check
  check (
    mainnet_status is null
    or mainnet_status_as_of_date is not null
  );

create index if not exists idx_projects_subsector_slug_secondary
  on public.projects (subsector_slug_secondary)
  where subsector_slug_secondary is not null;
create index if not exists idx_projects_is_pattern
  on public.projects (is_pattern)
  where is_pattern;
create index if not exists idx_projects_entity_type
  on public.projects (entity_type);
create index if not exists idx_projects_entity_archetype
  on public.projects (entity_archetype);
create index if not exists idx_projects_year_launched_int
  on public.projects (year_launched_int)
  where year_launched_int is not null;
create index if not exists idx_projects_parent_project_slug
  on public.projects (parent_project_slug)
  where parent_project_slug is not null;
create index if not exists idx_projects_scope_annotation
  on public.projects (scope_annotation)
  where scope_annotation is not null;

-- ---------------------------------------------------------------------------
-- 3. Shared m2m tables. project_chains / project_composes_with / project_aliases
--    are guarded with IF NOT EXISTS so they remain idempotent if future
--    sectors land them first.
-- ---------------------------------------------------------------------------

create table if not exists public.project_chains (
  project_id   uuid not null references public.projects(id) on delete cascade,
  chain_slug   text not null,
  primary key (project_id, chain_slug)
);
create index if not exists idx_project_chains_chain
  on public.project_chains (chain_slug);

create table if not exists public.project_composes_with (
  project_id          uuid not null references public.projects(id) on delete cascade,
  composes_with_token text not null,
  primary key (project_id, composes_with_token)
);
create index if not exists idx_project_composes_with_token
  on public.project_composes_with (composes_with_token);

create table if not exists public.project_aliases (
  alias_name   text primary key,
  project_slug text not null references public.projects(slug) on delete cascade
);
create index if not exists idx_project_aliases_project_slug
  on public.project_aliases (project_slug);

create table if not exists public.project_jurisdictions (
  project_id         uuid not null references public.projects(id) on delete cascade,
  jurisdiction_code  text not null,
  primary key (project_id, jurisdiction_code)
);
create index if not exists idx_project_jurisdictions_code
  on public.project_jurisdictions (jurisdiction_code);

create table if not exists public.project_regulatory_frameworks (
  project_id     uuid not null references public.projects(id) on delete cascade,
  framework_code text not null,
  primary key (project_id, framework_code)
);
create index if not exists idx_project_regulatory_frameworks_code
  on public.project_regulatory_frameworks (framework_code);

create table if not exists public.project_token_standards (
  project_id     uuid not null references public.projects(id) on delete cascade,
  token_standard text not null,
  primary key (project_id, token_standard)
);
create index if not exists idx_project_token_standards_std
  on public.project_token_standards (token_standard);

create table if not exists public.project_custodians (
  project_id     uuid not null references public.projects(id) on delete cascade,
  custodian_name text not null,
  primary key (project_id, custodian_name)
);
create index if not exists idx_project_custodians_name
  on public.project_custodians (custodian_name);

create table if not exists public.project_identifier_standards (
  project_id          uuid not null references public.projects(id) on delete cascade,
  identifier_standard text not null,
  primary key (project_id, identifier_standard)
);
create index if not exists idx_project_identifier_standards_std
  on public.project_identifier_standards (identifier_standard);

create table if not exists public.project_credential_standards (
  project_id          uuid not null references public.projects(id) on delete cascade,
  credential_standard text not null,
  primary key (project_id, credential_standard)
);
create index if not exists idx_project_credential_standards_std
  on public.project_credential_standards (credential_standard);

-- RLS for every new shared table (public read; writes via service_role).
alter table public.project_chains              enable row level security;
alter table public.project_composes_with       enable row level security;
alter table public.project_aliases             enable row level security;
alter table public.project_jurisdictions       enable row level security;
alter table public.project_regulatory_frameworks enable row level security;
alter table public.project_token_standards     enable row level security;
alter table public.project_custodians          enable row level security;
alter table public.project_identifier_standards enable row level security;
alter table public.project_credential_standards enable row level security;

drop policy if exists "project_chains_public_read"               on public.project_chains;
drop policy if exists "project_composes_with_public_read"        on public.project_composes_with;
drop policy if exists "project_aliases_public_read"              on public.project_aliases;
drop policy if exists "project_jurisdictions_public_read"        on public.project_jurisdictions;
drop policy if exists "project_regulatory_frameworks_public_read" on public.project_regulatory_frameworks;
drop policy if exists "project_token_standards_public_read"      on public.project_token_standards;
drop policy if exists "project_custodians_public_read"           on public.project_custodians;
drop policy if exists "project_identifier_standards_public_read" on public.project_identifier_standards;
drop policy if exists "project_credential_standards_public_read" on public.project_credential_standards;

create policy "project_chains_public_read"               on public.project_chains               for select using (true);
create policy "project_composes_with_public_read"        on public.project_composes_with        for select using (true);
create policy "project_aliases_public_read"              on public.project_aliases              for select using (true);
create policy "project_jurisdictions_public_read"        on public.project_jurisdictions        for select using (true);
create policy "project_regulatory_frameworks_public_read" on public.project_regulatory_frameworks for select using (true);
create policy "project_token_standards_public_read"      on public.project_token_standards      for select using (true);
create policy "project_custodians_public_read"           on public.project_custodians           for select using (true);
create policy "project_identifier_standards_public_read" on public.project_identifier_standards for select using (true);
create policy "project_credential_standards_public_read" on public.project_credential_standards for select using (true);

-- ---------------------------------------------------------------------------
-- 4. Sector-common JSON Schema. Documents the 16 promoted columns plus the
--    Sector 6 cross-cutting decisions (smart-quote normalization,
--    dual-subsector splits, scope annotations, the 4 rename aliases).
-- ---------------------------------------------------------------------------

update public.sectors
   set common_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/sectors/advanced-compute-integration.json",
  "title": "Advanced Compute & Integration — sector_attributes",
  "description": "Fields shared by every subsector in Advanced Compute & Integration. Sidecar tables carry the per-subsector long tail; the columns documented here live on public.projects and are populated by enrich_advanced_compute.py.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_type":               { "title": "Entity type", "type": "string", "description": "Project / Protocol / Application / Pattern / Network / Standard." },
    "entity_archetype":          { "title": "Entity archetype", "type": "string", "description": "Fine-grained classification used as a UI facet (Aggregator, Subnet, Settlement layer, Tokenization platform, etc.)." },
    "maintaining_organization":  { "title": "Maintaining organization", "type": "string", "description": "Resolved org slug. Sheet's raw value is preserved in maintaining_organization_raw." },
    "maintaining_organization_raw": { "title": "Maintaining organization (raw)", "type": "string" },
    "year_launched_text":        { "title": "Year launched (source text)", "type": "string" },
    "year_launched_int":         { "title": "Year launched", "type": ["integer", "null"], "minimum": 2009, "maximum": 2100 },
    "mainnet_status":            { "title": "Mainnet status", "type": "string", "description": "Snapshot value; companion column mainnet_status_as_of_date is required when set." },
    "mainnet_status_as_of_date": { "title": "Mainnet status as-of date", "type": "string", "format": "date" },
    "one_line_description":      { "title": "One-line description", "type": "string" },
    "practitioner_note":         { "title": "Practitioner note", "type": "string", "description": "Source header has smart-quote U+2019, normalized to ASCII at ingest." },
    "practitioner_validation_check": { "title": "Practitioner validation check", "type": "string" },
    "scope_annotation":          { "title": "Scope annotation", "type": "string", "description": "Cross-Chain Compute scope hints preserved verbatim (e.g., 'execution-enabled usage only', 'verification & dispute contexts only')." },
    "description_long":          { "title": "Long-form description", "type": "string" },
    "reason_for_inclusion":      { "title": "Reason for inclusion", "type": "string" },
    "is_pattern":                { "title": "Is reference pattern", "type": "boolean", "description": "TRUE for AI Agents architectural pattern rows that are not ship-able entities." },
    "parent_project_slug":       { "title": "Parent project slug", "type": "string", "description": "Self-FK for Helium sub-networks → 'helium', OLAS → 'autonolas'." },
    "subsector_slug_secondary":  { "title": "Secondary subsector", "type": "string", "description": "For dual-subsector projects: Worldcoin, Bittensor, RISC Zero, Axiom." }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'advanced-compute-integration';

-- ---------------------------------------------------------------------------
-- 5. Subsector-specific JSON Schemas. Pin display labels and value enums so
--    the project page can humanise field keys without per-subsector logic.
--    Per-subsector sidecar tables (0002-0006 migrations) carry the typed
--    storage; this metadata pure JSONB-side aids rendering.
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/ai-agents-and-autonomous-systems.json",
  "title": "AI Agents & Autonomous Systems — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "primary_use_case":                  { "title": "Primary use case", "type": "string" },
    "target_users":                      { "title": "Target users", "type": "string" },
    "primary_agent_function":            { "title": "Primary agent function", "type": "string" },
    "ethereum_role_primary":             { "title": "Ethereum role (primary)", "type": "string" },
    "ethereum_role_secondary":           { "title": "Ethereum role (secondary)", "type": "string" },
    "chains_supported_raw":              { "title": "Chains supported (raw)", "type": "string" },
    "on_chain_execution_scope_primary":  { "title": "On-chain execution scope (primary)", "type": "string" },
    "on_chain_execution_scope_secondary":{ "title": "On-chain execution scope (secondary)", "type": "string" },
    "autonomous_on_chain_actions_bool":  { "title": "Autonomous on-chain actions", "type": ["boolean", "null"] },
    "autonomous_on_chain_actions_detail":{ "title": "Autonomous on-chain actions — detail", "type": "string" },
    "autonomy_level":                    { "title": "Autonomy level", "type": "string", "enum": ["Goal-Driven", "Reactive", "Supervised", "Limited"] },
    "off_chain_compute_location_primary":{ "title": "Off-chain compute location (primary)", "type": "string" },
    "off_chain_compute_location_secondary": { "title": "Off-chain compute location (secondary)", "type": "string" },
    "inference_planning_method":         { "title": "Inference / planning method", "type": "string" },
    "state_persistence_model_primary":   { "title": "State persistence model (primary)", "type": "string" },
    "state_persistence_model_secondary": { "title": "State persistence model (secondary)", "type": "string" },
    "human_override_capability":         { "title": "Human override capability", "type": "string" },
    "verification_model_primary":        { "title": "Verification model (primary)", "type": "string" },
    "verification_model_secondary":      { "title": "Verification model (secondary)", "type": "string" },
    "auditability":                      { "title": "Auditability", "type": "string", "enum": ["High", "Medium", "Low"] },
    "auditability_as_of_date":           { "title": "Auditability as-of date", "type": "string", "format": "date" },
    "replayability":                     { "title": "Replayability", "type": "string" },
    "failure_handling":                  { "title": "Failure handling", "type": "string" },
    "agent_identity_model":              { "title": "Agent identity model", "type": "string" },
    "permissioning_model":               { "title": "Permissioning model", "type": "string" },
    "role_based_controls_bool":          { "title": "Role-based controls", "type": ["boolean", "null"] },
    "sybil_resistance":                  { "title": "Sybil resistance", "type": "string" },
    "who_pays_primary":                  { "title": "Who pays (primary)", "type": "string" },
    "who_pays_secondary":                { "title": "Who pays (secondary)", "type": "string" },
    "fee_incentive_model":               { "title": "Fee / incentive model", "type": "string" },
    "slashing_bool":                     { "title": "Slashing / penalty mechanism", "type": ["boolean", "null"] },
    "slashing_detail":                   { "title": "Slashing / penalty — detail", "type": "string" },
    "value_accrual_primary":             { "title": "Value accrual (primary)", "type": "string" },
    "value_accrual_secondary":           { "title": "Value accrual (secondary)", "type": "string" },
    "external_dependencies_primary":     { "title": "Key external dependencies (primary)", "type": "string" },
    "external_dependencies_secondary":   { "title": "Key external dependencies (secondary)", "type": "string" },
    "primary_risk_factor_1":             { "title": "Primary risk factor 1", "type": "string" },
    "primary_risk_factor_2":             { "title": "Primary risk factor 2", "type": "string" },
    "censorship_resistance":             { "title": "Censorship resistance", "type": "string", "enum": ["High", "Medium", "Low"] },
    "censorship_resistance_as_of_date":  { "title": "Censorship resistance as-of date", "type": "string", "format": "date" },
    "upgrade_governance_control":        { "title": "Upgrade / governance control", "type": "string" },
    "composable_with_raw":               { "title": "Composable with (raw)", "type": "string" },
    "defensibility_source":              { "title": "Defensibility source", "type": "string" },
    "sector_adjacency_risk":             { "title": "Sector adjacency risk", "type": "string" },
    "sector_adjacency_risk_as_of_date":  { "title": "Sector adjacency risk as-of date", "type": "string", "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'ai-agents-and-autonomous-systems';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/real-world-assets-rwas.json",
  "title": "Real-World Assets (RWAs) — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "jurisdictions_raw":              { "title": "Jurisdictions (raw)", "type": "string" },
    "asset_class_primary":            { "title": "Asset class (primary)", "type": "string" },
    "asset_class_secondary":          { "title": "Asset class (secondary)", "type": "string" },
    "asset_issuer":                   { "title": "Asset issuer", "type": "string" },
    "asset_issuer_as_of_date":        { "title": "Asset issuer as-of date", "type": "string", "format": "date" },
    "is_dao_issuer":                  { "title": "DAO is issuer", "type": "boolean" },
    "legal_structure":                { "title": "Legal structure", "type": "string" },
    "jurisdiction_legal_enforceability": { "title": "Jurisdiction legal enforceability", "type": "string" },
    "redemption_rights":              { "title": "Redemption rights", "type": "string" },
    "investor_rights":                { "title": "Investor rights", "type": "string" },
    "ethereum_role_primary":          { "title": "Ethereum role (primary)", "type": "string" },
    "ethereum_role_secondary":        { "title": "Ethereum role (secondary)", "type": "string" },
    "token_standard_raw":             { "title": "Token standard (raw)", "type": "string" },
    "on_chain_lifecycle_primary":     { "title": "On-chain lifecycle events (primary)", "type": "string" },
    "on_chain_lifecycle_secondary":   { "title": "On-chain lifecycle events (secondary)", "type": "string" },
    "bidirectional_sync":             { "title": "Bidirectional sync", "type": "string" },
    "final_source_of_truth":          { "title": "Final source of truth", "type": "string", "enum": ["Off-chain registry", "On-chain", "Both"] },
    "kyc_aml_enforcement":            { "title": "KYC / AML enforcement", "type": "string" },
    "transfer_restrictions":          { "title": "Transfer restrictions", "type": "string" },
    "permissioning_model_primary":    { "title": "Permissioning model (primary)", "type": "string" },
    "permissioning_model_secondary":  { "title": "Permissioning model (secondary)", "type": "string" },
    "identity_provider_dependency":   { "title": "Identity provider dependency", "type": "string" },
    "identity_provider_project_slug": { "title": "Identity provider — project slug", "type": "string" },
    "who_pays_fees_primary":          { "title": "Who pays fees (primary)", "type": "string" },
    "who_pays_fees_secondary":        { "title": "Who pays fees (secondary)", "type": "string" },
    "fee_model":                      { "title": "Fee model", "type": "string" },
    "cash_flow_handling":             { "title": "Cash flow handling", "type": "string" },
    "custodians_raw":                 { "title": "Custodians (raw)", "type": "string" },
    "custodians_as_of_date":          { "title": "Custodians as-of date", "type": "string", "format": "date" },
    "key_trusted_parties":            { "title": "Key trusted parties", "type": "string" },
    "primary_risk_factor_1":          { "title": "Primary risk factor 1", "type": "string" },
    "primary_risk_factor_2":          { "title": "Primary risk factor 2", "type": "string" },
    "dispute_resolution":             { "title": "Dispute resolution", "type": "string" },
    "censorship_freeze_risk":         { "title": "Censorship / freeze risk", "type": "string", "enum": ["High", "Medium", "Low"] },
    "censorship_freeze_risk_as_of_date": { "title": "Censorship / freeze risk as-of date", "type": "string", "format": "date" },
    "primary_customers":              { "title": "Primary customers", "type": "string" },
    "composable_with_defi":           { "title": "Composable with DeFi", "type": "string", "enum": ["Yes", "No", "Limited"] },
    "scalability_constraints":        { "title": "Scalability constraints", "type": "string" },
    "defensibility_source":           { "title": "Defensibility source", "type": "string" },
    "sector_adjacency_risk":          { "title": "Sector adjacency risk", "type": "string" },
    "sector_adjacency_risk_as_of_date": { "title": "Sector adjacency risk as-of date", "type": "string", "format": "date" },
    "tokenization_platform_slug":     { "title": "Tokenization platform — project slug", "type": "string", "description": "Self-FK; e.g. BUIDL → securitize." }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'real-world-assets-rwas';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/identity-and-social-graphs.json",
  "title": "Identity & Social Graphs — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "primary_users":                  { "title": "Primary users", "type": "string" },
    "identity_type_primary":          { "title": "Identity type (primary)", "type": "string" },
    "identity_type_secondary":        { "title": "Identity type (secondary)", "type": "string" },
    "identifier_standard_raw":        { "title": "Identifier standard (raw)", "type": "string" },
    "reputation_attestation_type":    { "title": "Reputation / attestation type", "type": "string" },
    "social_graph_model":             { "title": "Social graph model", "type": "string" },
    "state_persistence_layer_primary":   { "title": "State persistence layer (primary)", "type": "string" },
    "state_persistence_layer_secondary": { "title": "State persistence layer (secondary)", "type": "string" },
    "ethereum_role_primary":          { "title": "Ethereum role (primary)", "type": "string" },
    "ethereum_role_secondary":        { "title": "Ethereum role (secondary)", "type": "string" },
    "on_chain_verifiability_value":   { "title": "On-chain verifiability", "type": "string", "enum": ["Yes", "No", "Partial"] },
    "on_chain_verifiability_detail":  { "title": "On-chain verifiability — detail", "type": "string" },
    "smart_contract_composability_value":  { "title": "Smart contract composability", "type": "string", "enum": ["Yes", "No", "Partial"] },
    "smart_contract_composability_detail": { "title": "Smart contract composability — detail", "type": "string" },
    "cross_protocol_reusability":     { "title": "Cross-protocol reusability", "type": "string", "enum": ["High", "Medium", "Low"] },
    "credential_standard_raw":        { "title": "Credential standard (raw)", "type": "string" },
    "who_can_issue_credentials":      { "title": "Who can issue credentials", "type": "string" },
    "revocation_mechanism":           { "title": "Revocation mechanism", "type": "string" },
    "role_permission_enforcement":    { "title": "Role / permission enforcement", "type": "string" },
    "sybil_resistance_primary":       { "title": "Sybil resistance (primary)", "type": "string" },
    "sybil_resistance_secondary":     { "title": "Sybil resistance (secondary)", "type": "string" },
    "verification_model_primary":     { "title": "Verification model (primary)", "type": "string" },
    "verification_model_secondary":   { "title": "Verification model (secondary)", "type": "string" },
    "key_trusted_parties":            { "title": "Key trusted parties", "type": "string" },
    "censorship_freeze_risk":         { "title": "Censorship / freeze risk", "type": "string", "enum": ["High", "Medium", "Low"] },
    "censorship_freeze_risk_as_of_date": { "title": "Censorship / freeze risk as-of date", "type": "string", "format": "date" },
    "upgrade_governance_control":     { "title": "Upgrade / governance control", "type": "string" },
    "centralized_dependency_value":   { "title": "Dependency on centralized services", "type": "string", "enum": ["Yes", "No", "Partial"] },
    "centralized_dependency_detail":  { "title": "Dependency on centralized services — detail", "type": "string" },
    "scalability_constraints":        { "title": "Scalability constraints", "type": "string" },
    "primary_use_cases":              { "title": "Primary use cases", "type": "string" },
    "composable_with_raw":            { "title": "Composable with (raw)", "type": "string" },
    "defensibility_source":           { "title": "Defensibility source", "type": "string" },
    "sector_adjacency_risk":          { "title": "Sector adjacency risk", "type": "string" },
    "sector_adjacency_risk_as_of_date": { "title": "Sector adjacency risk as-of date", "type": "string", "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'identity-and-social-graphs';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/depin-physical-infrastructure.json",
  "title": "DePIN (Physical Infrastructure) — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "primary_participants_primary":      { "title": "Primary participants (primary)", "type": "string" },
    "primary_participants_secondary":    { "title": "Primary participants (secondary)", "type": "string" },
    "physical_asset_type_primary":       { "title": "Physical asset type (primary)", "type": "string" },
    "physical_asset_type_secondary":     { "title": "Physical asset type (secondary)", "type": "string" },
    "hardware_ownership_model":          { "title": "Hardware ownership model", "type": "string", "enum": ["Operators", "Network-owned", "Hybrid"] },
    "coordinator_topology":              { "title": "Coordinator topology", "type": "string", "description": "v1 decentralization-axis dimension (ISS-S6-008): single-foundation, multi-operator-coordinated, permissionless, etc." },
    "governance_control_dimension":      { "title": "Governance control dimension", "type": "string", "description": "v1 decentralization-axis dimension (ISS-S6-008)." },
    "slashing_or_penalty_mechanism_bool": { "title": "Slashing / penalty mechanism", "type": ["boolean", "null"] },
    "slashing_or_penalty_mechanism_detail": { "title": "Slashing / penalty mechanism — detail", "type": "string" },
    "geographic_distribution_value":     { "title": "Geographic distribution", "type": "string", "enum": ["Global", "Regional", "Concentrated", "Single-jurisdiction"] },
    "geographic_distribution_as_of_date":{ "title": "Geographic distribution as-of date", "type": "string", "format": "date" },
    "geographic_distribution_detail":    { "title": "Geographic distribution — detail", "type": "string" },
    "minimum_physical_requirements":     { "title": "Minimum physical requirements", "type": "string" },
    "ethereum_role_primary":             { "title": "Ethereum role (primary)", "type": "string" },
    "ethereum_role_secondary":           { "title": "Ethereum role (secondary)", "type": "string" },
    "on_chain_settlement_scope":         { "title": "On-chain settlement scope", "type": "string" },
    "reward_distribution":               { "title": "Reward distribution", "type": "string" },
    "physical_activity_primary":         { "title": "Physical activity measured (primary)", "type": "string" },
    "physical_activity_secondary":       { "title": "Physical activity measured (secondary)", "type": "string" },
    "verification_method_primary":       { "title": "Verification method (primary)", "type": "string" },
    "verification_method_secondary":     { "title": "Verification method (secondary)", "type": "string" },
    "anti_cheating":                     { "title": "Anti-cheating", "type": "string" },
    "trusted_components":                { "title": "Trusted components", "type": "string" },
    "who_pays_primary":                  { "title": "Who pays (primary)", "type": "string" },
    "who_pays_secondary":                { "title": "Who pays (secondary)", "type": "string" },
    "token_incentive_model":             { "title": "Token incentive model", "type": "string" },
    "cost_structure_operators":          { "title": "Cost structure (operators)", "type": "string" },
    "governance_model":                  { "title": "Governance model", "type": "string" },
    "upgrade_control":                   { "title": "Upgrade control", "type": "string" },
    "centralized_dependency_value":      { "title": "Dependency on centralized infrastructure", "type": "string", "enum": ["Yes", "No", "Partial"] },
    "centralized_dependency_detail":     { "title": "Dependency on centralized infrastructure — detail", "type": "string" },
    "primary_risk_factor_1":             { "title": "Primary risk factor 1", "type": "string" },
    "primary_risk_factor_2":             { "title": "Primary risk factor 2", "type": "string" },
    "scalability_constraints":           { "title": "Scalability constraints", "type": "string" },
    "censorship_geographic_risk":        { "title": "Censorship / geographic risk", "type": "string", "enum": ["High", "Medium", "Low"] },
    "censorship_geographic_risk_as_of_date": { "title": "Censorship / geographic risk as-of date", "type": "string", "format": "date" },
    "composable_with_raw":               { "title": "Composable with (raw)", "type": "string" },
    "defensibility_source":              { "title": "Defensibility source", "type": "string" },
    "sector_adjacency_risk":             { "title": "Sector adjacency risk", "type": "string" },
    "sector_adjacency_risk_as_of_date":  { "title": "Sector adjacency risk as-of date", "type": "string", "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'depin-physical-infrastructure';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/cross-chain-compute.json",
  "title": "Cross-Chain Compute — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "primary_users":                      { "title": "Primary users", "type": "string" },
    "execution_location_primary":         { "title": "Execution location (primary)", "type": "string" },
    "execution_location_secondary":       { "title": "Execution location (secondary)", "type": "string" },
    "execution_type_primary":             { "title": "Execution type (primary)", "type": "string" },
    "execution_type_secondary":           { "title": "Execution type (secondary)", "type": "string" },
    "supported_chains_raw":               { "title": "Supported chains (raw)", "type": "string" },
    "verification_mechanism_primary":     { "title": "Verification mechanism (primary)", "type": "string" },
    "verification_mechanism_secondary":   { "title": "Verification mechanism (secondary)", "type": "string" },
    "verification_strength_tier":         { "title": "Verification strength tier", "type": "string", "enum": ["zk", "optimistic", "committee", "multisig", "tee", "hybrid", "other"] },
    "who_verifies_execution_primary":     { "title": "Who verifies execution (primary)", "type": "string" },
    "who_verifies_execution_secondary":   { "title": "Who verifies execution (secondary)", "type": "string" },
    "dispute_resolution_model":           { "title": "Dispute resolution model", "type": "string" },
    "finality_anchor":                    { "title": "Finality anchor", "type": "string" },
    "finality_anchor_project_slug":       { "title": "Finality anchor — project slug", "type": "string" },
    "ethereum_role_primary":              { "title": "Ethereum role (primary)", "type": "string" },
    "ethereum_role_secondary":            { "title": "Ethereum role (secondary)", "type": "string" },
    "on_chain_verifiability_value":       { "title": "On-chain verifiability", "type": "string", "enum": ["Yes", "No", "Partial"] },
    "on_chain_verifiability_detail":      { "title": "On-chain verifiability — detail", "type": "string" },
    "failure_handling":                   { "title": "Failure handling", "type": "string" },
    "trust_assumptions":                  { "title": "Trust assumptions", "type": "string" },
    "slashing_bool":                      { "title": "Slashing / penalty mechanism", "type": ["boolean", "null"] },
    "slashing_detail":                    { "title": "Slashing / penalty — detail", "type": "string" },
    "key_trusted_parties":                { "title": "Key trusted parties", "type": "string" },
    "who_pays_fees_primary":              { "title": "Who pays fees (primary)", "type": "string" },
    "who_pays_fees_secondary":            { "title": "Who pays fees (secondary)", "type": "string" },
    "fee_model":                          { "title": "Fee model", "type": "string" },
    "incentive_alignment":                { "title": "Incentive alignment", "type": "string" },
    "composable_with_raw":                { "title": "Composable with (raw)", "type": "string" },
    "scalability_constraints":            { "title": "Scalability constraints", "type": "string" },
    "defensibility_source":               { "title": "Defensibility source", "type": "string" },
    "sector_adjacency_risk":              { "title": "Sector adjacency risk", "type": "string" },
    "sector_adjacency_risk_as_of_date":   { "title": "Sector adjacency risk as-of date", "type": "string", "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'cross-chain-compute';
