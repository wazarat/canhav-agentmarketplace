-- M8.5 — Consensus Layer pilot.
--
-- 1) Point the consensus-layer subsector at the new authoritative source sheet
--    (https://docs.google.com/spreadsheets/d/1DQB35o6r52b-6sazjzdtdXViC5I6IVbh/edit?gid=1429524989).
-- 2) Install the JSON Schemas mirrored from .cursor/skills/market-map/schemas/*.json so the
--    backend can return field titles + descriptions for the UI (`humanLabel`).
--
-- These schemas are intentionally additive (`additionalProperties: true`) so we can keep evolving
-- the per-row shape during the sector loop without re-migrating on every iteration.

update public.subsectors
   set source_sheet_id  = '1DQB35o6r52b-6sazjzdtdXViC5I6IVbh',
       source_sheet_gid = '1429524989'
 where slug = 'consensus-layer';

-- ---------------------------------------------------------------------------
-- Core Protocol Architecture — sector_attributes schema
-- ---------------------------------------------------------------------------
update public.sectors
   set common_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/sectors/core-protocol-architecture.json",
  "title": "Core Protocol Architecture — sector_attributes",
  "description": "Fields shared by every subsector in Core Protocol Architecture (Consensus Layer, Execution Layer, Validators & Staking Providers, MEV & Block Builders, Network Upgrades).",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "maintaining_organization": {
      "title": "Maintaining organization",
      "type": "string",
      "description": "The org or team that owns / maintains the entity."
    },
    "entity_type": {
      "title": "Entity type",
      "type": "string",
      "description": "What kind of thing this is. 'Protocol Specification (Normative)' is reserved for canonical, spec-level entries.",
      "examples": [
        "Protocol Specification (Normative)",
        "Consensus Client",
        "Execution Client",
        "Validator Operator",
        "Staking Provider",
        "Block Builder",
        "Relay",
        "Network Upgrade"
      ]
    },
    "supported_networks": {
      "title": "Supported networks",
      "type": "string",
      "description": "Semicolon-separated list of chains / networks this entity supports."
    },
    "license": {
      "title": "License",
      "type": "string",
      "description": "SPDX-like identifier for the entity's source license."
    },
    "production_status": {
      "title": "Production status",
      "type": "string",
      "description": "Maturity / deployment status. 'canonical' is reserved for authoritative specs.",
      "examples": [
        "canonical",
        "production-major",
        "production-stable",
        "production-limited",
        "experimental",
        "deprecated"
      ]
    },
    "reason_for_inclusion": {
      "title": "Reason for inclusion",
      "type": "string",
      "description": "Why this entity belongs in the Market Map."
    },
    "practitioner_note": {
      "title": "Practitioner note",
      "type": "string",
      "description": "Editorial commentary from the CanHav research team."
    },
    "practitioner_validation_check": {
      "title": "Practitioner validation check",
      "type": "string",
      "description": "Counter-factual / what-if-this-disappeared check, used to justify inclusion."
    }
  }
}
$json$::jsonb
 where slug = 'core-protocol-architecture';

-- ---------------------------------------------------------------------------
-- Consensus Layer — subsector_attributes schema
-- ---------------------------------------------------------------------------
update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/consensus-layer.json",
  "title": "Consensus Layer — subsector_attributes",
  "description": "Fields specific to the Consensus Layer subsector.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "client_implementation": {
      "title": "Client implementation",
      "type": "string",
      "description": "Kind of consensus implementation (e.g. 'Beacon Node + Validator Client' for clients, 'N/A (Specification)' for specs)."
    },
    "role_in_consensus": {
      "title": "Role in consensus",
      "type": "string",
      "description": "Semicolon-separated list of consensus duties this entity performs or defines."
    },
    "client_category": {
      "title": "Client category",
      "type": "string",
      "description": "High-level category (e.g. 'Full Consensus Client', 'Canonical Consensus Specification')."
    },
    "client_scope": {
      "title": "Client scope",
      "type": "string",
      "description": "Scope of operation."
    },
    "implementation_language": {
      "title": "Implementation language",
      "type": "string",
      "description": "Primary language. Lowercase string like 'rust', 'go', 'java', 'typescript', 'nim'."
    },
    "client_diversity_risk": {
      "title": "Client diversity risk",
      "type": "string",
      "description": "Risk this entity poses to Ethereum client diversity.",
      "examples": ["low", "medium", "high", "n/a"]
    },
    "client_diversity_risk_note": {
      "title": "Client diversity risk note",
      "type": "string",
      "description": "Editorial note on the diversity contribution."
    }
  }
}
$json$::jsonb
 where slug = 'consensus-layer';
