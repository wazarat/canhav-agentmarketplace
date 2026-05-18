# Dev Changelog

> Append-only log of meaningful changes. **Update this file after every change.** Newest entry on top.
>
> Format per entry:
>
> ```
> ## YYYY-MM-DD HH:MM — <short title>
>
> **Why.** <user-visible reason or technical motivation>
> **What changed.** <bullet list>
> **Files.** <paths touched, grouped if many>
> **Verified.** <build/test/manual check done>
> **Follow-ups.** <if any — empty if none>
> ```

---

## 2026-05-18 18:45 — M8.1-M8.4: Market Map foundations (schema, API, UI shell, skill folder)

**Why.** Kickoff of M8 (Market Map). User chose a sector-by-sector rollout instead of the original "seed 500+" approach, with a repo-local Claude Skill that codifies the workflow so each new sector is mostly data work. The 7 source sectors have heterogeneous fields, so we adopted a 3-tier schema: typed universal columns on `projects` + `sector_attributes jsonb` + `subsector_attributes jsonb`, with JSON Schemas describing each blob's shape.

**What changed.**

Supabase migrations (new):
- `supabase/migrations/20260518_0001_market_map_schema.sql` — `sectors`, `subsectors`, `projects` tables. Universal columns (`slug`, `name`, `description`, `status`, `stage`, `founded_year`, `total_funding_usd`, etc.) + the two JSONB attribute columns. GIN indexes on `sector_attributes` / `subsector_attributes` for JSONB-key filters. `pg_trgm` index on `projects.name` for ILIKE search. Auto-`updated_at` triggers. RLS enabled, anon-role select-only. Two convenience views: `sector_summary` and `subsector_summary`.
- `supabase/migrations/20260518_0002_seed_sectors_subsectors.sql` — seeds all 7 sectors and all 36 subsectors with `display_order`, descriptions, and the source-sheet `id`/`gid` for every subsector. Idempotent (`on conflict do update`).
- **Not yet applied** — Supabase MCP `create_project` is rate-limited by a Vercel-Marketplace-managed 2-project quota; user is provisioning `canhav-market-map` manually in the dashboard. Migrations will be applied via Supabase MCP `apply_migration` once the project is `ACTIVE_HEALTHY`.

