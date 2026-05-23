-- Market Map — Sector 5 (Data & Consensus Infrastructure) sector-wide schema.
--
-- WHAT THIS LANDS.
--   1. Three sector-wide typed columns on public.projects (promoted from JSONB
--      after appearing in 4 of 5 Sector 5 subsectors' field specs):
--        - data_infra_archetype          text
--        - trust_model                   text
--        - centralization_risk_score     smallint (0-10)
--        - centralization_risk_evidence_quality text
--   2. Sector-common JSON Schema for sectors.slug='data-consensus-infrastructure'.
--   3. Subsector-specific JSON Schemas for the five Sector 5 subsectors:
--        - rpc-node-providers
--        - oracles-data-networks
--        - data-availability-systems
--        - indexing-query-engines
--        - analytics-intelligence
--
-- WHY THIS PATTERN.
--   Sectors 3 (Monetary) and 4 (DeFi) shipped JSONB-only schemas; Sector 2
--   (Rollup) shipped sidecars. Sector 5 ships both: this migration handles
--   the sector-wide JSONB schema + universal column promotions, then the
--   five 20260523_0003-0007 migrations add one sidecar + view per subsector.
--   The backend SUBSECTOR_VIEW_REGISTRY (refactored in M8.16) is wired in
--   the same change so every sidecar field surfaces on the project page.

-- ---------------------------------------------------------------------------
-- 1. Sector-wide typed columns on public.projects.
-- ---------------------------------------------------------------------------

alter table public.projects
  add column if not exists data_infra_archetype text,
  add column if not exists trust_model text,
  add column if not exists centralization_risk_score smallint,
  add column if not exists centralization_risk_evidence_quality text;

alter table public.projects
  drop constraint if exists projects_data_infra_archetype_check;
alter table public.projects
  add constraint projects_data_infra_archetype_check
  check (
    data_infra_archetype is null
    or data_infra_archetype in (
      'rpc-provider',
      'oracle-network',
      'da-layer',
      'indexer',
      'analytics-platform',
      'multi-archetype'
    )
  );

alter table public.projects
  drop constraint if exists projects_trust_model_check;
alter table public.projects
  add constraint projects_trust_model_check
  check (
    trust_model is null
    or trust_model in (
      'cryptographic',
      'cryptoeconomic',
      'multi-operator',
      'single-operator',
      'self-hosted',
      'hybrid'
    )
  );

alter table public.projects
  drop constraint if exists projects_centralization_risk_score_check;
alter table public.projects
  add constraint projects_centralization_risk_score_check
  check (
    centralization_risk_score is null
    or (centralization_risk_score between 0 and 10)
  );

alter table public.projects
  drop constraint if exists projects_centralization_risk_evidence_quality_check;
alter table public.projects
  add constraint projects_centralization_risk_evidence_quality_check
  check (
    centralization_risk_evidence_quality is null
    or centralization_risk_evidence_quality in (
      'confirmed',
      'claimed',
      'inferred',
      'not-disclosed',
      'sourced-from-public-data',
      'editorial-judgment'
    )
  );

-- Mandate the evidence-quality companion whenever a score is recorded.
alter table public.projects
  drop constraint if exists projects_centralization_risk_evidence_required;
alter table public.projects
  add constraint projects_centralization_risk_evidence_required
  check (
    centralization_risk_score is null
    or centralization_risk_evidence_quality is not null
  );

create index if not exists idx_projects_data_infra_archetype
  on public.projects (data_infra_archetype);
create index if not exists idx_projects_trust_model
  on public.projects (trust_model);
create index if not exists idx_projects_centralization_risk_score
  on public.projects (centralization_risk_score);

-- ---------------------------------------------------------------------------
-- 2. Sector-common JSON Schema (rendered as humanLabels by the project page).
-- ---------------------------------------------------------------------------

update public.sectors
   set common_field_schema = $json$
{
  "type": "object",
  "properties": {
    "data_infra_archetype": {
      "humanLabel": "Data infra archetype",
      "type": "string",
      "enum": ["rpc-provider", "oracle-network", "da-layer", "indexer", "analytics-platform", "multi-archetype"]
    },
    "trust_model": {
      "humanLabel": "Trust model",
      "type": "string",
      "enum": ["cryptographic", "cryptoeconomic", "multi-operator", "single-operator", "self-hosted", "hybrid"]
    },
    "centralization_risk_score": {
      "humanLabel": "Centralization risk score (0-10)",
      "type": "integer",
      "minimum": 0,
      "maximum": 10
    },
    "centralization_risk_evidence_quality": {
      "humanLabel": "Centralization risk evidence quality",
      "type": "string"
    },
    "maintaining_organization": {
      "humanLabel": "Maintaining organization",
      "type": "string"
    },
    "year_founded": {
      "humanLabel": "Year founded",
      "type": "integer"
    },
    "headquarters_jurisdiction": {
      "humanLabel": "Headquarters / jurisdiction",
      "type": "string"
    },
    "previous_names": {
      "humanLabel": "Previous names",
      "type": "array",
      "items": {"type": "string"}
    }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'data-consensus-infrastructure';

-- ---------------------------------------------------------------------------
-- 3. Subsector-specific JSON Schemas.
--    Field set follows the cleaned source workbook
--    (Data-and-Consensus-Infrastructure_cleaned_v1.xlsx) one-to-one. The
--    enrichment scripts (Phase 6) populate subsector_attributes with these
--    keys; the project page renders any key whose value is non-empty.
-- ---------------------------------------------------------------------------

-- 3a. rpc-node-providers
update public.subsectors
   set specific_field_schema = $json$
{
  "type": "object",
  "properties": {
    "entity_type": {"humanLabel": "Entity type", "type": "string"},
    "primary_role_in_stack": {"humanLabel": "Primary role in stack", "type": "string"},
    "ethereum_clients_supported": {"humanLabel": "Ethereum clients supported", "type": "string"},
    "execution_consensus_coverage": {"humanLabel": "Execution / consensus coverage", "type": "string"},
    "rpc_interfaces_supported": {"humanLabel": "RPC interfaces supported", "type": "string"},
    "transaction_submission_supported": {"humanLabel": "Transaction submission supported", "type": "string"},
    "archive_node_support": {"humanLabel": "Archive node support", "type": "string"},
    "historical_depth": {"humanLabel": "Historical depth", "type": "string"},
    "geographic_distribution": {"humanLabel": "Geographic distribution", "type": "string"},
    "uptime_sla_claims": {"humanLabel": "Uptime / SLA claims", "type": "string"},
    "decentralization_model": {"humanLabel": "Decentralization model", "type": "string"},
    "censorship_resistance_characteristics": {"humanLabel": "Censorship resistance characteristics", "type": "string"},
    "client_diversity_risk": {"humanLabel": "Client diversity risk", "type": "string"},
    "known_outages_or_incidents": {"humanLabel": "Known outages or incidents", "type": "string"},
    "pricing_model": {"humanLabel": "Pricing model", "type": "string"},
    "cost_sensitivity_at_scale": {"humanLabel": "Cost sensitivity at scale", "type": "string"},
    "rate_limits_throttling_model": {"humanLabel": "Rate limits / throttling model", "type": "string"},
    "description": {"humanLabel": "Description", "type": "string"},
    "reason_for_inclusion": {"humanLabel": "Reason for inclusion", "type": "string"},
    "practitioner_note": {"humanLabel": "Practitioner's note", "type": "string"},
    "practitioner_validation_check": {"humanLabel": "Practitioner validation check", "type": "string"},
    "typical_users": {"humanLabel": "Typical users", "type": "string"},
    "downstream_dependency_risk": {"humanLabel": "Downstream dependency risk", "type": "string"},
    "replaceability_score": {"humanLabel": "Replaceability score", "type": "string"}
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'rpc-node-providers';

-- 3b. oracles-data-networks
update public.subsectors
   set specific_field_schema = $json$
{
  "type": "object",
  "properties": {
    "oracle_type": {"humanLabel": "Oracle type", "type": "string"},
    "primary_data_domain": {"humanLabel": "Primary data domain", "type": "string"},
    "on_chain_footprint": {"humanLabel": "On-chain footprint", "type": "string"},
    "data_source_model": {"humanLabel": "Data source model", "type": "string"},
    "verification_mechanism": {"humanLabel": "Verification mechanism", "type": "string"},
    "who_can_submit_data": {"humanLabel": "Who can submit data", "type": "string"},
    "who_can_challenge_data": {"humanLabel": "Who can challenge data", "type": "string"},
    "freshness_guarantees": {"humanLabel": "Freshness guarantees", "type": "string"},
    "correctness_guarantees": {"humanLabel": "Correctness guarantees", "type": "string"},
    "availability_guarantees": {"humanLabel": "Availability guarantees", "type": "string"},
    "failure_handling_dispute_resolution": {"humanLabel": "Failure handling / dispute resolution", "type": "string"},
    "security_model": {"humanLabel": "Security model", "type": "string"},
    "cost_model": {"humanLabel": "Cost model", "type": "string"},
    "value_at_risk_alignment": {"humanLabel": "Value at risk alignment", "type": "string"},
    "typical_protocol_dependencies": {"humanLabel": "Typical protocol dependencies", "type": "string"},
    "downstream_economic_impact_if_incorrect": {"humanLabel": "Downstream economic impact if incorrect", "type": "string"},
    "centralization_risk_note": {"humanLabel": "Centralization risk (qualitative)", "type": "string"},
    "known_exploits_or_incidents": {"humanLabel": "Known exploits or incidents", "type": "string"},
    "description": {"humanLabel": "Description", "type": "string"},
    "reason_for_inclusion": {"humanLabel": "Reason for inclusion", "type": "string"},
    "practitioner_note": {"humanLabel": "Practitioner's note", "type": "string"},
    "practitioner_validation_check": {"humanLabel": "Practitioner validation check", "type": "string"},
    "typical_users": {"humanLabel": "Typical users", "type": "string"},
    "replaceability_score": {"humanLabel": "Replaceability score", "type": "string"},
    "oracle_dependency_criticality": {"humanLabel": "Oracle dependency criticality", "type": "string"},
    "products": {
      "humanLabel": "Products",
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "product_name": {"type": "string"},
          "oracle_type": {"type": "string"},
          "primary_data_domain": {"type": "string"},
          "verification_mechanism": {"type": "string"},
          "product_url": {"type": "string"}
        }
      }
    }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'oracles-data-networks';

-- 3c. data-availability-systems
update public.subsectors
   set specific_field_schema = $json$
{
  "type": "object",
  "properties": {
    "da_type": {"humanLabel": "DA type", "type": "string"},
    "primary_da_consumer": {"humanLabel": "Primary DA consumer", "type": "string"},
    "execution_coupling": {"humanLabel": "Execution coupling", "type": "string"},
    "data_publication_method": {"humanLabel": "Data publication method", "type": "string"},
    "availability_guarantee_model": {"humanLabel": "Availability guarantee model", "type": "string"},
    "verification_mechanism": {"humanLabel": "Verification mechanism", "type": "string"},
    "who_can_withhold_data": {"humanLabel": "Who can withhold data", "type": "string"},
    "who_detects_withholding": {"humanLabel": "Who detects withholding", "type": "string"},
    "primary_failure_mode": {"humanLabel": "Primary failure mode", "type": "string"},
    "time_to_detect_failure": {"humanLabel": "Time to detect failure", "type": "string"},
    "recovery_path": {"humanLabel": "Recovery path", "type": "string"},
    "impact_of_da_failure": {"humanLabel": "Impact of DA failure", "type": "string"},
    "cost_model": {"humanLabel": "Cost model", "type": "string"},
    "cost_vs_ethereum_da": {"humanLabel": "Cost vs Ethereum DA", "type": "string"},
    "scaling_characteristics": {"humanLabel": "Scaling characteristics", "type": "string"},
    "typical_protocol_dependencies": {"humanLabel": "Typical protocol dependencies", "type": "string"},
    "centralization_risk_note": {"humanLabel": "Centralization risk (qualitative)", "type": "string"},
    "known_incidents_or_risks": {"humanLabel": "Known incidents or risks", "type": "string"},
    "description": {"humanLabel": "Description", "type": "string"},
    "reason_for_inclusion": {"humanLabel": "Reason for inclusion", "type": "string"},
    "practitioner_note": {"humanLabel": "Practitioner's note", "type": "string"},
    "practitioner_validation_check": {"humanLabel": "Practitioner validation check", "type": "string"},
    "replaceability_score": {"humanLabel": "Replaceability score", "type": "string"},
    "da_dependency_criticality": {"humanLabel": "DA dependency criticality", "type": "string"},
    "long_term_viability_risk": {"humanLabel": "Long-term viability risk", "type": "string"}
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'data-availability-systems';

-- 3d. indexing-query-engines
update public.subsectors
   set specific_field_schema = $json$
{
  "type": "object",
  "properties": {
    "indexer_type": {"humanLabel": "Indexer type", "type": "string"},
    "primary_data_coverage": {"humanLabel": "Primary data coverage", "type": "string"},
    "primary_users": {"humanLabel": "Primary users", "type": "string"},
    "execution_coupling": {"humanLabel": "Execution coupling", "type": "string"},
    "indexing_model": {"humanLabel": "Indexing model", "type": "string"},
    "query_interface": {"humanLabel": "Query interface", "type": "string"},
    "real_time_support": {"humanLabel": "Real-time support", "type": "string"},
    "reorg_handling_strategy": {"humanLabel": "Reorg handling strategy", "type": "string"},
    "data_freshness_guarantees": {"humanLabel": "Data freshness guarantees", "type": "string"},
    "historical_depth": {"humanLabel": "Historical depth", "type": "string"},
    "backfill_capability": {"humanLabel": "Backfill capability", "type": "string"},
    "failure_modes": {"humanLabel": "Failure modes", "type": "string"},
    "pricing_model": {"humanLabel": "Pricing model", "type": "string"},
    "cost_sensitivity_at_scale": {"humanLabel": "Cost sensitivity at scale", "type": "string"},
    "rate_limits_quotas": {"humanLabel": "Rate limits / quotas", "type": "string"},
    "typical_protocol_dependencies": {"humanLabel": "Typical protocol dependencies", "type": "string"},
    "centralization_risk_note": {"humanLabel": "Centralization risk (qualitative)", "type": "string"},
    "known_incidents_or_gaps": {"humanLabel": "Known incidents or gaps", "type": "string"},
    "description": {"humanLabel": "Description", "type": "string"},
    "reason_for_inclusion": {"humanLabel": "Reason for inclusion", "type": "string"},
    "practitioner_note": {"humanLabel": "Practitioner's note", "type": "string"},
    "practitioner_validation_check": {"humanLabel": "Practitioner validation check", "type": "string"},
    "replaceability_score": {"humanLabel": "Replaceability score", "type": "string"},
    "indexing_dependency_criticality": {"humanLabel": "Indexing dependency criticality", "type": "string"},
    "operational_complexity": {"humanLabel": "Operational complexity", "type": "string"},
    "product_scopes": {
      "humanLabel": "Product scopes",
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "product_name": {"type": "string"},
          "subsector_slug": {"type": "string"},
          "notes": {"type": "string"}
        }
      }
    }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'indexing-query-engines';

-- 3e. analytics-intelligence
update public.subsectors
   set specific_field_schema = $json$
{
  "type": "object",
  "properties": {
    "analytics_type": {"humanLabel": "Analytics type", "type": "string"},
    "primary_audience": {"humanLabel": "Primary audience", "type": "string"},
    "primary_inputs": {"humanLabel": "Primary inputs", "type": "string"},
    "core_models_used": {"humanLabel": "Core models used", "type": "string"},
    "time_horizon": {"humanLabel": "Time horizon", "type": "string"},
    "explainability_level": {"humanLabel": "Explainability level", "type": "string"},
    "data_freshness_dependence": {"humanLabel": "Data freshness dependence", "type": "string"},
    "assumption_sensitivity": {"humanLabel": "Assumption sensitivity", "type": "string"},
    "known_biases_blind_spots": {"humanLabel": "Known biases / blind spots", "type": "string"},
    "failure_modes": {"humanLabel": "Failure modes", "type": "string"},
    "pricing_model": {"humanLabel": "Pricing model", "type": "string"},
    "cost_sensitivity_at_scale": {"humanLabel": "Cost sensitivity at scale", "type": "string"},
    "typical_decision_impact": {"humanLabel": "Typical decision impact", "type": "string"},
    "narrative_influence_level": {"humanLabel": "Narrative influence level", "type": "string"},
    "centralization_risk_note": {"humanLabel": "Centralization risk (qualitative)", "type": "string"},
    "description": {"humanLabel": "Description", "type": "string"},
    "reason_for_inclusion": {"humanLabel": "Reason for inclusion", "type": "string"},
    "practitioner_note": {"humanLabel": "Practitioner's note", "type": "string"},
    "practitioner_validation_check": {"humanLabel": "Practitioner validation check", "type": "string"},
    "replaceability_score": {"humanLabel": "Replaceability score", "type": "string"},
    "decision_dependency_criticality": {"humanLabel": "Decision dependency criticality", "type": "string"},
    "epistemic_risk_level": {"humanLabel": "Epistemic risk level", "type": "string"}
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'analytics-intelligence';
