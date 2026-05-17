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
