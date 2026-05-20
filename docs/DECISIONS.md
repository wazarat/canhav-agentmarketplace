# Architectural Decisions

> Append-only log of decisions that shape this codebase. **Do not re-litigate** without explicit user approval. If you must deviate, add a new entry that supersedes the old one and links back to it.
>
> Format: `## YYYY-MM-DD — <decision>` followed by **Context · Decision · Consequences · Alternatives considered**.

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
