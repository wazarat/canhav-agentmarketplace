# Architectural Decisions

> Append-only log of decisions that shape this codebase. **Do not re-litigate** without explicit user approval. If you must deviate, add a new entry that supersedes the old one and links back to it.
>
> Format: `## YYYY-MM-DD — <decision>` followed by **Context · Decision · Consequences · Alternatives considered**.

---

## 2026-05-20 — Extract `_enrichment.py` (org-FK helpers only); defer full `enrich_clients.py` generalization to subsector #4

**Context.** M8.8 (MEV & Block Builders) is the third subsector to ship a Tier-1 enrichment script. M8.5 (Consensus) and M8.6 (Execution) share a GitHub-telemetry shape (`founded_year` / `latest_release_*` / `contributors_last_90d` from the GitHub REST API). M8.7 (Validators) and M8.8 (MEV) share a fundamentally different shape: no GitHub telemetry, but heavy use of the `public.organizations` upsert-by-slug pattern plus per-baseline dual-enum splits. The user asked at M8.8 kickoff to evaluate generalizing the four scripts into a single `enrich_clients.py --subsector <slug>` before writing the MEV one.

After looking at the four scripts side-by-side, the cleanest extraction is *not* the full `enrich_clients.py`. The GitHub helpers (Consensus + Execution) and the org-FK helpers (Validators + MEV) are two distinct cluster shapes; folding them together would force a confusing union type. The genuinely shared mechanics across **all four** is narrower: the `OrgBaseline` dataclass + the three Supabase REST helpers (`upsert_organization`, `fetch_existing_project`, `patch_project`) + a small string-normalization helper (`norm`). Validators uses all four; MEV uses all four; Consensus + Execution don't use the org-upsert helper (their orgs were backfilled inline in the M8.7 migration) but use the project-PATCH helper.

**Decision.** Extract exactly this shared surface into `.cursor/skills/market-map/scripts/_enrichment.py` as part of M8.8. Refactor `enrich_validators_staking_providers.py` to import from it (light touch — pure deletion, no logic change). Write `enrich_mev_block_builders.py` from scratch using the new module. Leave `enrich_consensus_layer.py` + `enrich_execution_layer.py` untouched in this pass — their GitHub helpers are valuable enough on their own to stay in-script for now, and rewriting them mid-M8 would risk telemetry drift.

The full `enrich_clients.py` generalization (the one described in `docs/FUTURE_PLANS.md`) is deliberately deferred to **subsector #4** (whichever is next after MEV). The fourth instance is what will tell us whether the GitHub-telemetry shape genuinely belongs in the generic loop or is permanently Consensus/Execution-only.

**Consequences.**
- `_enrichment.py` is ~150 lines of focused helpers with no top-level side effects. Importing is cheap. Each per-subsector script keeps its own BASELINES, normalization tables, dual-enum maps, and `build_payload`.
- The validators refactor deleted ~80 lines of duplicated code without changing observed behavior (verified via `--dry-run` parity check before and after).
- The decision rule is now codified in code: anything shared by ≥2 enrichment scripts that does NOT depend on subsector-specific schema goes in `_enrichment.py`. Anything subsector-specific stays in the per-subsector script.
- `OrgBaseline` is now a single canonical dataclass. Future enrichment scripts that need an org reference type-annotated their imports cleanly.

**Alternatives considered.**
- *Ship the full `enrich_clients.py` now.* Rejected — the GitHub-telemetry shape and the org-FK shape are genuinely different. Forcing them under one CLI would either re-introduce per-subsector if/else branches in `main()` (the kind of code we're trying to avoid) or push the GitHub helpers into the generic path, where they'd be dead code for Validators/MEV/all future non-client subsectors.
- *Don't extract anything; copy-paste between Validators and MEV.* Rejected — that's the path that ends with five copies of `upsert_organization` and a subtle drift bug in one of them.
- *Wait until subsector #4 to extract anything.* Rejected — the org-FK plumbing is genuinely the same code in both scripts already, and the `_enrichment.py` extraction is mechanical. Deferring it makes both scripts harder to read.

**When to revisit.** When subsector #4 ships (M8.9). If it also uses the org-FK shape, the abstraction is correct. If it uses GitHub telemetry like Consensus/Execution, fold their helpers into `_enrichment.py` and write the generic `enrich_clients.py` then.

---

## 2026-05-20 — Apply dual-enum splits at enrichment time (NOT at ingest); curate per-entity for nuanced subsectors like MEV

**Context.** MEV & Block Builders has two source-sheet cells that collapse two axes each: `Censorship or Filtering Policies` (what + where) and `Infrastructure Control` (shape + moat source). The v6 doc proposed splitting them at import. The Validators dual-enum (`client_diversity_risk` × `client_diversity_role`) is split by a generic phrase-to-pair mapping table because the source phrases are stable; MEV's phrases are more nuanced and would not map cleanly through a generic table (e.g. Flashbots Relay's `evolving` policy needs `relay-enforced` layer, but the bloXroute relay's `configurable` policy needs `relay-enforced` for a *different* reason — it's a multi-flavor relay, not a policy reversal).

