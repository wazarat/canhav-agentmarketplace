-- M8.5 — Consensus Layer enrichment pass.
--
-- Adds the Tier-1 telemetry fields and the dual-enum `client_diversity_role` partner
-- to the consensus-layer subsector's `specific_field_schema`. Mirrors
-- `.cursor/skills/market-map/schemas/subsectors/consensus-layer.json`.
--
-- See:
--   - .cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/consensus-layer.md
--   - wazarat/consensuslayer/consensus-layer.data-sources.md  (Cursor sourcing guide)
--   - wazarat/consensuslayer/consensus-layer.fields-to-add.md (universal-field applicability)
--
-- Implementation deltas vs. the source docs:
--   * Tier-2 fields (audit_history, supported_features, incident_history,
--     min_hardware_requirements, governance_model, funding_dependency_on_ef) are NOT
--     added in this migration. They require manual curation per client and will be
--     introduced row-by-row once we have a curation flow. Parked in docs/FUTURE_PLANS.md.
--   * Tier-3 telemetry (open_critical_issues, slashing_incidents_attributed, etc.)
--     requires a cron runner. Parked in docs/FUTURE_PLANS.md.
--   * Schema remains `additionalProperties: true` so we can keep iterating without
--     re-migrating on every Tier-2/3 field promotion.

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/consensus-layer.json",
  "title": "Consensus Layer — subsector_attributes",
  "description": "Fields specific to the Consensus Layer subsector. Covers Ethereum consensus clients (Beacon Node + Validator), the canonical Ethereum Consensus Specifications, and related consensus-layer infrastructure.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "client_implementation": {
      "title": "Client implementation",
      "type": "string",
      "description": "What kind of consensus implementation this is."
    },
    "role_in_consensus": {
      "title": "Role in consensus",
      "type": "string",
      "description": "Semicolon-separated list of consensus duties this entity performs or defines."
    },
    "client_category": {
      "title": "Client category",
      "type": "string",
      "description": "High-level category."
    },
    "client_scope": {
      "title": "Client scope",
      "type": "string",
      "description": "Scope of operation."
    },
    "implementation_language": {
      "title": "Implementation language",
      "type": "string",
      "description": "Primary language. Lowercase string like 'rust', 'go', 'java', 'typescript', 'nim', or 'n/a' for specs.",
      "examples": ["rust", "go", "java", "typescript", "nim", "python", "c++", "n/a"]
    },
    "client_diversity_risk": {
      "title": "Client diversity risk",
      "type": "string",
      "description": "Severity grade of the concentration risk this entity poses to Ethereum client diversity. Always pair with client_diversity_role.",
      "examples": ["low", "low-medium", "medium", "medium-high", "high", "historically-dominant", "minority-positive", "n/a"]
    },
    "client_diversity_role": {
      "title": "Client diversity role",
      "type": "string",
      "description": "Qualitative role this entity plays in client diversity. Dual-enum partner to client_diversity_risk (severity).",
      "examples": [
        "dominant-incumbent",
        "balanced-contributor",
        "strategic-minority",
        "decentralization-critical",
        "research-language-diversity",
        "canonical-spec"
      ]
    },
    "client_diversity_risk_note": {
      "title": "Client diversity risk note",
      "type": "string",
      "description": "Free-text rationale, typically the parenthetical from the source sheet."
    },
    "validator_share_pct": {
      "title": "Validator share (%)",
      "type": "number",
      "minimum": 0,
      "maximum": 100,
      "description": "Approximate % of mainnet validators currently running this client. Backfilled from clientdiversity.org / rated.network as a 30-day rolling average."
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
 where slug = 'consensus-layer';
