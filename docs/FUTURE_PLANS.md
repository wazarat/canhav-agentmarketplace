# Future plans

Polish, follow-ups, and out-of-milestone work. Items here are **not milestones** — they get picked up opportunistically or after all milestones (M0–M11) are done. Append newest on top. If an item graduates into milestone scope, move it into the README milestone table or a `.cursor/plans/*.plan.md`.

Each entry should answer:
- **Status** — deferred / on hold / waiting on _x_.
- **What is parked** — the rails (DB columns, scripts, docs, storage objects) we already shipped and want to preserve.
- **To re-enable** — a concrete recipe so future-you doesn't have to re-derive it.

---

## Consensus Layer — Tier-2 and Tier-3 fields

**Status.** Deferred. Tier-1 (universal columns + `client_diversity_role` + GitHub release/contributor signals + validator share estimate) shipped on 2026-05-20.

**Why deferred.** Tier-2 fields need manual curation per client (audit PDFs, post-mortem URLs, hardware-requirements digging, supported-features matrices). Tier-3 fields need a cron runner. The Market Map is in the sector-by-sector ingest phase; we'd rather finish Execution Layer (M8.6) and unlock the next 5 subsectors than spend a week curating per-client telemetry that is not yet visible in the UI.

**What is parked (do NOT remove without re-reading this entry).**

Schema:
- `.cursor/skills/market-map/schemas/subsectors/consensus-layer.json` is `additionalProperties: true`. Adding any of the fields below later is a JSON-update on `public.subsectors.specific_field_schema` for `slug='consensus-layer'`; no Postgres column migration required.
- Supabase mirror: `supabase/migrations/20260520_0001_consensus_layer_enrichment_schema.sql` carries the v2 schema. The next pass would be `20260???_0001_consensus_layer_tier2_schema.sql`.

Convention rails:
- `subsector_attributes.data_refreshed_at` / `data_confidence` are already in the schema. New telemetry fields should reuse these for freshness banding rather than inventing per-field timestamps.
- The `BASELINES` list in `.cursor/skills/market-map/scripts/enrich_consensus_layer.py` is the canonical "what do we know about each client" registry. Tier-2 hand-curated fields (e.g. `funding_dependency_on_ef`) should land there first, then graduate to JSONB via the same script.

**Tier 2 — Add when manual curation allows.**

| Field                          | Shape                                                      | Source                                                |
| ------------------------------ | ---------------------------------------------------------- | ----------------------------------------------------- |
| `audit_history`                | array of `{firm, date, url, scope}`                        | Audit PDFs (manual)                                   |
| `supported_features`           | array<enum>                                                | Project docs — `mev-boost`/`dvt`/`builder-api`/`snap-sync`/`checkpoint-sync`/`rest-api`/`engine-api-v3` |
| `min_hardware_requirements`    | `{ram_gb, disk_gb, cpu_cores, bandwidth_mbps}`             | Project docs                                          |
| `governance_model`             | enum `single-org`/`multi-org`/`foundation`/`dao`           | Manual                                                |
| `funding_dependency_on_ef`     | enum `none`/`partial`/`majority`/`sole`                    | EF grants page + project disclosures                  |
| `incident_history`             | array of `{date, severity, summary, postmortem_url}`       | Post-mortems (e.g. Prysm finality stall May 2023)     |

**Tier 3 — Operational telemetry (cron-driven).**

Requires a scheduled runner (Supabase Edge Function on cron, or GitHub Actions cron). Once that exists, the enrichment script gets a `--telemetry-only` flag.

| Field                            | Source                                  | Frequency |
| -------------------------------- | --------------------------------------- | --------- |
| `open_critical_issues`           | `gh api ... /issues?labels=critical&state=open` | Daily |
| `slashing_incidents_attributed`  | `beaconcha.in/api/v1/slashings`         | Daily     |
| `current_attestation_perf_pct`   | `rated.network` (per-client)            | Weekly    |
| `mainnet_uptime_30d_pct`         | `rated.network`                         | Weekly    |
| `validator_share_pct` (verified) | Working live source (see open question) | Weekly    |

**Open question (blocking Tier-3 validator share).**