**Decision.** Apply both MEV dual-enum splits in `enrich_mev_block_builders.py`, at enrichment time, with per-baseline curated values rather than via a generic mapping table. The verbatim sheet cell is preserved under a `*_source` key (`censorship_policy_source`, `infrastructure_control_source`) so the curator can audit the mapping later. Same script handles the third "mini-split": `vertical_integration_raw` → `vertical_integration_flag` (typed boolean) + `vertical_integration_note` (free text).

For Validators (M8.7), the existing phrase-to-pair `DIVERSITY_MAP` is the right shape because the 9 source phrases are stable across years and operators. For MEV, the policy landscape is too dynamic and entity-specific for a generic table. The per-baseline curation pattern is what we use whenever the "row context" is needed to interpret the sheet cell.

**Consequences.**
- `enrich_mev_block_builders.py` has ~16 lines of curated values per entity (where Validators has ~1 line of phrase lookup) but the values are auditable side-by-side with the entity's other curated fields.
- Adding a new MEV entity requires hand-curating its dual-enum quadruple, not just adding a phrase to a map. This is correct: the curator should think about the policy landscape per-entity, not delegate to a one-size-fits-all mapping.
- Future subsectors that introduce their own multi-axis sheet cells follow the same rule: if the source phrases are stable → mapping table; if they're per-entity nuanced → curated per baseline.

**Alternatives considered.**
- *Build a generic MEV mapping table.* Rejected — would either be too coarse (collapsing important distinctions like "evolving" vs "configurable") or too long (one entry per entity, defeating the abstraction).
- *Land the dual-enum in the sheet as separate columns.* Rejected — we don't own the sheet; the upstream curators won't reshape their headers for our schema.
- *Split lazily in the UI.* Rejected — querying by single-axis values (e.g. "all relays with `policy='neutral'`") requires the split to be in the storage layer.

---

## 2026-05-20 — Introduce `public.organizations` table; `maintaining_organization` becomes a typed FK on `public.projects`

**Context.** The market map has a structural problem the first two subsectors masked but the Validators subsector exposes head-on: the same real-world company appears in many subsector rows. Coinbase shows up in Validators (as `Coinbase (Validator Operations)`) and will later show up in Custody, Exchanges, On/Off-Ramps, and Wallets. Today, each of those would be a duplicated row with its own copy of `hq_country`, `founded_year`, `total_funding_usd`, `twitter_handle` — guaranteed to drift out of sync. Same problem for Consensys (Teku + Besu today, MetaMask + Infura + Linea tomorrow) and the Ethereum Foundation (Geth + Yellow Paper + Execution EIPs + Consensus Specs today, plus future ecosystem programs).

The Perplexity-drafted `validators-staking-providers.fields-to-add.md` proposes the fix: every subsector row carries a `maintaining_organization` slug that FKs into a single `organizations` table. That table holds the shared universal fields **once**; subsector rows hold only the attributes that are specific to what that org does in that subsector.

**Decision.** Ship the cross-cutting `public.organizations` table now, at the start of M8.7, instead of bolting it on later. Migration `supabase/migrations/20260520_0003_organizations_table_and_backfill.sql` introduces:

- `public.organizations(slug PK, display_name, legal_name, entity_type, website_url, twitter_handle, logo_url, hq_country, founded_year, team_size_range, total_funding_usd, last_funding_round, last_funding_date, stage, funding_model, status, acquired_by_slug, notes, attributes jsonb)`. `entity_type` enum: `company | dao | foundation | aggregate | individual`. RLS on, public-readable, writes via service role only. `updated_at` trigger via shared `public.tg__set_updated_at()`.
- `public.projects.maintaining_organization text references public.organizations(slug) deferrable initially deferred` — typed FK column. Nullable for aggregates.
- `public.projects.is_aggregate boolean default false` and `public.projects.not_applicable_reason text` for explicit handling of category rows (Solo Validators today; "Other rollups", "Other DAOs" tomorrow). `not_applicable_reason` enum: `aggregate_category | dao_governed | protocol_specification | distributed_collective`.
- Inline backfill for the 8 distinct orgs already in flight (`ethereum-foundation`, `sigma-prime`, `chainsafe`, `status`, `offchain-labs`, `consensys`, `erigon`, `nethermind`) with curated universal data. Prysmatic Labs → `offchain-labs` (acquired Jan 2022); Erigon Community → `erigon` (legal entity Erigon Technologies AG).

