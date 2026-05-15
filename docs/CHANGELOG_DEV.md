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
