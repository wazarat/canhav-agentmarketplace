---
name: market-map/data-consensus-infrastructure
description: Background reference for the Data & Consensus Infrastructure sector. Auto-loads when the agent is working under .cursor/skills/market-map/sectors/data-consensus-infrastructure/. Not surfaced in /menu.
user-invocable: false
---

# Data & Consensus Infrastructure — Sector reference

## Sector-common fields (apply to every subsector)

Document each field that belongs in `sector_attributes` for projects in this sector. Things
that vary per subsector belong in the per-subsector reference doc.

| Field key | Type | Required | Description |
|-----------|------|----------|-------------|
| _example_field_ | string | no | _description_ |

Canonical JSON Schema: `schemas/sectors/data-consensus-infrastructure.json`.

## Subsectors in this sector

See `subsectors/` for the per-subsector field docs.

## Notes for ingest

- Sector-specific quirks, sheet-quality flags, anything that helps the next ingest run.