**Ingest rule (codified in `enrich_validators_staking_providers.py`, will be replicated across all future enrichment scripts).** When ingesting any subsector row: (1) look up `organizations[slug]` first; (2) if it doesn't exist, create it from the row's universal fields; (3) if it does exist, **do not overwrite** — only attach the new subsector row. The orgs table is upsert-by-slug; subsector tables are insert-only relative to it. DAOs (Lido DAO, Rocket Pool DAO, StakeWise DAO) get their own org rows with `entity_type='dao'` so financial fields can be null without breaking validation. Aggregates set `is_aggregate=true, maintaining_organization=null, not_applicable_reason='aggregate_category'`.

**Consequences.**
- Cross-subsector "everything this org does" queries become a single join: `select * from projects where maintaining_organization='coinbase'` will, after Custody and Exchanges land, return every Coinbase row across the map. This is the long-term payoff.
- The legacy `sector_attributes.maintaining_organization` JSONB key is intentionally **left in place** on existing rows for back-compat — the typed FK column is the new source of truth, but cleaning up the JSONB key happens in a separate UI-cutover migration. No data is lost.
- For exchange validator-ops rows, the FK points at the **parent exchange** (`coinbase`, `kraken`, `binance`), not at a synthetic "Coinbase Validator Operations" org. The parenthetical disambiguation lives in `projects.name`; the slug carries `-validator-operations` suffix; the org FK is the parent.
- Universal-field duplication on `projects` (founded_year, hq_country, etc.) is *not* removed in this migration. That's a UI-coupled cleanup left for a future pass; the org row is now the canonical write target for new data.

**Alternatives considered.**
- *Keep `maintaining_organization` as a free-text string in JSONB indefinitely.* Rejected — every subsector that ingests after Validators makes the duplication worse.
- *Add a `parent_company` slug as the typed column without a backing `organizations` table.* Rejected — solves the FK but not the data-once-not-many problem, and forces the same migration later anyway.
- *Backfill universal fields in a single rip-the-bandaid migration that also drops `projects.{founded_year,hq_country,...}` columns.* Rejected — too coupled to the UI; ship the table first, cut the UI over later.

---

## 2026-05-20 — `funding_model` enum lives in `subsector_attributes` first, promote to typed column when a second subsector needs it

**Context.** The Execution Layer source sheet does not encode *how* each entity is funded. The four production clients have fundamentally different funding mechanics: Geth is EF-internal headcount with no discrete raise; Nethermind raised a ~$8M Series A in 2022; Besu is funded inside Consensys; Erigon runs on EF + Optimism grants plus services revenue. The Perplexity-drafted `execution-layer.fields-to-add.md` proposes a `funding_model` enum to make this legible: `venture | foundation-internal | corporate-internal | grants-plus-services | dao | community | n/a`.

The same field would arguably help every other Core Protocol Architecture subsector (Consensus Layer, Validators & Staking Providers, MEV & Block Builders, Network Upgrades) and likely the DeFi / Monetary subsectors too. But promoting it to a typed `public.projects.funding_model` column now means committing to the enum *before* a second subsector validates the values.

**Decision.** Land `funding_model` in `subsector_attributes` for the Execution Layer rows only, scoped to that subsector's JSON Schema. When the next subsector to use it ships (most likely Validators & Staking Providers), evaluate whether the enum needs additional values (e.g. `tokenized-public-good`, `protocol-revenue-share`) and only then promote to a typed column on `projects` via a migration. The promotion path is identical to the `maintaining_organization` candidate already noted in the consensus-layer skill — JSONB first, typed later.

**Consequences.**
- Execution-layer baselines and UI can use the enum today (Geth → `foundation-internal`, Nethermind → `venture`, etc.).
- Cross-subsector queries (e.g. "all VC-funded execution clients vs VC-funded staking providers") need a `subsector_attributes->>'funding_model'` JSONB key path until promotion.
- The enum is intentionally small at v1; we'll grow it deliberately rather than chase every edge case up front.

**Alternatives considered.**
- *Promote to a typed column right now.* Rejected — premature commitment without a second consumer to validate the enum's shape.
- *Leave funding mechanics as free-text inside the existing `last_funding_round` field.* Rejected — `last_funding_round` is the actual round name (`series-a`, `seed`, `ecosystem-grant`, `acquired`), distinct from the funding *model* (the mechanism). Conflating them loses information.

---

## 2026-05-20 — Defer generalization of `enrich_consensus_layer.py` → `enrich_clients.py` until subsector #3

**Context.** Execution Layer is the second subsector to use the same enrichment shape: GitHub-derived founded_year + release + contributors-90d, plus a hand-curated baseline registry of (org / HQ / team_size / twitter / funding triplet / share_pct / diversity_phrase) entries, plus a fixed dual-enum mapping. The Consensus Layer pass that shipped earlier today flagged the obvious next step: extract the shared logic into a generic `enrich_clients.py --subsector <slug>` that loads its baseline registry from `baselines/<slug>.py`.

