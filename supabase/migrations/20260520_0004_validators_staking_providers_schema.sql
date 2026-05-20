-- M8.7 — Validators & Staking Providers subsector schema (Tier 1).
--
-- Replaces the placeholder `specific_field_schema` for slug='validators-staking-providers'
-- with the real shape covering the 4 operator archetypes:
--
--   1. Professional Validator Operators (Figment, Chorus One, P2P.org, Blockdaemon)
--   2. Exchange Validator Operations    (Coinbase, Kraken, Binance — parent org is the FK)
--   3. Liquid Staking Protocol Operators (Lido DAO, Rocket Pool DAO, StakeWise DAO)
--   4. Solo Validators                  (aggregate row; is_aggregate=true)
--
-- Mirrors `.cursor/skills/market-map/schemas/subsectors/validators-staking-providers.json`.
--
-- See:
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/
--     validators-staking-providers.md (implementation reference)
--
-- Implementation deltas vs. the source docs:
--   * Tier-2 fields (dvt_adoption_status, ofac_filtering_policy, geographic_distribution,
--     infra_provider_mix, key_management_model, validator_operation_model, soc2_status,
--     insurance_coverage_usd, protocol_fee_pct, liquid_token_address,
--     operator_count_in_set, permissionless) are NOT added in this migration. They
--     require operator transparency reports and manual curation. Parked in
--     docs/FUTURE_PLANS.md.
--   * Tier-3 telemetry (missed_attestations_30d, proposer_eff_30d_pct,
--     withdrawal_queue_position, last_significant_incident) requires a cron runner. Parked.
--   * The composite_risk_score is a derived/computed field that depends on Tier-2 inputs.
--     Parked until the inputs land.
--   * additionalProperties: true is retained so Tier-2/3 promotions land via a single
--     JSONB schema bump rather than a fresh Postgres migration each time.

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/validators-staking-providers.json",
  "title": "Validators & Staking Providers — subsector_attributes",
  "description": "Fields specific to the Validators & Staking Providers subsector. Covers professional operators, exchange validator ops, liquid-staking-protocol operator sets, and the solo-validator aggregate.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "operator_archetype": {
      "title": "Operator archetype",
      "type": "string",
      "description": "Replaces the source sheet's free-text `Type` column. Tells you what *kind* of operator this is.",
      "examples": [
        "professional_operator",
        "exchange_staking",
        "liquid_staking_protocol_infra",
        "solo_staker_collective",
        "restaking_operator",
        "dvt_network",
        "custody_with_staking"
      ]
    },
    "operational_role": {
      "title": "Operational role",
      "type": "string",
      "description": "Free-text role description from the source sheet."
    },
    "validator_operation_model": {
      "title": "Validator operation model",
      "type": "string",
      "description": "How validators are actually operated.",
      "examples": [
        "solo",
        "delegated-custodial",
        "delegated-non-custodial",
        "pooled-custodial",
        "pooled-noncustodial",
        "protocol-coordinated",
        "permissionless-pool",
        "dvt-distributed"
      ]
    },
    "key_management_model": {
      "title": "Key management model",
      "type": "string",
      "description": "Who controls the validator signing keys. Free-text from the source sheet; future Tier-2 work normalizes to enum.",
      "examples": [
        "custodian-controlled",
        "client-controlled",
        "dvt-distributed",
        "user-controlled",
        "hsm-backed"
      ]
    },
    "infrastructure_control": {
      "title": "Infrastructure control",
      "type": "string",
      "description": "Hosting profile.",
      "examples": ["self-hosted", "hybrid", "cloud-dominant"]
    },
    "consensus_client_mix": {
      "title": "Consensus client mix (primary)",
      "type": "string",
      "description": "Comma- or paren-formatted list of the consensus clients this operator runs. Free-text from sheet; downstream queries should slug-match against the consensus-layer subsector slugs."
    },
    "execution_client_mix": {
      "title": "Execution client mix (primary)",
      "type": "string",
      "description": "Same as consensus_client_mix, against execution-layer slugs."
    },
    "client_diversity_risk": {
      "title": "Client diversity risk",
      "type": "string",
      "description": "Severity grade of the client-monoculture risk this operator introduces. Pair with client_diversity_role.",
      "examples": ["low", "low-medium", "medium", "medium-high", "high"]
    },
    "client_diversity_role": {
      "title": "Client diversity role",
      "type": "string",
      "description": "Qualitative role this operator plays in client-diversity outcomes. Dual-enum partner to client_diversity_risk. Validators introduces three operator-only values absent from Consensus/Execution.",
      "examples": [
        "heterogeneity-anchor",
        "active-contributor",
        "compliant-default",
        "scale-correlated",
        "scale-correlated-active",
        "scale-and-concentration",
        "scale-and-monoculture"
      ]
    },
    "client_diversity_risk_note": {
      "title": "Client diversity risk note",
      "type": "string",
      "description": "Free-text rationale, typically the verbatim source phrase from the sheet's `Client Diversity Risk Flag` column."
    },
    "estimated_validator_share_band": {
      "title": "Estimated validator share (band)",
      "type": "string",
      "description": "Coarse qualitative band from the source sheet's `Estimated Share of Active Validators`. Pair with validator_share_pct for numeric.",
      "examples": ["negligible", "small", "small-medium", "medium", "medium-large", "large", "dominant", "unknown"]
    },
    "validator_share_pct": {
      "title": "Validator share (%)",
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Approximate % of active mainnet validators run by this operator. Tier-1 source: rated.network."
    },
    "validator_count": {
      "title": "Validator count",
      "type": "integer",
      "minimum": 0,
      "description": "Raw number of mainnet validators run by this operator. validator_count × 32 ETH = total stake."
    },
    "concentration_risk": {
      "title": "Concentration risk",
      "type": "string",
      "description": "Risk if THIS operator (regardless of client mix) goes offline.",
      "examples": ["low", "low-medium", "medium", "medium-high", "high"]
    },
    "censorship_sensitivity": {
      "title": "Censorship sensitivity",
      "type": "string",
      "description": "Likelihood this operator filters transactions under regulatory pressure.",
      "examples": ["low", "low-medium", "medium", "medium-high", "high"]
    },
    "governance_influence_vector": {
      "title": "Governance influence vector",
      "type": "string",
      "description": "Operator's primary lane of influence over Ethereum governance.",
      "examples": ["individual", "corporate", "corporate-ecosystem", "dao-governed", "protocol-embedded", "research", "regulatory", "none"]
    },
    "data_refreshed_at": {
      "title": "Data refreshed at",
      "type": "string",
      "format": "date-time",
      "description": "ISO timestamp of the most recent successful enrichment run."
    },
    "data_confidence": {
      "title": "Data confidence",
      "type": "string",
      "description": "Confidence band for live-fetch fields.",
      "examples": ["verified", "estimate", "stale"]
    }
  }
}
$json$::jsonb
 where slug = 'validators-staking-providers';
