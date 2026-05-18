---
name: market-map/rollup-scaling-frameworks/l3-appchain-frameworks
description: Background reference for the L3 & Appchain Frameworks subsector. Auto-loads when the agent is working under .cursor/skills/market-map/sectors/rollup-scaling-frameworks/. Not surfaced in /menu.
user-invocable: false
---

# L3 & Appchain Frameworks — Subsector reference

Sheet: `1J08OAuQ5UW4HQfoOrInTxYnoKXWqppOCRBr-1PxaKLk` tab `698572346`

## Sheet quality notes (FLAGGED)

The source sheet has two known issues that other Rollup & Scaling tabs do not have:

1. **Wrapped column headers.** Almost every column from index 9 onwards (`Bespoke Engineering Required`, `Execution Environment Options`, ...) ends with a literal `\n` because the cell text wraps to a new line. The `normalize_row.py` script strips whitespace from headers before lookup, so the column map in `schemas/subsectors/l3-appchain-frameworks.column_map.json` can use the clean version (`"Bespoke Engineering Required"`, no `\n`). Confirmed by direct gviz CSV pull on 2026-05-18.

2. **Overlap with Optimistic Rollups.** The sheet explicitly notes entries like `"OP Stack (already used, but also belongs here contextually)"`. Decide on per-row policy before ingest: either skip the dupes here (preferred — Optimistic Rollups is the canonical home), or set a JSONB flag `also_in: ["optimistic-rollups"]` so the UI can render a cross-link.

3. **Low row count.** As of 2026-05-18 the sheet contains only ~7 rows. Confirm with the research team that the dataset is intentionally short before treating L3 ingest as complete.

## Subsector-specific fields (38 columns to triage)

The L3 sheet has the richest schema of any Rollup subsector. Most columns are unique to this subsector and belong in `subsector_attributes`. Candidates that should probably promote to `sector_attributes` (shared with Optimistic / ZK / Validium):

- `Type of Framework`
- `Underlying Rollup Base`
- `Execution Environment Options`
- `Sequencer Model Options`
- `Settlement Layer`
- `Security Inheritance`
- `Fault / Validity Proof Inheritance`
- `Native Interoperability Support`

Lock those down after seeing the other three Rollup sheets so we don't promote prematurely.

## Subsector-specific candidates (`subsector_attributes`)

These don't appear on the L1/L2 Rollup tabs and are L3-specific:

| Field key | Type | Description |
|-----------|------|-------------|
| `level_of_protocol_abstraction` | string | E.g. "framework", "RaaS", "infrastructure". |
| `bespoke_engineering_required` | string | Free text from the sheet. |
| `configurable_parameters` | string | Free text. |
| `upgrade_model` | string | "permissioned" / "permissionless" / hybrid. |
| `does_this_enable_l3s` | string | Yes/No/conditional. |
| `path_to_sovereignty` | string | Strategy for becoming a sovereign L1. |
| `operational_complexity` | string | Subjective rating from the sheet. |
| `fixed_vs_variable_costs` | string | Cost model. |
| `infrastructure_responsibility_split` | string | Who runs which piece. |
| `vendor_lock_in_risk` | string | Sheet's subjective rating. |
| `number_of_chains_deployed` | integer | If parseable. |
| `types_of_users` | string | Who actually deploys an L3 on this. |
| `ecosystem_alignment` | string | OP / Arbitrum / Polygon / Avalanche / multi. |
| `dependency_concentration_risk` | string | Sheet's subjective rating. |
| `composability_with_base_rollup` | string | How L3s talk to the underlying L2. |
| `cross_rollup_messaging_assumptions` | string | Trust model for cross-rollup messages. |
| `external_bridge_dependency` | string | Required external bridges. |
| `also_in` | array of strings | Other subsector slugs this entity belongs to (e.g. `["optimistic-rollups"]`). |

Canonical JSON Schema: `schemas/subsectors/l3-appchain-frameworks.json`.

## Column map

`schemas/subsectors/l3-appchain-frameworks.column_map.json` maps the clean (whitespace-stripped) headers to the field buckets above. Re-run `ingest_subsector.py --slug l3-appchain-frameworks --dry-run` after every edit until the diff looks right.

## Ingest order recommendation

Do L3 **last** among the Rollup subsectors so the sector-common field list is already settled by then. Optimistic Rollups → ZK Rollups → Validiums → L3.
