---
name: market-map
description: How to extend the CanHav Market Map. Read whenever you're adding a sector, adding a subsector, ingesting new projects from the source Google Sheets, evolving the 3-tier schema (universal / sector-common / subsector-specific), or touching anything under /market-map. Composes with the per-sector and per-subsector skills under sectors/.
user-invocable: true
---

# CanHav Market Map — Builder's Guide

This skill is the entry point for anyone (human or agent) extending the Market Map. It is the place where the *judgment* of how to design fields lives. The *mechanical* parts (fetching sheets, upserting rows, validating JSON) are in `scripts/` and have zero token cost — invoke them as commands, never re-implement them inline.

## 1. The 3-tier data model

Every project row has three layers of fields.

```
projects                                              examples
├── Universal columns (typed Postgres columns)        name, slug, website_url, description, status,
│                                                     stage, founded_year, total_funding_usd, ...
├── sector_attributes  jsonb                          consensus_mechanism, chain_layer (L1/L2/L3),
│                                                     client_implementations, ...
│                                                     (shape lives in sectors.common_field_schema)
└── subsector_attributes jsonb                        finality_time_ms, validator_count (for consensus),
                                                      bundle_market, relay_type (for mev), ...
                                                      (shape lives in subsectors.specific_field_schema)
```

When a JSONB key has stabilized across **3 or more sectors**, promote it to a typed universal column in a new SQL migration. Don't promote earlier — premature columns force migration churn.

## 2. When to use which tool

| You want to...                                                       | Use                                                  |
| -------------------------------------------------------------------- | ---------------------------------------------------- |
| Add a new sector + all its subsectors                                | [`scripts/add_sector.py`](scripts/add_sector.py)     |
| Add one new subsector to an existing sector                          | [`scripts/add_subsector.py`](scripts/add_subsector.py)|
| Pull one tab from a Google Sheet as CSV                              | [`scripts/fetch_sheet.py`](scripts/fetch_sheet.py)   |
| Validate a row against the sector / subsector JSON schemas           | [`scripts/validate_schema.py`](scripts/validate_schema.py) |
| Push validated rows into Supabase                                    | [`scripts/upsert_projects.py`](scripts/upsert_projects.py) |
| Run the full ingest loop for one subsector                           | [`scripts/ingest_subsector.py`](scripts/ingest_subsector.py) |
| Upload one project logo                                              | [`scripts/upload_logo.py`](scripts/upload_logo.py) — see [LOGOS.md](LOGOS.md) |
| Upload a whole folder of org logos                                   | [`scripts/bulk_upload_logos.py`](scripts/bulk_upload_logos.py) — see [LOGOS.md](LOGOS.md) |

All scripts read config from environment variables. Required:

```bash
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # service_role JWT, NEVER ship to the frontend
```

## 3. Audit framework compliance

This folder was designed against the audit framework in `docs/CHANGELOG_DEV.md` (M8 entry). The rules:

### Visibility
- **`disable-model-invocation: true`** on any SKILL/subskill that wraps a side-effecting script (`add_sector`, `add_subsector`, `upsert_projects`, `ingest_subsector`). The agent must not auto-fire these — they hit the database. The user invokes them explicitly.
- **`user-invocable: false`** on per-sector and per-subsector reference docs (pure background knowledge — "what does `consensus_mechanism` mean for the Consensus Layer subsector"). They auto-load when the agent works in this repo but don't clutter `/menu`.
- This entry skill stays user-invocable so you can pull it up on demand.

### Deterministic vs non-deterministic
- **Scripts (deterministic, zero tokens):** URL building, CSV parsing, column renaming, JSON-schema validation, Supabase upserts, template scaffolding. Same inputs → same outputs forever.
- **AI (judgment):** Deciding which sheet column belongs in `universal` vs `sector_attributes` vs `subsector_attributes`. Writing a sector's description. Choosing when to promote a JSONB key to a typed column. Resolving the L3 & Appchain Frameworks sheet anomalies.

The skill markdown explains *how* to make those judgments, then hands off to a script for the mechanical work.

### Composability
- `fetch_sheet.py`, `normalize_row.py`, `validate_schema.py`, `upsert_projects.py` are shared across every sector/subsector. Never re-implement them in a sector folder.
- Sector skills reference the universal field list at `schemas/universal.json` — they don't repeat it.
- `add_subsector.py` is a thin wrapper around the same template engine as `add_sector.py`.

If you find yourself copy-pasting logic between sector folders: stop, lift it to `scripts/`.

## 4. The sector loop (M8.5+)

Per the M8 plan in `.cursor/plans/`:

```
1. Pick the next sector (in plan order: Core Protocol Architecture first, Governance last).
2. Skim every source sheet for that sector. Note shared columns vs unique columns.
3. Sketch the sector_common field schema and per-subsector specific field schemas.
4. Run: python scripts/add_sector.py --slug <sector-slug>
   This creates the sector folder, stubs the subsector reference docs, and writes blank
   JSON schema files. (The DB rows are already seeded — this only scaffolds skill files.)
5. Edit sectors/<slug>/SKILL.md to document sector-common conventions.
6. Edit schemas/sectors/<slug>.json with the actual JSON Schema for sector_attributes.
7. Edit each schemas/subsectors/<subsector>.json with the subsector-specific schema.
8. For each subsector:
   python scripts/ingest_subsector.py --slug <subsector-slug> --dry-run
   # review the diff, then drop --dry-run to commit to Supabase.
9. Visit /market-map/<sector>/<subsector> locally; spot-check fields.
10. If a JSONB key now appears in 3+ sectors, file a follow-up migration to promote it.
11. Commit, push, deploy. Update docs/CHANGELOG_DEV.md.
```

## 5. Field naming conventions

- `snake_case` for every JSONB key and SQL column.
- `*_url` for URL fields. `*_handle` for plain usernames. `*_at` for timestamps. `*_date` for dates.
- `*_usd` for currency in USD; never bake currency into a key name.
- Enum-like values are lowercase strings: `"live" | "testnet" | "mainnet" | "archived" | "unknown"`.
- Free-form numeric ranges like team size are strings: `"1-10"`, `"11-50"`, `"51-200"`, `"201-500"`, `"500+"`.

## 6. Where to look next

- Per-sector conventions: `sectors/<sector-slug>/SKILL.md`
- Per-subsector field definitions: `sectors/<sector-slug>/subsectors/<subsector-slug>.md`
- JSON Schemas the API and validator actually use: `schemas/`
- The plan that scoped M8: `.cursor/plans/m8_market_map_sector_by_sector_*.plan.md`
- Live API + frontend code: `backend/app/routes/market_map.py` and `frontend/app/market-map/`
