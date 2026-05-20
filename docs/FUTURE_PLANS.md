# Future plans

Polish, follow-ups, and out-of-milestone work. Items here are **not milestones** — they get picked up opportunistically or after all milestones (M0–M11) are done. Append newest on top. If an item graduates into milestone scope, move it into the README milestone table or a `.cursor/plans/*.plan.md`.

Each entry should answer:
- **Status** — deferred / on hold / waiting on _x_.
- **What is parked** — the rails (DB columns, scripts, docs, storage objects) we already shipped and want to preserve.
- **To re-enable** — a concrete recipe so future-you doesn't have to re-derive it.

---

## MEV & Block Builders — Tier-2 / Tier-3 fields + mevboost.pics / relayscan.io integration

**Status.** Deferred. Tier-1 (16 rows ingested + enriched, 6 new orgs, both dual-enum splits applied, validator coverage curated baselines) shipped on 2026-05-20.

**Why deferred.** Tier-2 fields need a live mevboost.pics / relayscan.io integration (`validator_coverage_pct` is currently a curated baseline tagged `data_confidence='estimate'`; flipping to `verified` and refreshing weekly requires the cron runner). Tier-3 needs additional per-entity observability (per-builder `builder_pubkey` from on-chain block headers; `ofac_filtering_pct` from relay-level analysis). The "Lido relay allow-list" cross-subsector governance signal is the single most-valuable derived metric and is blocked on the same cron-runner work.

**What is parked.**

Schema:
- `.cursor/skills/market-map/schemas/subsectors/mev-block-builders.json` is `additionalProperties: true`. Adding any field below later is a JSON-update on `public.subsectors.specific_field_schema` for `slug='mev-block-builders'`; no Postgres column migration required.
- Supabase mirror: `supabase/migrations/20260520_0005_mev_block_builders_schema.sql` carries the Tier-1 shape. The next pass would be `20260???_0001_mev_block_builders_tier2_schema.sql`.

Convention rails (already in the schema):
- `subsector_attributes.data_refreshed_at` / `data_confidence`.
- `subsector_attributes.censorship_policy` × `censorship_policy_layer` (dual-enum) — already shipped.
- `subsector_attributes.infrastructure_topology` × `infrastructure_advantage_source` (dual-enum) — already shipped.
- `subsector_attributes.validator_coverage_pct` (curated baseline) + `validator_coverage_band` (enum) — coexist; the band is the chart-friendly axis when the precise % is stale.

**Tier 2 — Add when manual curation or simple live sources allow.**

| Field                              | Shape                                                      | Source                                                |
| ---------------------------------- | ---------------------------------------------------------- | ----------------------------------------------------- |
| `policy_last_changed_date`         | date                                                       | Manual (Flashbots blog, bloXroute blog)                |
| `policy_history`                   | array of `{date, policy, layer, summary}`                  | Manual                                                |
| `relay_endpoint_verified`          | boolean                                                    | Periodic ping of `mev_boost_relay_endpoint`            |
| `ofac_filtering_pct`               | numeric (relay rows only)                                  | mevboost.pics live API                                 |
| `non_filtering_relay`              | boolean (relay rows only)                                  | Derived from `censorship_policy='neutral'`             |
| `builder_pubkey`                   | string (builder rows only)                                 | Observable on-chain                                    |
| `builder_market_share_30d_pct`     | numeric (builder rows only)                                | mevboost.pics live API                                 |
| `relay_subscriber_validator_pct`   | numeric (relay rows only)                                  | mevboost.pics / relayscan.io                           |

**Tier 3 — Operational telemetry (cron-driven).**

| Field                              | Refresh        | Source                                                |
| ---------------------------------- | -------------- | ----------------------------------------------------- |
| `validator_coverage_pct`           | Weekly         | mevboost.pics live API (replaces curated baseline)    |
| `missed_slot_rate_30d_pct`         | Weekly         | relayscan.io                                          |
| `bundle_inclusion_rate_30d_pct`    | Weekly         | libmev.com                                            |
| `last_significant_incident`        | On publish     | Operator post-mortems + Twitter/X                     |

