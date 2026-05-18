---
name: market-map/advanced-compute-integration/real-world-assets
description: Background reference for the Real World Assets (RWAs) subsector. Auto-loads when the agent is working under .cursor/skills/market-map/sectors/advanced-compute-integration/. Not surfaced in /menu.
user-invocable: false
---

# Real World Assets (RWAs) — Subsector reference

Sheet: `1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU` tab `1894391559`

## Subsector-specific fields

Document each field that belongs in `subsector_attributes` for this subsector. Fields shared
across multiple subsectors of `advanced-compute-integration` belong in the sector SKILL.md instead.

| Field key | Type | Required | Description |
|-----------|------|----------|-------------|
| _example_field_ | string | no | _description_ |

The canonical JSON Schema this list maps to lives at `schemas/subsectors/real-world-assets.json`.

## Column map

`schemas/subsectors/real-world-assets.column_map.json` maps CSV column headers to either a
universal column or a key in `subsector_attributes`. Edit it whenever the source sheet's
columns change.

## Ingest notes

- Source sheet anomalies, columns to skip, manual fixups, etc.