Backend (FastAPI):
- `backend/app/services/supabase.py` (new) — thin async client around Supabase PostgREST. `is_configured()` health gate, `get()` / `get_single()` helpers, custom `SupabaseError`.
- `backend/app/routes/market_map.py` (new) — read-only API at `/api/market-map/*`: `GET /sectors`, `GET /sectors/{slug}`, `GET /subsectors/{slug}`, `GET /subsectors/{slug}/projects`, `GET /projects` (with `sector` / `subsector` / `search` / `stage` / `status` filters), `GET /projects/{slug}`. Returns the project's `sector` + `subsector` + their schemas alongside the row so the UI can label JSONB keys.
- `backend/app/main.py` — wires `market_map_router`, splits `is_configured` imports into `instantly_configured` + `supabase_configured`, threads both into `/api/health`.
- `backend/app/schemas.py` — `HealthResponse.supabase_configured` field added (defaults to False so existing health checks don't break).
- `backend/.env.example` — added `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` with comments about which key each layer uses.
- `backend/requirements.txt` — added `jsonschema==4.23.0` (used by the M8 ingest validator).

Frontend (Next.js App Router):
- `frontend/lib/market-map.ts` (new) — typed server-side client for `/api/market-map/*`. Exports `listSectors`, `getSector`, `getSubsector`, `listSubsectorProjects`, `getProject`, plus `ProjectStatus` / `ProjectStage` union types and the full row interfaces. Server-side `revalidate: 60`. Custom `MarketMapError` so 404s can be distinguished from upstream failures.
- `frontend/components/market-map/SectorGrid.tsx`, `SubsectorGrid.tsx`, `ProjectTable.tsx`, `Breadcrumbs.tsx`, `ErrorPanel.tsx` (all new) — sector/subsector tiles, project table with formatted funding, breadcrumbs, and a warming-up banner when Supabase is not yet configured.
- `frontend/app/market-map/page.tsx` — REPLACED the `ComingSoonShell` usage with a live sector grid + stats strip + graceful error panel when the API is unreachable. Server component, fetches at request time with 60s revalidate.
- `frontend/app/market-map/[sector]/page.tsx` (new) — sector detail (subsector grid + crumbs + counts).
- `frontend/app/market-map/[sector]/[subsector]/page.tsx` (new) — subsector detail with `ProjectTable`.
- `frontend/app/market-map/project/[slug]/page.tsx` (new) — project detail. Universal-field overview + sector_attributes section (labels driven by the sector's `common_field_schema`) + subsector_attributes section (labels driven by the subsector's `specific_field_schema`).
- `frontend/.env.local.example` — documented the optional `API_BASE_URL` SSR override.

Repo-local Claude Skill (`.cursor/skills/market-map/`):
- `SKILL.md` — entry skill. Audited against the user-supplied "Audit my Claude Skills" framework: (1) Visibility — side-effecting tools have `disable-model-invocation: true`, background-knowledge skills have `user-invocable: false`. (2) Deterministic vs non-deterministic — `fetch_sheet`, `normalize_row`, `validate_schema`, `upsert_projects`, `add_sector`, `add_subsector` are pure scripts; AI is reserved for field-classification judgment. (3) Composability — every script lives in `scripts/` once and is reused across sectors; sector SKILL.md files reference universal fields by link rather than restating them.
- `scripts/_common.py`, `fetch_sheet.py`, `normalize_row.py`, `validate_schema.py`, `upsert_projects.py`, `ingest_subsector.py`, `add_sector.py`, `add_subsector.py` — full deterministic ingest pipeline. `normalize_row.py` strips whitespace from CSV headers before column-map lookup (handles the L3 sheet's wrapped headers — see below). `ingest_subsector.py` is the one-command end-to-end loop for adding projects to a subsector.
- `schemas/universal.json` — JSON Schema for the typed universal columns. 36 per-subsector schemas + 36 per-subsector column-map stubs + 7 per-sector schemas + 7 per-sector column-map stubs all scaffolded.
- 7 `sectors/<slug>/SKILL.md` reference files + 36 `sectors/<slug>/subsectors/<slug>.md` reference files — all `user-invocable: false`, auto-loaded when working in this surface.
- `sectors/rollup-scaling-frameworks/subsectors/l3-appchain-frameworks.md` — written long-form because of the source-sheet anomalies (see below).

L3 & Appchain Frameworks sheet investigation (the user's flagged source):
- Pulled the sheet via gviz CSV. 38 columns, 7 entity rows. Found three issues: (1) almost every column header from index 9 onwards has a trailing `\n` because the cell wraps; (2) the sheet explicitly notes overlap with Optimistic Rollups (`"OP Stack (already used, but also belongs here contextually)"`); (3) very low row count.
- Patched `normalize_row.py` to strip whitespace from headers before column-map lookup so the column map can use clean keys.
- Documented all three issues in `sectors/rollup-scaling-frameworks/subsectors/l3-appchain-frameworks.md` and recommended L3 ingest be done **last** within the Rollup sector so sector-common fields are settled first.

Docs:
- `docs/DECISIONS.md` — new entry **2026-05-18 — M8 Market Map: sector-by-sector rollout with 3-tier JSONB schema**. Documents the 3-tier model, the promotion rule (JSONB key → typed column when 3+ sectors share), and the rejected alternatives (typed per-sector tables, pure EAV, single JSONB blob, big-bang seed).
- `docs/AI_CONTEXT.md` — added `supabase/` and `.cursor/skills/market-map/` to the repo layout (section 3); added the Market Map data store subsection to section 4 (tech stack); added `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` to the env vars table (section 6); added "How to add a Market Map sector or subsector" quick reference to section 8.
- `README.md` — bumped M6 + M7 to ✅; replaced the M8 row with the sector-by-sector framing; added the M8.1-M8.11 sub-milestone breakdown; updated the architecture summary to mention `/api/market-map/*` and the ingest scripts.
- `DEPLOYMENT.md` — added `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` to the Render env table with clear notes on which key each layer uses; updated the smoke-test JSON to include `supabase_configured`; added a "§5 Market Map (M8) — Supabase" section with the 5-step provision flow.

**Files.**
- `supabase/migrations/20260518_0001_market_map_schema.sql` (new)
- `supabase/migrations/20260518_0002_seed_sectors_subsectors.sql` (new)
- `backend/app/services/supabase.py` (new)
- `backend/app/routes/market_map.py` (new)
- `backend/app/main.py`, `backend/app/schemas.py`, `backend/.env.example`, `backend/requirements.txt`
- `frontend/lib/market-map.ts` (new)
- `frontend/components/market-map/{SectorGrid,SubsectorGrid,ProjectTable,Breadcrumbs,ErrorPanel}.tsx` (new)
- `frontend/app/market-map/page.tsx`, `frontend/app/market-map/[sector]/page.tsx` (new), `frontend/app/market-map/[sector]/[subsector]/page.tsx` (new), `frontend/app/market-map/project/[slug]/page.tsx` (new)
- `frontend/.env.local.example`
- `.cursor/skills/market-map/SKILL.md`, `README.md`, `scripts/*.py` (8 files), `schemas/universal.json` + 7 sector + 36 subsector schema + column-map stubs, `sectors/*/SKILL.md` (7 sectors), `sectors/*/subsectors/*.md` (36 subsectors)
- `docs/AI_CONTEXT.md`, `docs/DECISIONS.md`, `docs/CHANGELOG_DEV.md` (this entry), `README.md`, `DEPLOYMENT.md`

**Verified.**
- Backend: `python -c "from app.main import app"` lists 8 API routes incl. the 6 new `/api/market-map/*` endpoints.
- Frontend: `npm run build` clean. 4 new dynamic routes registered (`/market-map`, `/market-map/[sector]`, `/market-map/[sector]/[subsector]`, `/market-map/project/[slug]`). No TS or lint errors. First Load JS for the new pages is 96.2 kB (same as the shared baseline).
- Skill scaffold: all 7 sectors + 36 subsectors scaffolded by a one-shot run of `add_sector.write_sector_files` + `add_subsector.write_files` for each pair. Verified the on-disk tree matches the plan structure.
- L3 sheet: pulled live via gviz, confirmed the wrapped-header issue, patched `normalize_row.py`, documented in the L3 reference doc.

**Follow-ups.**
- **User action required:** create the `canhav-market-map` Supabase project manually in the dashboard (free tier, `us-east-1`). Vercel Marketplace's 2-project quota blocks MCP `create_project` until then. Once `ACTIVE_HEALTHY`, the next agent (or me on resume) should: apply the two migrations via Supabase MCP `apply_migration`, verify `select count(*) from sectors` returns 7 and `subsectors` returns 36, then set `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` in `backend/.env` and on Render.
- M8.5 kickoff: pilot sector **Core Protocol Architecture**. Read the 5 source sheets, decide which columns are universal (already typed), which are `sector_attributes` (shared across all 5 subsectors), which are `subsector_attributes`. Edit the sector + 5 subsector JSON schemas + column maps. Run `python .cursor/skills/market-map/scripts/ingest_subsector.py --slug consensus-layer --dry-run` for each subsector, review, then commit. Goal: `/market-map/core-protocol-architecture` renders the 5 subsector tiles with non-zero project counts and at least one fully-populated project detail page in prod.
- Promote stable JSONB keys: once 3+ sectors share a key, file a migration that adds the typed column + backfills. Likely candidates after M8.5: `client_implementations`, `chain_layer` (L1/L2/L3/L4), `consensus_mechanism`.
- M8.6 prep: do not start L3 ingest until the other 3 Rollup subsectors are done. See `sectors/rollup-scaling-frameworks/subsectors/l3-appchain-frameworks.md` for the sheet-quality caveats.

---

## 2026-05-17 13:30 — M7: PostHog analytics wired (Product + Web) + em-dash purge in share title

**Why.** Kickoff of M7 (analytics). User chose PostHog after seeing four products pre-selected in the onboarding (Product Analytics, Web Analytics, LLM Analytics, Logs — default: Product Analytics). Same pass also removes the em dash from the shared-link title because em dashes "read LLM-generated" and the user wants to eliminate them from user-facing copy site-wide as we touch each file.

**What changed.**

Em dash → colon (share-link title only; the rest will be migrated opportunistically):
- `app/layout.tsx` — extracted a `SHARE_TITLE = \`${SITE.name}: ${SITE.tagline}\`` and reused it for `metadata.title.default`, `openGraph.title`, `openGraph.images[0].alt`, and `twitter.title`. Previously each of those used `${SITE.name} — ${SITE.tagline}`. Visible effect: when someone pastes a link to the site in iMessage/Slack/Twitter, the preview now reads `CanHav: Turn web3 research into products your agents can help ship.` instead of `CanHav — Turn web3 research into products…`.

PostHog M7 (Phase 1 — Product + Web Analytics):
- Installed `posthog-js@^1.373.5` and `posthog-node@^5.34.2` (the node SDK is staged for M10's LLM Analytics; not used at runtime yet).
- New `components/providers/PostHogProvider.tsx` (client). Initialises `posthog-js` inside `useEffect` with `api_host: "/ingest"`, `ui_host` from env, `capture_pageview: false` (we handle it manually for App Router), `capture_pageleave: true`, `capture_exceptions: true`, `person_profiles: "identified_only"`, `defaults: "2026-01-30"`. Guards against double-init via a module-level flag. If `NEXT_PUBLIC_POSTHOG_KEY` is missing, logs a dev-only warning and no-ops so local dev / preview deploys without the secret still build and run.
- New `components/providers/PostHogPageView.tsx` (client). Fires `$pageview` on `usePathname()`/`useSearchParams()` change, wrapped in `<Suspense>` so the App Router doesn't deopt every page into client rendering (per Next.js docs).
- `app/layout.tsx` — wrapped `<Background />`, `<Nav />`, `<main>`, `<Footer />`, and `<Toaster />` in `<PostHogProvider>`. The provider mounts `<PostHogPageView />` for us.
- `next.config.mjs` — added `rewrites()` to proxy `/ingest/static/:path*` → `us-assets.i.posthog.com/static/:path*` and `/ingest/:path*` → `us.i.posthog.com/:path*`, plus `skipTrailingSlashRedirect: true` (PostHog's API uses trailing slashes). This is the recommended "same-origin reverse proxy" pattern — ad blockers that block `*.posthog.com` can't drop our events, and the cookie/event surface stays first-party.
- `components/landing/WaitlistForm.tsx` — on successful `submitWaitlist()` we now call `posthog.identify(email, { email, role, waitlist_source })` and `posthog.capture("waitlist_submitted", { source, role, lead_id })`. On failure we capture `waitlist_submit_failed`. Both are wrapped in `try/catch` and gated on `posthog.__loaded` so analytics errors can never break the form.
- `frontend/.env.local.example` — added `NEXT_PUBLIC_POSTHOG_KEY=` and `NEXT_PUBLIC_POSTHOG_HOST=https://us.posthog.com`.
- `DEPLOYMENT.md` — added both env vars to the Vercel deploy table and a note explaining the `/ingest` reverse proxy + the "missing key → no-op" behaviour.

Docs:
- `docs/AI_CONTEXT.md` — added `posthog-js` to the stack list (section 4), added a "Copy rule" line under section 5 banning em dashes in user-facing copy, added `components/providers/` to the repo layout, added `NEXT_PUBLIC_POSTHOG_KEY` + `NEXT_PUBLIC_POSTHOG_HOST` to the env vars table (section 6).
- `docs/DECISIONS.md` — added two entries: (1) **M7 analytics vendor: PostHog (Product + Web Analytics first)** with the rationale, the explicit phasing (LLM Analytics deferred to M10, Logs deferred until we have something worth logging), and the rejected alternatives (Plausible / Vercel Analytics / GA4 / self-hosted). Includes a note that we're using the provider pattern instead of `instrumentation-client.ts` because we're on Next 14.2.35 (the instrumentation file is 15.3+ only) — when we upgrade we should migrate. (2) **Style: no em dashes in user-facing copy** locking in the copy rule.

**Files.**
- `frontend/app/layout.tsx`
- `frontend/components/providers/PostHogProvider.tsx` (new)
- `frontend/components/providers/PostHogPageView.tsx` (new)
- `frontend/components/landing/WaitlistForm.tsx`
- `frontend/next.config.mjs`
- `frontend/.env.local.example`
- `frontend/package.json` + `frontend/package-lock.json` (posthog-js, posthog-node added)
- `DEPLOYMENT.md`
- `docs/AI_CONTEXT.md`
- `docs/DECISIONS.md`
- `docs/CHANGELOG_DEV.md` (this entry)

**Verified.**
- `npm run build` clean. Routes: `/` (40.1 kB / 213 kB First Load — up from 151 kB; the +62 kB is `posthog-js`), `/agents` (175 kB), `/market-map` (175 kB), `/api/waitlist`. No type or lint errors.
- `posthog-js` and `posthog-node` correctly added to `frontend/package.json` only (no stray root-level install — a stray root `package.json`/`node_modules`/`package-lock.json` was created on the first install attempt because the shell cwd was the repo root; cleaned up and re-installed in `frontend/`).

**Follow-ups.**
- User must set `NEXT_PUBLIC_POSTHOG_KEY` (`phc_...` from us.posthog.com → Project settings → Project API Key) and `NEXT_PUBLIC_POSTHOG_HOST=https://us.posthog.com` in Vercel (Production + Preview + Development), then redeploy. Until then the production build runs but no events are sent.
- After the first prod deploy with the key set, do a live smoke test: open `https://canhav-agentmarketplace.vercel.app` in an incognito window, navigate `/` → `/market-map` → `/agents`, submit the waitlist form on one of them, then confirm in PostHog → Activity that you see `$pageview` × 3 and `waitlist_submitted` × 1, and that the person profile is keyed by the email you submitted.
- Remaining em-dash sweep: ~10 component files still contain em dashes per ripgrep (`frontend/app/{market-map,agents}/page.tsx`, `frontend/components/landing/{WaitlistForm,Features,FAQ,AgentNetwork,ValueProps}.tsx`, `frontend/components/layout/ComingSoonShell.tsx`, `frontend/lib/api.ts`). Per the copy rule, replace these opportunistically when touching those files for other reasons.
- Phase 2 (deferred): LLM Analytics + Logs. Wire `posthog-node` LLM tracing into the M10 Agents pillar, set up OTLP log capture when we have a backend log surface worth shipping.
- When we eventually upgrade to Next.js 15.3+ (no current plan), migrate from the `PostHogProvider` component to `instrumentation-client.ts` per PostHog's current Next.js docs.

---

## 2026-05-17 12:15 — M6(fix): Stat copy + reposition network labels

**Why.** Live review tweaks after v2.

**What changed.**
- `components/landing/Hero.tsx` — third stat value: "Agent Marketplace powered by Arbitrum" → "Agentic Economy".
- `components/landing/AgentNetwork.tsx` — `ON-CHAIN RAILS` moved bottom-right → bottom-left; restored the `● LIVE` signal pip in bottom-right (signal-400).

**Files.** `frontend/components/landing/Hero.tsx`, `frontend/components/landing/AgentNetwork.tsx`, `docs/CHANGELOG_DEV.md`.

**Verified.** `npm run build` clean.

---

## 2026-05-17 12:10 — M6(fix): Homepage copy pass v2 (wordmark, headline, stat, network labels)

**Why.** User reviewed the deployed M6.2 homepage and asked for a second copy pass after seeing it live.

**What changed.**
- `components/ui/Logo.tsx` — wordmark "CanHav" → "CanHav Research" (matches the parent brand and the Substack at `research.canhav.com`).
- `components/landing/Hero.tsx`:
  - Headline rewritten to **"The builder intelligence for shipping <gradient>web3 products</gradient> with <gradient>AI agents</gradient>."** (two gradient phrases instead of one).
  - Third stat strip value: "Arbitrum" → "Agent Marketplace powered by Arbitrum" (label still "Marketplace").
- `components/landing/AgentNetwork.tsx` — re-added three corner labels in the same mono/uppercase format as before: top-left `AGENT INTELLIGENCE`, top-right `WEB3 MARKET MAP`, bottom-right `ON-CHAIN RAILS`. (Bottom-left intentionally empty per user spec; previous `● live` pip removed.)

**Files.** `frontend/components/ui/Logo.tsx`, `frontend/components/landing/Hero.tsx`, `frontend/components/landing/AgentNetwork.tsx`, `docs/CHANGELOG_DEV.md`.

**Verified.** `npm run build` clean (`/` 40 kB / 151 kB First Load).

**Follow-ups.** The new third-stat string is long ("Agent Marketplace powered by Arbitrum") and may wrap on narrow viewports — keep an eye on it on mobile. If it looks bad we can split label/value differently or move it out of the stat strip.

---

## 2026-05-17 11:55 — M6.2: Custom brand assets wired + landing copy refresh

**Why.** Closes out M6. The user supplied real brand assets (logo, mark, favicon, Apple touch icon, Android icons, OG image) and asked for a homepage copy/structure pass at the same time. Goal of this milestone is a single `M6: Custom brand assets + Instantly E2E verified` commit that ships both the assets and the copy changes the user dictated.

**What changed.**

Brand assets:
- Added user-supplied files in `frontend/public/`: `logo.svg`, `mark.svg`, `favicon.png`, `icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `og-image.png`. (Note: favicon is `.png`, not `.ico`.)
- Removed stray `.DS_Store` from `frontend/public/`.
- `components/ui/Logo.tsx` — replaced the placeholder gradient "C" tile with `<Image src="/mark.svg" />` (28×28, `priority`). Kept the soft electric blur halo and the "CanHav" wordmark.
- `app/layout.tsx` — added `metadata.icons` (`favicon.png`, `icon-192`, `icon-512`, `apple-touch-icon`), and added `openGraph.images` + `twitter.images` pointing at `/og-image.png` (1200×630). Description now matches the new sub-headline so OG/Twitter previews and the `<meta name="description">` are consistent.

Copy + structure (homepage review):
- `components/landing/Hero.tsx` — headline rewritten to **"Turn web3 research into products your <gradient>agents can help ship</gradient>."** Sub rewritten to "Use CanHav to research blockchain ecosystems, train smarter agents, and turn AI agent workflows into products that can be deployed and monetized on-chain."
- `components/landing/SocialProof.tsx` — kept the "Built by researchers shipping across the ecosystem" eyebrow, removed the chain wordmark strip (ETHEREUM/ARBITRUM/BASE/SOLANA/OPTIMISM/POLYGON) — we don't have real partnerships with any of those L1/L2s yet, so claiming them implicitly is misleading.
- `components/landing/AgentNetwork.tsx` — removed the three left/top/bottom corner labels (`agent_net::v0`, `arbitrum`, `00 nodes online`). Kept only the bottom-right `● live` status pip.
- `components/landing/ValueProps.tsx` — third card body: "Arbitrum marketplace" → "Agent Marketplace" (we don't want to over-commit to the chain in homepage copy, and "Agent Marketplace" matches the name we'll use in M11).
- `lib/utils.ts` — `SITE.tagline` updated to match new headline. `SITE.socials.github` removed; `SITE.socials.linkedin` added (`https://www.linkedin.com/in/wazarat`). `SITE.socials.x` updated to `https://x.com/wazarat` (was `https://x.com/canhav_research`, which doesn't exist).
- `components/layout/Footer.tsx` — Connect column: GitHub icon swapped for LinkedIn icon (`lucide-react`'s `Linkedin`), now linking to the new `SITE.socials.linkedin`. Twitter icon now goes to the new `SITE.socials.x`.

**Files.**
- `frontend/public/{logo.svg,mark.svg,favicon.png,icon-192.png,icon-512.png,apple-touch-icon.png,og-image.png}` (new, user-supplied)
- `frontend/components/ui/Logo.tsx`
- `frontend/app/layout.tsx`
- `frontend/components/landing/Hero.tsx`
- `frontend/components/landing/SocialProof.tsx`
- `frontend/components/landing/AgentNetwork.tsx`
- `frontend/components/landing/ValueProps.tsx`
- `frontend/components/layout/Footer.tsx`
- `frontend/lib/utils.ts`
- `docs/CHANGELOG_DEV.md` (this entry)

**Verified.**
- `npm run build` clean. Routes: `/` (39.9 kB / 151 kB First Load), `/agents`, `/market-map`, `/api/waitlist`. No type or lint errors.
- `curl https://canhav-backend.onrender.com/api/health` → `200 {"ok":true,"service":"canhav-backend","instantly_configured":true}` — confirms the M6.1 production E2E path is still live before we ship the brand changes.
- M6.1 already proved real Instantly leads from production for `landing` / `market-map` / `agents` sources (lead IDs in the previous changelog entry).

**Follow-ups.**
- After this push, visually confirm in a Twitter / Slack / iMessage share preview that `og-image.png` renders at 1200×630 (Twitter caches aggressively — use [cards-dev.twitter.com/validator](https://cards-dev.twitter.com/validator) if needed).
- M7 kickoff (analytics vendor decision: PostHog vs Plausible vs Vercel Analytics vs GA4) is the next milestone.
- Consider replacing the current `Logo.tsx` `<Image>` with the larger `logo.svg` (full wordmark) anywhere we want a hero-sized logo — right now we only use the square `mark.svg` in the nav/footer, which is correct.

---

## 2026-05-15 12:05 — M6 Step 0 + M6.1: Roadmap rolled forward, production E2E verified

**Why.** M5 was marked "configs ready" but never proven against production Instantly. The user has now finished the Vercel + Render deploy steps, supplied the production `ALLOWED_ORIGINS` value, and confirmed they want to continue from a fresh context. Need to (a) prove the live stack actually creates Instantly leads end-to-end, (b) reflect the new M6 → M11 roadmap in all docs, and (c) capture the live URLs as ground truth for the next agent.

**What changed.**
- **README.md** — Updated milestone table: M5 ✅ (was ⏳), reframed M6 as "Brand + E2E verified", inserted M7 (analytics), M8 (Supabase Market Map), M9 (auth + Substack paid sync), M10 (Agents pillar + skill files), and renumbered the on-chain marketplace as M11. Added a new "Live URLs" subsection with the Vercel + Render production URLs and a note about the planned `canhav.com` custom domain.
- **docs/AI_CONTEXT.md** — Updated section 1 (status line: M0–M5 done, M6 in progress, marketplace renumbered M11), section 6 (env vars table now lists the actual production `ALLOWED_ORIGINS` value and `NEXT_PUBLIC_API_BASE_URL`, plus a "Production deploys" note), and section 8 (milestone protocol now points to README for the new M6 → M11 plan and notes that M5 is verified).
- **docs/DECISIONS.md** — Two new entries: (1) "Roadmap renumbered: Marketplace is now M11, with M6–M10 in between" with full rationale and the rejected alternatives; (2) "M5 production deploy verified end-to-end" recording the actual `/api/health` response, the three live `lead_id`s returned by production submissions, and the ALLOWED_ORIGINS value as deployed.

**Files.**
- `README.md`
- `docs/AI_CONTEXT.md`
- `docs/DECISIONS.md`
- `docs/CHANGELOG_DEV.md` (this entry)

**Verified.**
- `curl https://canhav-backend.onrender.com/api/health` → `200 {"ok":true,"service":"canhav-backend","instantly_configured":true}` in 179ms (warm).
- `curl -XPOST https://canhav-agentmarketplace.vercel.app/api/waitlist` with `source: landing` → `200 {"ok":true,"lead_id":"019e2c62-445e-738a-8382-ec17b5811b58"}`.
- Same with `source: market-map` → `200 {"ok":true,"lead_id":"019e2c62-e46d-7efa-b8df-074ad1f60b61"}`.
- Same with `source: agents` → `200 {"ok":true,"lead_id":"019e2c62-e650-760b-8831-6058c219bbcd"}`.
- All three should appear in the configured Instantly campaign with `custom_variables.source` matching the call. **User must visually confirm in the Instantly UI** that the three `verify-*@canhav.com` rows landed with the right `source` and `role` tags.

**Follow-ups.**
- M6.2 — wire user-supplied brand assets (logo, mark, favicon, OG image) into `frontend/public/brand/`, `Logo.tsx`, and `layout.tsx` metadata. Blocked on the user dropping the asset files in the workspace.
- M6.3 — single commit `M6: Custom brand assets + Instantly E2E verified`, push to main, confirm Vercel auto-deploy and that the OG image renders in a Twitter / Slack share preview.
- Open decision (deferred to M9 kickoff): mechanism for syncing Substack paid subscribers — CSV upload vs Zapier vs Stripe webhook.
- Open decision (deferred to M7 kickoff): analytics vendor — PostHog (recommended for product analytics + privacy posture) vs Plausible (lightest) vs Vercel Analytics (zero-config) vs GA4.
- Open decision (deferred to M10 kickoff): exact schema for "skill `.md` files" (frontmatter fields, where they live in the repo, how the marketplace surfaces them).

---

## 2026-05-15 11:25 — Add persistent agent memory in `docs/`

**Why.** Chat context windows hit ~100% during long sessions and the next agent (or the user re-opening the project later) loses everything. Persisting context inside the repo solves this.

**What changed.**
- Created `docs/AI_CONTEXT.md` — the bootstrapping doc for any agent: project purpose, architecture, repo layout, tech stack, design system cheat-sheet, env vars, dev commands, milestone protocol, commit convention, and explicit "do this before/after changes" rules.
- Created `docs/DECISIONS.md` — append-only architectural decision log, seeded with the 8 locked-in choices made during M0–M5 (Render-not-Vercel for backend, Instantly-as-source-of-truth, cyber/dark aesthetic, hand-rolled UI primitives, CSS-keyframe hero, honeypot for spam, milestone gating, the `docs/` system itself).
- Created this file (`docs/CHANGELOG_DEV.md`).

**Files.**
- `docs/AI_CONTEXT.md` (new)
- `docs/DECISIONS.md` (new)
- `docs/CHANGELOG_DEV.md` (new)

**Verified.** Files render correctly (markdown). No code changes, so no build needed.

**Follow-ups.**
- Consider adding a top-level note in `README.md` pointing agents at `docs/AI_CONTEXT.md`.
- Consider a Cursor rule (`.cursor/rules/`) that auto-loads `docs/AI_CONTEXT.md` and `docs/DECISIONS.md` at the start of every session.

---

## 2026-05-15 11:15 — Rewrite git history under user identity (`wazarat <wazarat@outlook.com>`)

**Why.** All M0–M5 commits were authored as `CanHav Dev <dev@canhav.com>` (the in-session default). User wants every commit attributed to their GitHub account `wazarat`.

**What changed.**
- Ran `git filter-branch --env-filter` to rewrite `GIT_AUTHOR_*` and `GIT_COMMITTER_*` for all 6 commits to `wazarat / wazarat@outlook.com`.
- Set local repo `.git/config` `user.name=wazarat` and `user.email=wazarat@outlook.com` so future commits use the right identity automatically.
- Force-pushed `main` with `--force-with-lease` to overwrite remote history.

**Files.** None (history rewrite + git config only).

**Verified.** `git log --pretty=format:'%h %an <%ae>'` shows all 6 commits authored by `wazarat <wazarat@outlook.com>`. GitHub remote updated (forced update from `7f49f73` → `f75dbbe`).

**Follow-ups.**
- User must add `wazarat@outlook.com` to verified emails on github.com/settings/emails for GitHub to attribute commits to the profile (avatar, "verified" badge, contribution graph).
- User should set `git config --global user.name wazarat` + `git config --global user.email wazarat@outlook.com` if they want this identity in other repos too. Not done by the agent (would touch global config).

---

## 2026-05-15 11:09 — M5 + M6 deployment scaffolding

**Why.** Make the production deploy a 5-minute task instead of an investigation.

**What changed.**
- `frontend/vercel.json` — Next.js framework config + security headers (X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy).
- `DEPLOYMENT.md` — full runbook: push, deploy backend on Render via `render.yaml`, deploy frontend on Vercel with `Root Directory=frontend` + `NEXT_PUBLIC_API_BASE_URL`, custom domain wiring (apex/www → Vercel, `research.canhav.com` already on Substack, optional `api.canhav.com` → Render), end-to-end smoke test steps.
- `.github/workflows/ci.yml` — Frontend job runs `typecheck`, `lint`, `build`. Backend job installs requirements and import-checks the FastAPI app.
- `contracts/README.md` — placeholder doc for M6: target Foundry stack, planned contracts (`AgentRegistry`, `AgentListing`, `Escrow`, `MarketplaceRouter`), Arbitrum Sepolia → Arbitrum One roadmap, and frontend integration plan via wagmi/RainbowKit.
- Removed `contracts/.gitkeep`.

**Files.** `frontend/vercel.json`, `DEPLOYMENT.md`, `.github/workflows/ci.yml`, `contracts/README.md`, `contracts/.gitkeep` (deleted).

**Verified.** `npm run build` passes. `git push -u origin main` succeeded.

**Follow-ups.** User completes the live Vercel + Render deploy. (In-progress at the time of writing — see top of file.)

---

## 2026-05-15 11:01 — M4: Three-tab navigation (Research external, Market Map + Agents placeholders)

**Why.** Need to wire the three nav tabs to real destinations even though Market Map and Agents are not built yet.

**What changed.**
- `frontend/components/layout/ComingSoonShell.tsx` — shared layout for placeholder pages (eyebrow, gradient title, description, badge chips, bullet grid, embedded `WaitlistForm` with the right `source` tag, "Back to home" link).
- `frontend/app/market-map/page.tsx` — uses the shell. Source = `market-map`. Sector badges: Infra/DeFi/AI Agents/Wallets/Identity/Data.
- `frontend/app/agents/page.tsx` — uses the shell. Source = `agents`. Badges: Bring-your-own-model/Evals/Datasets/Arbitrum payments.
- Both pages have unique `<title>` + `<description>` metadata.
- Research nav item was already wired (external link in `Nav.tsx`, `target="_blank"`).

**Files.** `frontend/components/layout/ComingSoonShell.tsx` (new), `frontend/app/market-map/page.tsx` (replaced skeleton), `frontend/app/agents/page.tsx` (replaced skeleton).

**Verified.** `npm run build` passes (both routes prerender static, 2.55 kB each). Browser-tested via cursor-ide-browser — both pages render the cyber/dark layout, the form, and the "Back to home" link.

**Follow-ups.** Build the actual Market Map UI when product is ready; train + ship agent training stack for the Agents page.

---

## 2026-05-15 10:55 — M3: Polished landing page (the centerpiece)

**Why.** Most important milestone — converts visitors to waitlist signups.

**What changed.** Eight new components composed in `frontend/app/page.tsx`:
- `Hero.tsx` — headline ("The fastest path from idea to **shipped, monetized** AI agent."), sub, dual CTAs (Join the waitlist / Read research), 3 stat strips. Uses CSS-keyframe `animate-fade-in-up` (NOT framer-motion `initial`) so above-fold content is visible without JS.
- `AgentNetwork.tsx` — decorative animated SVG of a central "agent" node connected to 8 satellite nodes, slowly rotating, with shimmering edges. Uses Framer Motion (only place in the hero that does).
- `SocialProof.tsx` — wordmark strip (Ethereum/Arbitrum/Base/Solana/Optimism/Polygon).
- `ValueProps.tsx` — 3-up grid (Ship faster / Trained agents / Monetize on-chain) with gradient icon tiles.
- `Features.tsx` — 3 alternating left/right feature blocks (Research / Market Map / Agents), each with a custom mock visual and a CTA link to the relevant tab.
- `Roadmap.tsx` — vertical timeline (Step 01 Live → 04 Later) with status pills.
- `WaitlistSection.tsx` + `WaitlistForm.tsx` — anchored at `#waitlist`. Form: email + role chips (Web3 dev / AI dev / Both) + submit. Honeypot `company` field, 1.5s submit throttle, sonner toasts, success-state collapse to a confirmation row.
- `FAQ.tsx` — 6-item accordion (CSS-grid-rows trick for height animation).
- Refactored `Button` to support `asChild` properly via `React.cloneElement` (so `<Button asChild><a>...</a></Button>` doesn't render `<button><a>...</a></button>`).

**Files.** All under `frontend/components/landing/`, plus `frontend/app/page.tsx`, `frontend/components/ui/Button.tsx`.

**Verified.** Browser-tested end-to-end via cursor-ide-browser at `http://localhost:3030`: hero renders, scroll through value props/features/roadmap looks correct, form submission triggers backend call, button enters loading state, error toast shown when Instantly is unconfigured (expected). `npm run build` clean.

**Follow-ups.** Replace the placeholder logo wordmarks with real partner logos when available. Add a real Lighthouse run in CI.

---

## 2026-05-15 10:50 — M2: Next.js 14 frontend shell + cyber/dark design system

**Why.** Need a polished foundation before building the landing page.

**What changed.**
- Scaffolded Next.js 14.2.35 (App Router, TS strict, Tailwind 3.4) by hand (no `create-next-app` boilerplate).
- Custom Tailwind palette: `ink-{50..950}`, `electric-{400..700}`, `neon-{400..600}`, `signal-{400,500}`. Custom keyframes (`fade-in-up`, `blob`, `pulse-soft`, `shimmer`, `float`).
- Global CSS utilities in `app/globals.css`: `.glass`, `.glass-strong`, `.grid-bg`, `.glow-ring`, `.btn-glow`, `.text-gradient-brand`, `.noise`.
- Layout: `Background.tsx` (animated grid + 3 colored blurred blobs), sticky `Nav.tsx` (logo, 3 links, "Join waitlist" CTA, mobile menu, scroll-aware compaction), `Footer.tsx` (3 columns + socials + copyright).
- UI primitives: `Button.tsx`, `Input.tsx`, `Card.tsx`, `Logo.tsx`. (Hand-rolled, not shadcn — see DECISIONS.md.)
- Skeleton routes: `/`, `/market-map`, `/agents`.
- `/api/waitlist/route.ts` — proxy to backend so the browser never deals with CORS or the backend URL.
- Bumped Next.js from initial 14.2.18 → 14.2.35 to clear an upstream security advisory.

**Files.** Whole `frontend/` tree.

**Verified.** `npm run build` clean. Browser-tested locally.

**Follow-ups.** None — moved straight to M3.

---

## 2026-05-15 10:47 — M1: FastAPI backend with Instantly.ai waitlist endpoint

**Why.** Need a real backend that can push leads into Instantly so the landing page form actually does something.

**What changed.**
- `backend/app/main.py` — FastAPI app, CORS from `ALLOWED_ORIGINS` env, mounts `/api/health` + waitlist router.
- `backend/app/schemas.py` — `WaitlistSignup` (email + role + source + honeypot `company`), `WaitlistResponse`, `HealthResponse`.
- `backend/app/services/instantly.py` — async httpx client for `POST https://api.instantly.ai/api/v2/leads` with Bearer auth, `campaign` + `custom_variables`, `skip_if_in_workspace=true`. Custom `InstantlyError` with `status_code` + `body`.
- `backend/app/routes/waitlist.py` — handles honeypot (silent 200), maps Instantly 4xx to soft 200, 5xx to our own 502 with friendly copy.
- `backend/requirements.txt` — fastapi 0.115.5, uvicorn[standard] 0.32.1, httpx 0.28.1, pydantic[email] 2.10.3, python-dotenv 1.0.1.
- `backend/render.yaml` — blueprint (free plan, healthcheck `/api/health`, all secrets `sync: false`).
- `backend/.env.example`, `backend/README.md`.

**Files.** Whole `backend/` tree.

**Verified.** Started locally on port 8765, `curl /api/health` returns ok, `curl /api/waitlist` validates email and 502s gracefully when no Instantly key configured.

**Follow-ups.** None — moved to M2.

---

## 2026-05-15 10:46 — M0: Bootstrap monorepo

**Why.** Start of the project.

**What changed.** Created `frontend/`, `backend/`, `contracts/`, `.github/workflows/` directories, `README.md` with milestone roadmap, `LICENSE` (MIT), `.gitignore` covering Node/Python/Solidity/IDE artifacts. Initial commit on `main`.

**Files.** `README.md`, `LICENSE`, `.gitignore`, `frontend/.gitkeep`, `backend/.gitkeep`, `contracts/.gitkeep`.

**Verified.** `git init && git commit` succeeded.

**Follow-ups.** None — proceeded to M1.