**Decision.** Don't generalize yet. Ship `enrich_execution_layer.py` as a near-twin of `enrich_consensus_layer.py` and revisit the abstraction once Validators & Staking Providers (M8.7) has been ingested. The third instance is where pattern-vs-coincidence becomes visible — Validators may want a totally different telemetry shape (uptime % per validator from beaconcha.in, slashing attribution, etc.) that doesn't fit the GitHub-release pattern at all.

**Consequences.**
- Two copies of the GitHub helpers, the Supabase patch helpers, and the `main()` loop. Acceptable duplication for now (~80 lines each).
- The script-level diff between the two files reads as the spec: each one's `BASELINES` + `DIVERSITY_MAP` + per-subsector normalization. Easier to review per-subsector PRs.
- Generalization is parked in `docs/FUTURE_PLANS.md` with a concrete recipe so the next pass doesn't have to re-derive.

**Alternatives considered.**
- *Generalize now and force Validators into the same shape.* Rejected — pre-extracting before the third consumer ships almost always bakes in the wrong abstraction.
- *Stop here, never generalize.* Rejected — duplication will start to hurt by subsector #4 or #5. Plan to do it deliberately at M8.7.

---

## 2026-05-20 — `client_diversity_risk` and `client_diversity_role` are a dual-enum, not a single field

**Context.** The source Google Sheet stores Ethereum client diversity in one cell shaped like `"Historically Dominant (Elevated Correlated Failure Risk)"`. The v1 ingest split this on the first `(` into `client_diversity_risk` (enum head) and `client_diversity_risk_note` (free text). That worked for v1 but conflated two *different* dimensions: severity (how big is the concentration risk?) and role (what kind of contributor is this entity to client diversity?). A single field cannot answer both.

Concrete: Lighthouse is in the "Balanced Share (Positive for Client Diversity)" bucket. Severity is low-to-medium. Role is "balanced-contributor". Teku, Nimbus, and Lodestar all share `minority-positive` severity but play three different roles (`strategic-minority`, `decentralization-critical`, `research-language-diversity`). Collapsing role into the severity field destroys this signal.

The external sourcing guide at `~/wazarat/consensuslayer/consensus-layer.data-sources.md` recommends a dual-enum explicitly, with a fixed mapping table from the source phrase to (severity, role).

**Decision.** Treat `client_diversity_risk` (severity grade) and `client_diversity_role` (qualitative role) as two independent enum fields inside `subsector_attributes`. Both live in JSONB — `additionalProperties: true` — so we did not need a typed-column migration. The role is **derived** from `client_diversity_risk_note` at enrichment time per the fixed table in `.cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/consensus-layer.md`. The role is not pulled from the sheet because the sheet does not separate it.

**Consequences.**
- UI must render the chip from `client_diversity_risk` and the secondary line from `client_diversity_role`. Never re-merge.
- Both fields update together. The enrichment script and any future sheet-row edits must keep them consistent.
- When new clients arrive, the curator picks the source phrase and the script applies both halves deterministically — no per-row judgment required.
- Lighthouse's severity was corrected from `medium` → `low-medium` on 2026-05-20 (the doc's mapping table places "Balanced Share" at `low-medium`, not `medium`).

**Alternatives considered.**
- *Keep one field, encode role in the `_note`.* Rejected — defeats the purpose; you cannot sort or filter on role.
- *Promote both to typed columns now.* Rejected — JSONB keeps cross-subsector schema evolution cheap. Promote only when at least two subsectors share the same field.
- *Drop the severity field, keep only role.* Rejected — severity is the more chart-friendly axis. Both have independent value.

---

## 2026-05-20 — `clientdiversity.org/api` does not exist; validator share is a curated estimate until a working live source is wired up

**Context.** Both `~/wazarat/consensuslayer/consensus-layer.data-sources.md` and the in-skill subsector reference name `clientdiversity.org/api` as the primary source for `validator_share_pct`. In practice both `/api` and `/api/v1` return 404 HTML (verified 2026-05-20). The site only renders an HTML dashboard; there is no documented JSON endpoint. Alternatives discussed in the doc — `rated.network` — require authenticated API access.

**Decision.** Populate `validator_share_pct` from a hand-curated baseline embedded in `.cursor/skills/market-map/scripts/enrich_consensus_layer.py` (BASELINES), and stamp every row written by that script with `data_confidence='estimate'` + `data_refreshed_at=<utc-now>`. UI consumers can use the confidence band to decide whether to render the value with a "(est.)" suffix or hide it on strict views. When a working live source comes online, the script's per-baseline `validator_share_pct` field will be replaced with the API call and `data_confidence` will flip to `verified`.

**Consequences.**
- The single field still moves in step with reality (we update the baseline whenever we refresh).
- Downstream code can trust `data_confidence` as a freshness band — no need to inspect URLs or hostnames.
- The same pattern (estimate → verified) is reusable for any other field where the documented live source turns out to be unreachable or gated. Set the baseline, flag as estimate, surface the timestamp.

