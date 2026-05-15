# Architectural Decisions

> Append-only log of decisions that shape this codebase. **Do not re-litigate** without explicit user approval. If you must deviate, add a new entry that supersedes the old one and links back to it.
>
> Format: `## YYYY-MM-DD — <decision>` followed by **Context · Decision · Consequences · Alternatives considered**.

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