`clientdiversity.org/api` does not exist (404). Until a working source is identified, `validator_share_pct` stays at `data_confidence='estimate'` per `docs/DECISIONS.md` 2026-05-20. Candidates to evaluate:
- Scrape the `clientdiversity.org` HTML dashboard (fragile; page is JS-rendered).
- `rated.network` (paid API).
- Migalabs (`migalabs.io`) — community dashboards, may expose JSON.
- `monitoreth.io` — community dashboard.

**To re-enable later.**

1. Extend the JSONB schema for `consensus-layer` with the Tier-2 keys you're filling. New migration: `20260???_0001_consensus_layer_tier2_schema.sql`, identical shape to the v2 migration.
2. Extend `BASELINES` in `enrich_consensus_layer.py` with the per-client hand-curated values (Tier 2 is per-client, so this is the natural home).
3. For Tier 3 (telemetry), write `scripts/refresh_consensus_telemetry.py` and stand up a daily/weekly schedule. Reuse `data_refreshed_at` + `data_confidence` for freshness banding.
4. UI: surface Tier-2 fields in the project-detail page first (one row per client gets a richer page), then add a Tier-3 ribbon ("Last release 14d ago · 18 contributors / 90d · validator share 33% (est.)").

---

## Project logos in the Market Map UI

**Status.** Deferred. Pipeline shipped 2026-05-19 (commit `95a18c5`). UI display reverted 2026-05-20 (the commit that introduced this doc).

**Why deferred.** Visible logos were drawing attention before the Market Map data is broad enough to earn it. We want the canvas clean until more sectors are populated, then re-introduce logos as a single polish pass.

**What is parked (do NOT remove without re-reading this entry).**
- Supabase Storage bucket `project-logos` (`supabase/migrations/20260519_0002_project_logos_storage_bucket.sql`) — public read, service-role write, RLS in place.
- 6 Consensus Layer logos already uploaded to that bucket and patched onto `projects.logo_url`: `ethereum-foundation.webp`, `prysmatic-labs.webp`, `sigma-prime.webp`, `consensys.webp`, `status.webp`, `chainsafe.webp`.
- `projects.logo_url` column on the schema (`supabase/migrations/20260518_0001_market_map_schema.sql`) — predates the logo work, lives in the universal-fields tier.
- `.cursor/skills/market-map/scripts/upload_logo.py` (single-project pipeline).
- `.cursor/skills/market-map/scripts/bulk_upload_logos.py` (folder-scan + match by maintaining-org slug).
- `.cursor/skills/market-map/LOGOS.md` (full convention: source formats, file naming, optimizer behavior, UI rules).
- `.cursor/skills/market-map/SKILL.md` cross-reference rows pointing at the two scripts and LOGOS.md.
- `backend/requirements.txt` → `Pillow==11.3.0` (dormant unless a script is invoked).
- `frontend/next.config.mjs` → `images.remotePatterns` allow-list for `*.supabase.co/storage/v1/object/public/**` (retained on purpose; marker comment in the file points back here).
- The universal JSON schema slot for `logo_url` and the Consensus Layer column-map entry mapping the sheet's `logo_url` column to the universal field.

**To re-enable later** (UI-only change, ~5 minutes once we're ready):
1. Restore `frontend/components/market-map/ProjectLogo.tsx` from commit `95a18c5`.
2. Re-add the three call sites in:
   - `frontend/components/market-map/ProjectTable.tsx` — small (28px) tile leading each row, inside the `Link`.
   - `frontend/components/market-map/CanonicalSpecCard.tsx` — medium (48px) tile next to the gradient title.
   - `frontend/app/market-map/project/[slug]/page.tsx` — large (80px) tile to the left of the H1 (the "Maintained by …" line under the title was kept in place when the logo was reverted).
3. Nothing else is needed: schema, RLS, bucket, scripts, Pillow, `remotePatterns`, and the 6 already-uploaded files are all still live.
4. For brand-new sectors, drop logos in `~/logos` and run `python .cursor/skills/market-map/scripts/bulk_upload_logos.py --dir ~/logos --subsector <slug>`.