**Alternatives considered.**
- *Scrape the clientdiversity.org HTML dashboard.* Reserved for a follow-up; scraping is fragile and the page is JS-rendered. If it becomes the only path, we will add a dedicated `scripts/refresh_validator_share.py` instead of inlining HTML parsing into the enrichment script.
- *Use rated.network with a paid API key.* Out of scope for a pre-revenue product. Revisit post-launch.
- *Leave `validator_share_pct` null.* Rejected — the value is genuinely informative even at ±3pp accuracy, and the dual-enum (`risk` + `role`) is not a substitute for the percentage.

---

## 2026-05-15 — Frontend on Vercel, backend on Render (NOT both on Vercel)

**Context.** The Python backend could in theory run on Vercel as a serverless function. Vercel even auto-detects the monorepo and offers a multi-service deploy (which is what triggered the "vercel.json required to deploy projects with multiple services" error during M5).

**Decision.** Frontend deploys to **Vercel** (root = `frontend/`). Backend deploys to **Render** (root = `backend/`, using `backend/render.yaml`). Vercel must be configured with **Root Directory = `frontend`** so it never sees the backend folder.

**Consequences.**
- Two deploys instead of one. Acceptable.
- Backend gets long-lived processes (good for the future on-chain marketplace indexer / background jobs that Vercel serverless can't easily host).
- Frontend talks to backend via the absolute URL in `NEXT_PUBLIC_API_BASE_URL`, proxied through Next.js's own `/api/waitlist` route handler so the browser never deals with CORS.
- Free Render plan cold-starts the backend after ~15min idle. The waitlist call may take 5–10s on first hit. Acceptable for a waitlist; will revisit if/when the backend serves higher-throughput traffic.

**Alternatives considered.**
- *Vercel Python serverless functions.* Tighter limits, harder for future Solidity/indexer logic, weaker DX for a real Python project.
- *Skip Python entirely, use Next.js API routes only.* Rejected — the user explicitly wants a Python backend.
- *Vercel multi-service (`experimentalServices`).* Rejected — experimental, vendor-locks us to Vercel for the backend, and reintroduces the cold-start question.

---

## 2026-05-15 — Instantly.ai is the source of truth for waitlist leads (no DB)

**Context.** We need somewhere to store waitlist signups. Options: Postgres (Supabase/Neon), our own SQLite, or just push directly to a CRM/email tool.

**Decision.** No database on day one. The backend's `POST /api/waitlist` calls Instantly.ai v2 (`POST /api/v2/leads`) directly with `email`, `campaign`, and `custom_variables = { source, role }`. Instantly is the system of record.

**Consequences.**
- Zero DB to operate. One fewer secret. One fewer failure mode.
- Lead segmentation lives in Instantly (custom variables `source` and `role`).
- If Instantly is down, leads are lost — we accept this for the waitlist phase.
- 4xx errors from Instantly (e.g. duplicate skip via `skip_if_in_workspace: true`) are silently mapped to a 200 success on our side, so we never tell a user "you're already on the list" or leak existence info to bots.

**Alternatives considered.**
- *Supabase + nightly Instantly sync.* Overkill at this stage; reintroduce later if we need analytics on the waitlist itself.

**When to revisit.** If we add user accounts, paid tiers, or anything that requires querying our own user list.

---

## 2026-05-15 — Cyber/dark "web3 native" aesthetic (not blue-corporate, not Linear-minimal)

**Context.** Three design directions were on the table: (a) keep the previous repo's blue/black "professional" theme, (b) Linear/Vercel-style monochrome minimalism, (c) modern dark cyber/web3 (gradients, neon accents, animated grid).

**Decision.** Direction (c). Custom palette: deep black `#05060A` (ink-950), electric blue `#3D7BFF`, neon violet `#8B5CF6`, signal cyan `#22D3EE`. Display font Space Grotesk; body Inter; accent JetBrains Mono.

**Consequences.**
- Resonates with the actual buyer (web3 + AI agent dev). Looks like a16z crypto / Arbitrum / Base sites, not a SaaS landing page.
- Forces us to invest in real visual craft (animated grid background, agent-network SVG, glass surfaces, glow rings). We've done this in M3.
- Dark mode only — no light theme. We add `class="dark"` permanently on `<html>`.

**Alternatives considered.** See above. Linear-minimal would be safer but easier to ignore.

---

## 2026-05-15 — Hand-rolled UI primitives instead of shadcn/ui

**Context.** shadcn/ui is the default for "I want nice React components fast." The plan even called for it.

**Decision.** Use a tiny hand-rolled set in `frontend/components/ui/` (`Button`, `Input`, `Card`, `Logo`) instead of bringing in shadcn + Radix.

**Consequences.**
- Bundle stays small. Build is fast. Zero Radix dependency tree.
- We own the components — easy to tweak for the cyber aesthetic without overriding shadcn defaults.
- `Button` supports an `asChild` prop via a lightweight `React.cloneElement` (no Radix Slot needed) so we can render `<a>` / `<Link>` triggers with button styling.

**Alternatives considered.**
- *shadcn/ui.* Reasonable default; rejected because we only need 4 components and the cyber aesthetic differs enough that we'd be overriding most defaults.

**When to revisit.** When we need a real Dialog/Popover/Combobox/Select — at that point pulling in Radix primitives directly (or shadcn for those specific pieces) is correct.

---

## 2026-05-15 — Hero animations use CSS keyframes, not Framer Motion `initial/animate`

**Context.** First M3 build used Framer Motion for the hero (`initial={{ opacity: 0 }}` → `animate={{ opacity: 1 }}`). This rendered the hero invisible in the initial HTML, breaking SEO crawlers and creating a janky first paint.

**Decision.** Above-the-fold hero copy uses Tailwind's `animate-fade-in-up` keyframe (defined in `tailwind.config.ts`) with staggered `[animation-delay:*]` modifiers. Framer Motion is reserved for the decorative `<AgentNetwork />` SVG only.

**Consequences.**
- Hero is in the SSR HTML and visible in the first paint (after CSS loads).
- We pay nothing for Framer Motion on the hero render path.
- Staggered reveal still feels alive.

**Alternatives considered.**
- *Framer Motion `initial={false}` + `whileInView`.* Solves the SEO issue but adds JS to the critical path for no reason.

---

## 2026-05-15 — Honeypot field for spam, no captcha (yet)

**Context.** Public waitlist form needs basic spam defence.

**Decision.** Hidden `company` field on both client (`WaitlistForm.tsx`) and server (`schemas.WaitlistSignup.company`). If non-empty, server returns 200 silently without calling Instantly. Plus a 1.5s client-side submit throttle.

**Consequences.**
- No friction for real users. No third-party captcha SDK.
- Will catch dumb bots; sophisticated ones will bypass it.

**When to revisit.** If we see spam leads landing in Instantly. Then add Cloudflare Turnstile (preferred, no Google) or hCaptcha.

---

## 2026-05-15 — Milestone-based delivery; do not start M(N+1) until M(N) ships

**Context.** User explicitly asked for milestone-gated work.

**Decision.** Each milestone has explicit exit criteria (in `README.md` and the `.cursor/plans/` plan file). Agents must not proceed to the next milestone until the previous one's exit criteria are met. Marketplace work (M6) is **explicitly out of scope** until M5 (production deploy) is verified live.

**Consequences.**
- Slower in the short term, predictable in the long term.
- Forces each milestone to be independently shippable / useful.

---

## 2026-05-15 — Persistent agent memory lives in `docs/`

**Context.** Chat context windows fill up. Future agents (or future-me) need to reload state without re-reading the whole repo.

**Decision.** Three Markdown files in `docs/`:
- `AI_CONTEXT.md` — what the project is, the stack, the rules. Read first.
- `DECISIONS.md` — append-only log of locked-in choices (this file).
- `CHANGELOG_DEV.md` — append-only log of what changed and why, written after every meaningful change.

**Consequences.**
- Agents have a stable contract for ramping up.
- Repo grows a small docs surface. Worth it.

---

## 2026-05-15 — Roadmap renumbered: Marketplace is now M11, with M6–M10 in between

**Context.** The original 7-item roadmap (M0–M6) jumped straight from "deploy" to "on-chain marketplace." After M5 shipped, the user articulated five intermediate milestones that need to land first: brand polish, analytics, Market Map data, auth + Substack paid sync, and the Agents pillar.

**Decision.** Renumber the roadmap to:
- **M6** — Brand assets (logo, favicon, OG image) + production E2E verification
- **M7** — Analytics (PostHog, Plausible, Vercel Analytics, or GA4 — pick at kickoff)
- **M8** — Market Map backed by Supabase (Postgres) — sectors + projects schema, FastAPI routes, sector grid UI
- **M9** — Auth (Supabase) + roles (user/admin/superadmin) + Substack paid-subscriber sync
- **M10** — Agents pillar (skill `.md` schema, agent profile pages, submit-an-agent form)
- **M11** — On-chain marketplace on Arbitrum Sepolia (Foundry contracts + wagmi/RainbowKit + indexer)

**Consequences.**
- Marketplace is now intentionally further out — the project ships value (research, market map, agents directory, paid auth) before the on-chain piece.
- Each new milestone has its own gating decision still to make at kickoff (analytics vendor, paid-sync mechanism, skill-file schema).
- README milestone table and `AI_CONTEXT.md` section 8 must reflect this — both updated 2026-05-15.

**Alternatives considered.**
- *Keep marketplace as M6, add the rest as M7–M11.* Rejected — would imply we should jump to contracts before having auth/users to actually transact on behalf of, which is the wrong sequencing.
- *Drop the milestone gating entirely and parallelize.* Rejected — user explicitly chose milestone-gated delivery (see prior entry).

---

## 2026-05-17 — M7 analytics vendor: PostHog (Product + Web Analytics first)

**Context.** M7 opens with the deferred analytics-vendor decision (PostHog vs Plausible vs Vercel Analytics vs GA4). User opened a PostHog onboarding and pre-selected four products: **Product Analytics, Web Analytics, LLM Analytics, Logs** (default: Product Analytics). PostHog is also the recommended pick in the M6 follow-ups in `CHANGELOG_DEV.md`.

**Decision.** Adopt **PostHog Cloud (US)** as the single analytics vendor.
- Phase 1 (this milestone): Product Analytics + Web Analytics via `posthog-js`. Autocapture on; manual `$pageview` from the App Router; person profiles set to `identified_only` (avoid an anonymous profile per session); waitlist signups identified with the email as `distinct_id` and a `waitlist_submitted` event captured.
- Phase 2 (when the relevant features land): LLM Analytics via `posthog-node` once the agents pillar makes its first LLM calls (M10); Logs via OTLP exporter once we have something worth logging server-side.

**Consequences.**
- One vendor, one project, one billing line item across product / web / replay / errors / LLM / logs / flags / experiments — explicitly the "grouping products in one project" pattern PostHog recommends.
- All ingestion goes through a same-origin reverse proxy at `/ingest/*` (configured in `next.config.mjs` via `rewrites()` → `us.i.posthog.com` + `us-assets.i.posthog.com`). Two upsides: ad blockers that block `*.posthog.com` won't drop events; the cookie/event surface stays first-party. Cost: every event request traverses Vercel's edge, which is fine on our traffic.
- The provider is initialised inside a client `useEffect` (we're on Next.js 14.2.35, which does **not** support `instrumentation-client.ts` — that's 15.3+). When we upgrade to Next 15.3+ we should migrate to `instrumentation-client.ts` and delete the provider component (the example reference notes the two approaches must not be combined).
- If `NEXT_PUBLIC_POSTHOG_KEY` is missing the provider logs a warning and no-ops, so local dev and preview deploys without the secret still build and run.
- Identifying by email is a deliberate trade-off (vs an opaque UUID): we already store the email in Instantly, so PostHog isn't adding new PII surface, and it makes cross-tool linking trivial.

**Alternatives considered.**
- *Plausible.* Lightest, privacy-friendliest, but no funnels / cohorts / experiments / replay / LLM analytics. We'd outgrow it the moment M9 (auth) lands.
- *Vercel Analytics + Vercel Web Analytics.* Zero config, but the data is read-only inside Vercel — no cohorting, no event capture, no flags, no replay. Useful as a free supplement later if we want Core Web Vitals.
- *GA4.* Universally hated DX, terrible event model, sampling. No.
- *Self-hosted PostHog.* Not worth the ops cost at this stage.

**When to revisit.** When PostHog Cloud bills exceed ~$50/month, or when we need a metric PostHog explicitly doesn't surface well (e.g. SEO).

---

## 2026-05-17 — Style: no em dashes in user-facing copy

**Context.** Em dashes (`—`) read as LLM-generated to a non-trivial slice of readers and the user wants the marketing copy to feel hand-written. The visible offender today was the shared-link title (`CanHav — Turn web3 research into products…`) in `app/layout.tsx` metadata.

**Decision.** No em dashes in user-facing copy on the site. Use a colon, comma, period, or parenthetical instead. The shared-link `<title>` now uses `:` (e.g. `CanHav: Turn web3 research into products…`). Other em dashes in landing components will be migrated opportunistically as we touch those files (the `AI_CONTEXT.md` "Copy rule" enforces this for future agents). Em dashes are still allowed in `docs/`, code comments, and PR descriptions.

**Consequences.** Slightly stricter copy review surface; agents have one fewer "tell". Costs nothing.

**Alternatives considered.** *Ban en dashes too.* Rejected — en dashes (`–`) are useful for date ranges and don't carry the same LLM-vibe.

---

## 2026-05-18 — M8 Market Map: sector-by-sector rollout with 3-tier JSONB schema

**Context.** The original M8 ("provision Supabase, seed 500+ projects, replace `/market-map` placeholder") had two problems: (1) the "500+" target forces premature data work before the schema has been learned, and (2) there's no system for the next agent to keep extending the dataset. The user also surfaced that the 7 source sectors have heterogeneous fields — every sector has its own sheets with overlapping-but-not-identical columns, and within a sector each subsector has unique columns of its own. A flat one-size-fits-all schema would either lose those fields or churn migrations every sector.

**Decision.** Ship M8 as a chain of sub-milestones (M8.1 → M8.11) that loop sector-by-sector. The data model is three tiers:

- **Universal columns** (typed Postgres columns on `projects`): the fields every project has regardless of sector — `slug`, `name`, `description`, `website_url`, `status`, `stage`, `founded_year`, `total_funding_usd`, etc.
- **`sector_attributes jsonb`** on `projects`: fields shared by every subsector within a sector. Shape documented in `sectors.common_field_schema` (JSON Schema).
- **`subsector_attributes jsonb`** on `projects`: fields specific to one subsector. Shape documented in `subsectors.specific_field_schema`.

Promotion rule: once a JSONB key appears in **3+ sectors**, promote it to a typed column via a follow-up migration. Not before.

A repo-local Claude Skill at [.cursor/skills/market-map/](.cursor/skills/market-map/) codifies the workflow:
- Entry [`SKILL.md`](.cursor/skills/market-map/SKILL.md) (audited against the user-supplied "Audit my Claude Skills" framework: visibility, deterministic vs non-deterministic, composability).
- Deterministic shared scripts in `scripts/` (`fetch_sheet`, `normalize_row`, `validate_schema`, `upsert_projects`, `ingest_subsector`, `add_sector`, `add_subsector`) — zero token cost, idempotent, side effects gated behind `--dry-run`.
- Per-sector + per-subsector reference docs (`user-invocable: false`) auto-load when working on this surface but don't clutter `/menu`.

Source data lives in 7 public Google Sheets (one workbook per sector, one tab per subsector). Ingest pulls via the public `gviz/tq?tqx=out:csv` endpoint — no Sheets API creds, no manual CSV exports.

**Consequences.**
- Adding a new project to an existing subsector is a one-command operation: `python .cursor/skills/market-map/scripts/ingest_subsector.py --slug <subsector>`.
- Adding a brand-new subsector is two commands + one migration: `add_subsector.py` scaffolds the skill stub + JSON schema + column map; an SQL migration inserts the row.
- JSONB makes schema iteration painless during the early sectors, at the cost of giving up some Postgres type-checking until we promote. Indexed via `gin (sector_attributes)` + `gin (subsector_attributes)` so JSONB-key filters stay fast.
- Each sector loop ends with a deploy. The "500+ projects" copy on the homepage becomes truthful sector-by-sector — we delete the placeholder claim until real numbers back it up.
- Frontend reads via FastAPI only (`/api/market-map/*`), never directly from Supabase in the browser. Keeps the anon key off the wire and centralizes caching.

**Alternatives considered.**
- *Typed per-sector child tables (`core_protocol_projects`, `defi_projects`, ...).* Strictest type-safety but migration churn every sector and an N-way join every cross-sector query. Rejected.
- *Pure EAV (entity-attribute-value).* Maximum flexibility, terrible query ergonomics, no integrity. Rejected.
- *One JSONB blob (no sector/subsector split).* Loses the structural information the UI needs to render fields with proper labels per sector. Rejected.
- *Seed all 500+ projects in one go up front.* Original plan. Rejected per the kickoff conversation — premature data work and no learning loop.

**When to revisit.** When 3+ JSONB keys have stabilized across sectors → promote to typed columns. When the dataset exceeds ~5k projects, consider materialized views for the sector/subsector summary counts (currently plain `view`s).

---

## 2026-05-15 — M5 production deploy verified end-to-end (Render + Vercel + Instantly)

**Context.** M5 was marked "configs ready" pending the user actually clicking deploy on both platforms.

**Decision.** M5 is now ✅ **done**. Verified on 2026-05-15:
- `GET https://canhav-backend.onrender.com/api/health` → `200 {"ok":true,"service":"canhav-backend","instantly_configured":true}`
- `POST https://canhav-agentmarketplace.vercel.app/api/waitlist` (3 calls, one per source tag: `landing`, `market-map`, `agents`) → all `200` with real Instantly `lead_id`s returned (`019e2c62-445e-...`, `019e2c62-e46d-...`, `019e2c62-e650-...`).
- ALLOWED_ORIGINS in production: `http://localhost:3000,https://canhav.com,https://www.canhav.com,https://canhav-agentmarketplace-5cxv27582-wazarats-projects.vercel.app,https://canhav-agentmarketplace.vercel.app`.

**Consequences.**
- The Render free tier cold-starts after ~15min idle. First waitlist submission after a long idle may take 5–10s. Acceptable for a waitlist, will revisit if traffic grows.
- The custom domain `canhav.com` is whitelisted in CORS but not yet pointed (DNS work pending).

---

<!--
TEMPLATE for new entries:

## YYYY-MM-DD — <one-line decision>

**Context.** <what triggered this>
**Decision.** <what we chose>
**Consequences.** <good and bad>
**Alternatives considered.** <what we rejected and why>
**When to revisit.** <optional — what would change our mind>
-->
