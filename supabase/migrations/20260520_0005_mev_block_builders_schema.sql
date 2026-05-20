-- M8.8 — MEV & Block Builders subsector schema (Tier 1).
--
-- Replaces the placeholder `specific_field_schema` for slug='mev-block-builders'
-- with the real shape covering the 4 archetypes:
--
--   1. Block Builders          (Flashbots Builder, Titan, bloXroute Builder, rsync-builder)
--   2. MEV Relays              (Flashbots Relay, bloXroute Relay, Ultra Sound Relay, Eden Relay)
--   3. Searcher Infrastructure (Flashbots Searcher Infra, bloXroute Searcher Pipeline,
--                              Eden Network Searcher Infra, Builder-Native Searchers AGG)
--   4. Integrated MEV Stack    (Flashbots, bloXroute, Eden Network, Builder-Relay Integrated AGG)
--
-- 16 rows total. 14 attach to one of 6 org slugs (3 of which — flashbots,
-- bloxroute-labs, eden-network — back multiple subsector rows; the
-- maintaining_organization SSoT pattern from M8.7 is what makes this clean).
-- 2 rows are aggregates and set is_aggregate=true with
-- not_applicable_reason='aggregate_category'.
--
-- Mirrors `.cursor/skills/market-map/schemas/subsectors/mev-block-builders.json`.
--
-- See:
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/
--     mev-block-builders.md (implementation reference)
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/
--     mev-block-builders.{narrative,data-sources,fields-to-add}.md (Perplexity v6
--     mirrored references)
--
-- Implementation deltas vs. the source docs:
--   * Tier-2 fields (ofac_filtering_pct, builder_pubkey, policy_last_changed_date,
--     composite_concentration_score) are NOT added in this migration. They
--     require live mevboost.pics / relayscan.io integration. Parked in
--     docs/FUTURE_PLANS.md.
--   * additionalProperties: true is retained so Tier-2/3 promotions land via a
--     single JSONB schema bump rather than a fresh Postgres migration each time.
--   * Dual-enum splits (censorship_policy x censorship_policy_layer;
--     infrastructure_topology x infrastructure_advantage_source) live entirely
--     in JSONB. Same pattern as Validators' client_diversity_risk x
--     client_diversity_role.

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/mev-block-builders.json",
  "title": "MEV & Block Builders — subsector_attributes",
  "description": "Fields specific to the MEV & Block Builders subsector. Covers 4 archetypes: block builders, MEV relays, block-coupled searcher infrastructure, and vertically-integrated MEV stacks. Two rows are aggregates (Builder-Native Searcher Pipelines, Builder-Relay Integrated Operators).",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "mev_subsector_type": {
      "title": "MEV subsector type",
      "type": "string",
      "description": "Replaces the source sheet's free-text 'MEV Subsector Type' column. Four canonical archetypes per the v6 narrative.",
      "examples": [
        "block-builder",
        "mev-relay",
        "searcher-infrastructure",
        "integrated-mev-stack"
      ]
    },
    "operational_role": {
      "title": "Operational role",
      "type": "string",
      "description": "Free-text role description from the source sheet."
    },
    "block_construction_authority": {
      "title": "Block construction authority",
      "type": "string",
      "description": "How much of the block this entity actually constructs.",
      "examples": [
        "full",
        "partial-bundles-only",
        "gatekeeping-relay",
        "partial-full-builder-varies",
        "none"
      ]
    },
    "transaction_ordering_control": {
      "title": "Transaction ordering control",
      "type": "string",
      "description": "How directly this entity dictates intra-block transaction order.",
      "examples": ["full", "conditional", "indirect", "none"]
    },
    "validator_access_path": {
      "title": "Validator access path",
      "type": "string",
      "description": "How this entity reaches proposers.",
      "examples": [
        "direct",
        "relay-mediated",
        "hybrid",
        "network-optimized",
        "indirect-via-owning-builder"
      ]
    },
    "validator_coverage_band": {
      "title": "Validator coverage (band)",
      "type": "string",
      "description": "Coarse qualitative band from the source sheet. Pair with validator_coverage_pct.",
      "examples": ["negligible", "small", "small-medium", "medium", "medium-large", "large", "dominant", "unknown"]
    },
    "validator_coverage_pct": {
      "title": "Validator coverage (%)",
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Approximate % of MEV-Boost validators subscribed to this relay (relay rows) or % of MEV-Boost blocks produced by this builder (builder rows). Tier-1 source: mevboost.pics / relayscan.io. Curated baselines until that integration ships."
    },
    "primary_mev_types": {
      "title": "Primary MEV types enabled",
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "arbitrage",
          "sandwich",
          "liquidations",
          "front-running",
          "back-running",
          "jit-liquidity",
          "cross-domain",
          "toxic-flow",
          "latency-sensitive",
          "bundle-based",
          "benign"
        ]
      },
      "description": "Array of MEV categories. Normalized from the sheet's comma-list."
    },
    "censorship_policy": {
      "title": "Censorship / filtering policy",
      "type": "string",
      "description": "What the entity actually does about OFAC-sanctioned addresses. Dual-enum partner to censorship_policy_layer.",
      "examples": [
        "neutral",
        "ofac-aligned",
        "builder-specific",
        "configurable",
        "opaque",
        "policy-driven",
        "evolving",
        "n/a"
      ]
    },
    "censorship_policy_layer": {
      "title": "Censorship policy layer",
      "type": "string",
      "description": "Where in the stack the filtering happens. Dual-enum partner to censorship_policy.",
      "examples": ["relay-enforced", "builder-enforced", "both", "upstream-inherited", "n/a"]
    },
    "censorship_policy_note": {
      "title": "Censorship policy note",
      "type": "string",
      "description": "Free-text rationale."
    },
    "infrastructure_topology": {
      "title": "Infrastructure topology",
      "type": "string",
      "description": "Coarse shape of the operating infrastructure. Dual-enum partner to infrastructure_advantage_source.",
      "examples": ["centralized", "federated", "decentralized", "hybrid"]
    },
    "infrastructure_advantage_source": {
      "title": "Infrastructure advantage source",
      "type": "string",
      "description": "Where the competitive moat actually comes from. Dual-enum partner to infrastructure_topology.",
      "examples": [
        "software-stack",
        "networking-latency",
        "validator-relationships",
        "policy-default",
        "none-stated"
      ]
    },
    "infrastructure_control_note": {
      "title": "Infrastructure control note",
      "type": "string"
    },
    "vertical_integration_flag": {
      "title": "Vertical integration flag",
      "type": "boolean",
      "description": "True when the entity operates across multiple MEV layers."
    },
    "vertical_integration_note": {
      "title": "Vertical integration note",
      "type": "string"
    },
    "single_point_of_failure_risk": {
      "title": "Single-point-of-failure risk",
      "type": "string",
      "description": "Engineering risk if THIS entity goes down. Distinct from protocol_influence_surface (political risk).",
      "examples": ["low", "low-medium", "medium", "medium-high", "high"]
    },
    "governance_influence_vector": {
      "title": "Governance influence vector",
      "type": "string",
      "examples": [
        "corporate",
        "corporate-ecosystem",
        "private-opaque",
        "community",
        "dao",
        "none"
      ]
    },
    "protocol_influence_surface": {
      "title": "Protocol influence surface",
      "type": "string",
      "description": "Political risk: how much can this entity shape PBS, MEV-Boost, ePBS norms?",
      "examples": ["low", "low-medium", "medium", "medium-high", "high", "very-high"]
    },
    "mev_boost_relay_endpoint": {
      "title": "MEV-Boost relay endpoint",
      "type": "string",
      "format": "uri",
      "description": "For relay rows only. The public mev-boost subscription URL."
    },
    "data_refreshed_at": {
      "title": "Data refreshed at",
      "type": "string",
      "format": "date-time"
    },
    "data_confidence": {
      "title": "Data confidence",
      "type": "string",
      "examples": ["verified", "estimate", "stale"]
    }
  }
}
$json$::jsonb
 where slug = 'mev-block-builders';
