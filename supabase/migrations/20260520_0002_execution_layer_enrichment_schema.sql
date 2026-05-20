-- M8.6 — Execution Layer subsector schema (Tier 1).
--
-- Replaces the placeholder `specific_field_schema` for slug='execution-layer'
-- with the real shape covering the four production execution clients
-- (Geth / Nethermind / Besu / Erigon) and the two canonical specs
-- (Yellow Paper + Execution EIPs). Mirrors
-- `.cursor/skills/market-map/schemas/subsectors/execution-layer.json`.
--
-- See:
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/execution-layer.md
--     (in-repo implementation reference — also mirrors the perplexity-supplied
--      narrative / data-sources / fields-to-add drafts)
--
-- Implementation deltas vs. the source docs:
--   * Tier-2 fields (audit_history, supported_features, incident_history,
--     min_hardware_requirements, governance_model, funding_dependency_on_ef,
--     eip_implementation_lag_days, engine_api_version_supported) are NOT added
--     in this migration. They require manual curation per client and will be
--     introduced row-by-row once we have a curation flow. Parked in
--     docs/FUTURE_PLANS.md "Execution Layer — Reth + Tier-2/3 fields".
--   * Tier-3 telemetry (open_critical_issues, mainnet_sync_status_30d_pct,
--     historical_fork_compliance_pct) requires a cron runner. Parked.
--   * The EIP-tracking proposal (a parallel `protocol_changes` table linking
--     EIP → fork → affected_clients) is NOT implemented here. It is captured as
--     a schema sketch in docs/FUTURE_PLANS.md "Execution Layer — EIP tracking
--     table" because it introduces a new top-level table and crosses subsector
--     boundaries (links to network-upgrades).
--   * `additionalProperties: true` is retained so Tier-2/3 promotions land via
--     a single JSONB schema bump rather than a fresh Postgres migration each
--     time.
--   * Reth is intentionally not seeded in `projects` — the source sheet does
--     not contain it. Re-evaluate after the next sheet refresh.

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/execution-layer.json",
  "title": "Execution Layer — subsector_attributes",
  "description": "Fields specific to the Execution Layer subsector. Covers Ethereum execution clients (Geth, Nethermind, Besu, Erigon, future Reth) plus the two canonical specs (Yellow Paper + Execution EIPs).",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "client_implementation": {
      "title": "Client implementation",
      "type": "string",
      "description": "What kind of execution implementation this is."
    },
    "role_in_execution": {
      "title": "Role in execution",
      "type": "string",
      "description": "Semicolon-separated list of execution duties (EVM bytecode execution, state transitions, gas accounting, mempool, engine-api)."
    },
    "execution_scope": {
      "title": "Execution scope",
      "type": "string",
      "description": "High-level scope. 'Execution Client' for production clients; 'Protocol Execution Specification (Normative)' for spec rows."
    },
    "vm_type": {
      "title": "VM type",
      "type": "string",
      "description": "Virtual machine flavor. Mainnet clients normalize to 'evm'; spec rows use 'evm-normative'.",
      "examples": ["evm", "evm-plus-precompiles", "evm-with-stateless-extensions", "evm-normative", "n/a"]
    },
    "gas_accounting_model": {
      "title": "Gas accounting model",
      "type": "string",
      "description": "Canonical Ethereum gas model variant.",
      "examples": ["canonical-evm-gas", "eip-1559", "eip-1559-plus-blob"]
    },
    "state_model": {
      "title": "State model (external)",
      "type": "string",
      "description": "Externally observable state model. 'mpt' for all mainnet clients today; 'verkle' is the post-Pectra direction.",
      "examples": ["mpt", "verkle", "binary-merkle"]
    },
    "state_model_internal": {
      "title": "State model (internal)",
      "type": "string",
      "description": "Internal storage representation. Distinct from `state_model` (which must be externally identical). Captures Erigon's flat-KV / staged-sync architecture.",
      "examples": ["mpt", "flat-kv", "erigon-staged-sync"]
    },
    "implementation_language": {
      "title": "Implementation language",
      "type": "string",
      "description": "Primary language. Lowercase string. 'n/a' for spec rows.",
      "examples": ["go", "csharp", "java", "rust", "typescript", "python", "n/a"]
    },
    "client_diversity_risk": {
      "title": "Client diversity risk",
      "type": "string",
      "description": "Severity grade of the concentration risk this entity poses. Always pair with client_diversity_role.",
      "examples": ["low", "low-medium", "medium", "medium-high", "high", "n/a"]
    },
    "client_diversity_role": {
      "title": "Client diversity role",
      "type": "string",
      "description": "Qualitative role this entity plays in execution-client diversity. Dual-enum partner to client_diversity_risk.",
      "examples": [
        "dominant-incumbent",
        "balanced-contributor",
        "institutional-contributor",
        "architectural-diversity",
        "canonical-spec"
      ]
    },
    "client_diversity_risk_note": {
      "title": "Client diversity risk note",
      "type": "string",
      "description": "Free-text rationale, typically the verbatim 'Client Diversity Risk Flag' cell from the source sheet."
    },
    "execution_share_pct": {
      "title": "Execution-node share (%)",
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Approximate % of mainnet full nodes running this execution client. Pair with data_confidence + data_refreshed_at."
    },
    "funding_model": {
      "title": "Funding model",
      "type": "string",
      "description": "How the entity is funded. Execution-layer specific because the four clients fund themselves in fundamentally different ways.",
      "examples": ["venture", "foundation-internal", "corporate-internal", "grants-plus-services", "dao", "community", "n/a"]
    },
    "latest_release_tag": {
      "title": "Latest release tag",
      "type": "string",
      "description": "Most recent GitHub release tag. Liveness signal."
    },
    "latest_release_date": {
      "title": "Latest release date",
      "type": "string",
      "format": "date",
      "description": "ISO date of the latest release."
    },
    "contributors_last_90d": {
      "title": "Contributors (last 90d)",
      "type": "integer",
      "minimum": 0,
      "description": "Approximate count of distinct GitHub contributors active in the last 90 days."
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
 where slug = 'execution-layer';