**Composite metrics (computed view, not stored):**
- `composite_concentration_score` = weighted (`validator_coverage_pct` × `vertical_integration_flag` × `single_point_of_failure_risk`). Useful as the headline chart for the subsector landing page.

**The Lido relay allow-list signal.** When `validator_coverage_pct` is wired, the most-watched cross-subsector signal becomes the diff between Lido's relay allow-list and the broader validator population. Lido currently routes through ~5-6 relays; a single allow-list change can shift 25%+ of total MEV-Boost share. Future cross-subsector view: query `projects.subsector_attributes->'lido_allowlist'` on the Lido validator row (set when the Lido governance vote lands) joined against MEV relay rows.

**To re-enable.**
1. Wire `https://mevboost.pics/api` (or scrape the dashboard JSON) into `scripts/refresh_mev_telemetry.py`. Map each relay/builder name → `projects.slug` (manual mapping table for the first cut).
2. Promote `validator_coverage_pct` from `data_confidence='estimate'` to `verified` for the touched rows.
3. Author `enrich_mev_tier2.py` per the script-per-tier convention (or fold into the generic `enrich_clients.py` if subsector #4 motivates extracting it).
4. Stand up a weekly cron (Supabase Edge Function or GitHub Actions) to call the refresh script.

---

## Organizations table — UI cutover + drop duplicated universal fields from `projects`

**Status.** Deferred. The `public.organizations` table shipped on 2026-05-20 (migration `20260520_0003`) and is the new source of truth for org-level universal fields. The duplicated columns on `public.projects` (`founded_year`, `hq_country`, `team_size_range`, `twitter_handle`, `total_funding_usd`, `last_funding_round`, `last_funding_date`, `stage`) are still in place, and so is the legacy `sector_attributes.maintaining_organization` JSONB key. This is intentional — dropping them now would require simultaneously cutting the frontend over to read from the org row via a join.

**What is parked.**
- The org table itself is fully populated for the 18 orgs in flight across consensus-layer, execution-layer, and validators-staking-providers.
- `public.projects.maintaining_organization` is a typed FK to `organizations.slug` and is set for every non-aggregate row.
- The legacy `sector_attributes.maintaining_organization` free-text JSONB key still sits on rows ingested before M8.7. It is no longer the source of truth, but it's not actively misleading either — the typed column always agrees with or supersedes it.

**To re-enable.**
1. Update the Next.js frontend (`frontend/src/app/market-map/...`) to load org data via a join: `select p.*, o.* from projects p left join organizations o on o.slug = p.maintaining_organization`.
2. Replace any UI code that reads `p.hq_country`, `p.founded_year`, etc. with `o.hq_country`, `o.founded_year`, etc. Same for `twitter_handle`, `total_funding_usd`, `last_funding_round`, `last_funding_date`, `stage`, `team_size_range`.
3. Ship a migration `20260???_0001_drop_duplicated_universal_columns_on_projects.sql` that DROPs the now-redundant columns from `projects`. Include a sanity-check `select` in a transaction that verifies every project has either `maintaining_organization is not null` (FK works) or `is_aggregate = true` before the drop.
4. Ship a follow-up `20260???_0002_drop_legacy_maintaining_organization_jsonb.sql` that strips the `sector_attributes->>'maintaining_organization'` key from every row.

**Open question.** Some universal fields (especially `stage` for exchange validator-ops rows like `coinbase-validator-operations`) might want a *per-subsector* override even after the org row exists. E.g. Coinbase's parent stage is `public` but the staking-business-unit stage might want to be `n/a`. Decide whether subsector overrides live in `subsector_attributes` or as a per-row override column on `projects`.

---

## Validators & Staking Providers — Tier-2 and Tier-3 fields + rated.network integration

**Status.** Deferred. Tier-1 (operator archetype, validator share %, dual-enum, ingest of all 4 archetypes including the aggregate handling) shipped on 2026-05-20.

**Why deferred.** Tier-2 fields need operator transparency reports (`infra_provider_mix`, `geographic_distribution`, `dvt_adoption_status`, `ofac_filtering_policy`, `key_management_model` as enum, `soc2_status`, `insurance_coverage_usd`, `protocol_fee_pct`, `liquid_token_address`, `operator_count_in_set`, `permissionless`). Tier-3 needs a cron runner (`effective_apr_30d_pct`, `attestation_perf_30d_pct`, `missed_attestations_30d`, `slashing_events_lifetime`, `proposer_eff_30d_pct`, `withdrawal_queue_position`, `last_significant_incident`). Both require a wired `rated.network` API integration; the `validator_share_pct` we ship today is a curated baseline tagged `data_confidence='estimate'`.

**What is parked.**

Schema:
- `.cursor/skills/market-map/schemas/subsectors/validators-staking-providers.json` is `additionalProperties: true`. Adding any field below later is a JSON-update on `public.subsectors.specific_field_schema` for `slug='validators-staking-providers'`; no Postgres column migration required.
- Supabase mirror: `supabase/migrations/20260520_0004_validators_staking_providers_schema.sql` carries the v1 (Tier-1) shape. The next pass would be `20260???_0001_validators_tier2_schema.sql`.

Convention rails (already in the schema):
- `subsector_attributes.data_refreshed_at` / `data_confidence`.
- `subsector_attributes.client_diversity_risk` × `client_diversity_role` (dual-enum) — already shipped.

**Tier 2 — Add when manual curation allows.**

| Field                          | Shape                                                      | Source                                                |
| ------------------------------ | ---------------------------------------------------------- | ----------------------------------------------------- |
| `dvt_adoption_status`          | enum: `none | testnet | partial-mainnet | mainnet`         | Operator announcements                                |
| `ofac_filtering_policy`        | enum: `filtering | non-filtering | selective | undisclosed` | Operator policy page                                  |
| `geographic_distribution`      | array of `{country, pct}`                                  | Operator transparency reports                         |
| `infra_provider_mix`           | array of `{provider, pct}`                                 | Operator transparency + monitoreth.io                 |
| `key_management_model` (enum)  | `custodian-controlled | client-controlled | dvt-distributed | user-controlled | hsm-backed` | Self-disclosed                                        |
| `soc2_status`                  | enum: `none | type-1 | type-2 | type-2-renewed`            | Operator disclosure                                   |
| `insurance_coverage_usd`       | numeric                                                    | Operator disclosure                                   |
| `protocol_fee_pct`             | numeric (LST only)                                         | Protocol docs                                         |
| `liquid_token_address`         | string (Ethereum address, LST only)                        | Etherscan / DefiLlama                                 |
| `operator_count_in_set`        | int (LST only)                                             | Protocol docs / on-chain                              |
| `permissionless`               | boolean (LST only)                                         | Protocol docs                                         |
| `composite_risk_score`         | computed 0–100                                             | Derived from all Tier-2 inputs                        |

**Tier 3 — Operational telemetry (cron-driven).**

| Field                          | Refresh        | Source                                                |
| ------------------------------ | -------------- | ----------------------------------------------------- |
| `validator_count`              | Weekly         | rated.network or beaconcha.in                         |
| `effective_apr_30d_pct`        | Weekly         | rated.network                                         |
| `attestation_perf_30d_pct`     | Weekly         | rated.network                                         |
| `proposer_eff_30d_pct`         | Weekly         | rated.network                                         |
| `missed_attestations_30d`      | Weekly         | beaconcha.in                                          |
| `slashing_events_lifetime`     | Daily          | beaconcha.in/api/v1/slashings                         |
| `withdrawal_queue_position`    | Daily          | beaconcha.in/api/v1/validator/queue                   |
| `last_significant_incident`    | On publish     | Operator post-mortems                                 |

**Lido 33% line.** Once `validator_share_pct` is wired to rated.network, surface Lido's share as a featured metric on the subsector landing page, recomputed weekly. This is the single most-watched number in the subsector.

**To re-enable.**
1. Wire rated.network: `https://api.rated.network/v0/eth/operators`. Map operator name → `projects.slug` (manual mapping table for the first cut).
2. Promote `validator_share_pct` from `data_confidence='estimate'` to `verified` once Tier-1 telemetry lands.
3. Author `enrich_validators_tier2.py` per the script-per-tier convention.

---

## Execution Layer — Reth seeding + Tier-2 and Tier-3 fields

**Status.** Deferred. Tier-1 (universal columns + `funding_model` + `client_diversity_role` + GitHub release/contributor signals + execution-share estimate) shipped on 2026-05-20.

**Why deferred.** Reth is not in the source Google Sheet and the per-entity production-readiness call needs explicit user sign-off. Tier-2 fields need manual curation per client (audit PDFs, EIP-implementation lag, archive disk numbers, supported features matrices, engine API version). Tier-3 needs the same cron runner the Consensus Layer entry talks about.

**What is parked (do NOT remove without re-reading this entry).**

Schema:
- `.cursor/skills/market-map/schemas/subsectors/execution-layer.json` is `additionalProperties: true`. Adding any field below later is a JSON-update on `public.subsectors.specific_field_schema` for `slug='execution-layer'`; no Postgres column migration required.
- Supabase mirror: `supabase/migrations/20260520_0002_execution_layer_enrichment_schema.sql` carries the v1 (Tier-1) schema. The next pass would be `20260???_0001_execution_layer_tier2_schema.sql`.

Convention rails:
- `subsector_attributes.data_refreshed_at` / `data_confidence` are already in the schema. New telemetry fields should reuse these.
- The `BASELINES` list in `.cursor/skills/market-map/scripts/enrich_execution_layer.py` is the canonical "what do we know about each client" registry. Tier-2 hand-curated fields land there first.

**Reth — explicit decision still owed.**

The Perplexity-drafted `execution-layer.data-sources.md` and `execution-layer.fields-to-add.md` both recommend adding a Reth row even at `production-limited`. The narrative file explicitly defers it. User instruction at M8.6 ingest was to skip. Re-evaluate on the next sheet refresh (or sooner if a working live execution-share source covers it). When added, target shape:

- `entity_type=client_implementation`, `production_status=production-limited`.
- `implementation_language='rust'`, `funding_model='venture'` (Paradigm-backed via Reth's `Paradigm-XYZ` grant cadence — verify), `client_diversity_role='architectural-diversity'`, `client_diversity_risk='low'`.
- `team_size_range='5-20'`, `hq_country='United States'`, `twitter_handle='paradigm'` (proxy until Reth has its own), `last_funding_round=null`.
- License: `apache-2.0` or `mit` — verify against the actual LICENSE file before write.

**Tier 2 — Add when manual curation allows.**

| Field                          | Shape                                                      | Source                                                |
| ------------------------------ | ---------------------------------------------------------- | ----------------------------------------------------- |
| `audit_history`                | array of `{firm, date, url, scope}`                        | Audit PDFs (manual)                                   |
| `supported_features`           | array<enum>                                                | Project docs — `engine-api-v3`/`snap-sync`/`full-sync`/`archive-mode`/`trace-api`/`debug-api` |
| `min_hardware_requirements`    | `{ram_gb, disk_gb, cpu_cores, bandwidth_mbps}`             | Project docs                                          |
| `default_sync_mode`            | enum `snap`/`full`/`beam`/`erigon-staged`                  | Project docs                                          |
| `archive_node_disk_gb`         | integer                                                    | Practitioner data (Geth ~12TB+, Erigon ~2.5TB)        |
| `governance_model`             | enum `foundation-internal`/`single-org`/`dao`/`community-multi-org` | Manual                                       |
| `funding_dependency_on_ef`     | enum `none`/`partial`/`majority`/`sole`                    | EF grants page + project disclosures                  |
| `incident_history`             | array of `{date, severity, summary, postmortem_url}`       | EF post-mortems (Geth Hades 2020, Geth fork 2021, Nethermind sync 2022) |
| `eip_implementation_lag_days`  | numeric                                                    | Historical fork timing data                           |
| `engine_api_version_supported` | string                                                     | Project docs (e.g. `v3` for post-Cancun)              |

**Tier 3 — Operational telemetry (cron-driven).**

| Field                          | Source                                  | Frequency |
| ------------------------------ | --------------------------------------- | --------- |
| `open_critical_issues`         | `gh api ... /issues?labels=critical&state=open` | Daily |
| `mainnet_sync_status_30d_pct`  | `ethernodes.org`                        | Weekly    |
| `historical_fork_compliance_pct` | Manual + post-mortems                 | On fork   |
| `execution_share_pct` (verified) | Working live source (see open question) | Weekly  |

**Open question (blocking Tier-3 share verification).** Same as Consensus Layer — `clientdiversity.org/api` does not exist. Candidates: scrape `clientdiversity.org` HTML dashboard, scrape `ethernodes.org`, or pay for `rated.network`. Tracked in the Consensus Layer entry below.

**To re-enable later.**

1. Extend the JSONB schema for `execution-layer` with the Tier-2 keys you're filling. New migration: `20260???_0001_execution_layer_tier2_schema.sql`, identical shape to the v1 migration.
2. Extend `BASELINES` in `enrich_execution_layer.py` with the per-client hand-curated values.
3. For Reth: add a sixth `ClientBaseline` entry and a curated `client_diversity_risk_note` value matching `Minority Implementation (Performance & Architecture Diversity)` (or a new phrase if it warrants).
4. For Tier 3 telemetry, write `scripts/refresh_execution_telemetry.py` and stand up a daily/weekly schedule. Reuse `data_refreshed_at` + `data_confidence` for freshness banding.

---

## Execution Layer — EIP-tracking parallel table

**Status.** Deferred. Proposed in `.cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/execution-layer.fields-to-add.md`.

**Why deferred.** This is genuinely a new top-level entity, not a JSONB key. The `Execution EIPs` row is not one document — it's a *process* that yields hundreds of individual EIPs (EIP-1559, EIP-3675, EIP-4844, EIP-7702, ...). Each EIP has its own status, fork activation, and per-client implementation lag. Modeling them as JSONB array entries on the spec row would collapse what should be a queryable graph.

The schema cross-cuts subsectors — an EIP links to one or more **Execution Clients** (`affected_clients`) and to a **Network Upgrade** (`activated_in_fork`). That second relationship requires the Network Upgrades subsector to be ingested first.

**What is parked.**

Proposed `public.protocol_changes` table (sketch — implement after Network Upgrades ships):

| Column                       | Type                       | Notes                                                                |
| ---------------------------- | -------------------------- | -------------------------------------------------------------------- |
| `id`                         | uuid                       | PK                                                                   |
| `eip_number`                 | integer                    | E.g. `1559`, `4844`, `7702`                                          |
| `title`                      | text                       | From `eips.ethereum.org`                                              |
| `eip_status`                 | text (enum)                | `draft`/`review`/`last-call`/`final`/`stagnant`/`withdrawn`/`living` |
| `activated_in_fork_slug`     | text (FK → projects.slug)  | Links to the Network Upgrades row for the fork (`london`, `dencun`)  |
| `affected_client_slugs`      | text[] (FK array)          | Links back to which execution clients shipped support                |
| `gas_cost_change`            | boolean                    | Did this EIP change opcode-level gas?                                |
| `opcode_change`              | boolean                    | Did this EIP add/remove/change EVM opcodes?                          |
| `created_at` / `updated_at`  | timestamptz                |                                                                       |

Ingest source: `https://eips.ethereum.org/eip/<n>.json` (machine-readable per EIP) + the `ethereum/EIPs` GitHub repo for status history.

**To re-enable later.**

1. Ship Network Upgrades (M8.x) first so the FK target exists.
2. New migration: `20260???_0001_protocol_changes_table.sql` — `create table public.protocol_changes (...)` with RLS (anon SELECT only).
3. New ingest script: `.cursor/skills/market-map/scripts/ingest_eips.py` — pulls all execution EIPs from `eips.ethereum.org` + the GitHub repo, computes `activated_in_fork_slug` and `affected_client_slugs`.
4. Frontend: a new `/market-map/eips` route + EIP-detail pages, plus a "Recent EIPs" ribbon on the Execution Layer subsector page.

---

## Generalize `enrich_<subsector>.py` → `enrich_clients.py` (post-M8.8 status)

**Status.** Partially landed. **Deferred completion until subsector #4 (M8.9).**

**What landed at M8.8 (2026-05-20).** The genuinely shared mechanics across the 4 enrichment scripts — `OrgBaseline` dataclass + the three Supabase REST helpers (`upsert_organization`, `fetch_existing_project`, `patch_project`) + a string-normalization helper (`norm`) — were extracted into `.cursor/skills/market-map/scripts/_enrichment.py`. `enrich_validators_staking_providers.py` and `enrich_mev_block_builders.py` import from it; the older `enrich_consensus_layer.py` and `enrich_execution_layer.py` were left untouched in this pass because their GitHub-telemetry helpers are not yet shared by any other script. See `docs/DECISIONS.md` 2026-05-20 (`_enrichment.py` extraction rationale) for the full reasoning.

**Why still deferred.** Two scripts now use the org-FK shape (Validators, MEV); two use the GitHub-telemetry shape (Consensus, Execution). It's still ambiguous whether the GitHub helpers should fold into `_enrichment.py` or live elsewhere — folding them now would push dead code onto Validators/MEV. The fourth subsector to use either shape is what will resolve the ambiguity.

**What is parked.**

- `.cursor/skills/market-map/scripts/enrich_consensus_layer.py` — 431-line script with `BASELINES` for the 5 consensus clients. Still inline-defines its GitHub helpers + Supabase PATCH helper.
- `.cursor/skills/market-map/scripts/enrich_execution_layer.py` — near-twin, ~360 lines, `BASELINES` for the 4 execution clients + `DIVERSITY_MAP`. Still inline-defines its GitHub helpers.
- `.cursor/skills/market-map/scripts/_enrichment.py` — already has the org-FK + normalization helpers shared by Validators + MEV.
- Shared shape (Consensus + Execution): `ClientBaseline` dataclass + GitHub helpers (`gh_get`, `fetch_repo_created_year`, `fetch_latest_release`, `fetch_contributors_last_90d`).

**To re-enable later (after subsector #4 ships).**

1. Audit how subsector #4 fits — does it use the org-FK shape (Validators/MEV cluster) or the GitHub-telemetry shape (Consensus/Execution cluster) or something new?
2. If it uses GitHub telemetry, fold `gh_get` / `fetch_repo_created_year` / `fetch_latest_release` / `fetch_contributors_last_90d` into `_enrichment.py` (with a clear "Optional[github]" param surface so org-FK-only scripts don't carry the import).
3. Create `enrich_clients.py` with CLI `--subsector <slug>` that loads `from baselines.<slug> import BASELINES, DIVERSITY_MAP, SHARE_PCT_FIELD_NAME` (or the orgs-only equivalent).
4. Create `.cursor/skills/market-map/scripts/baselines/{consensus_layer,execution_layer,validators_staking_providers,mev_block_builders}.py` modules. Each exposes its registry + per-subsector helpers.
5. Replace the four per-subsector scripts with two-line wrappers that import and dispatch.

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
