# AI Context — canhav-agentmarketplace

> **Read this file first.** It is the persistent memory for any AI agent working in this repo. Pair it with [`DECISIONS.md`](./DECISIONS.md) for the *why* and [`CHANGELOG_DEV.md`](./CHANGELOG_DEV.md) for the *what just happened*.
>
> **After making changes, update [`CHANGELOG_DEV.md`](./CHANGELOG_DEV.md).** Always.

---

## 1. What is this project?

**CanHav Agent Marketplace** is the new website for [CanHav Research](https://research.canhav.com), positioning CanHav as the fastest path from idea to shipped, monetized AI agent — for **web3 + AI agent developers**.

The end-state is a three-pillar product:

1. **Research** — weekly research drops (already lives on Substack at `research.canhav.com`).
2. **Market Map** — searchable map of hundreds of projects across the blockchain ecosystem.
3. **Agents** — bring-your-own-model agent training stack + an on-chain marketplace where specialized AI agents transact with each other on **Arbitrum**.

Today (M0–M5 done, M6 in progress) the repo ships a polished landing page + waitlist live in production at [`canhav-agentmarketplace.vercel.app`](https://canhav-agentmarketplace.vercel.app), backed by [`canhav-backend.onrender.com`](https://canhav-backend.onrender.com), creating real leads in Instantly.ai. The on-chain marketplace is now **M11** — see the milestone table in `README.md` for the full M6 → M11 plan.

## 2. Architecture (one-liner)

```
Visitor → Vercel (Next.js 14, App Router)
        ├─ /api/waitlist proxy → Render (FastAPI) → Instantly.ai (lead created)
        └─ external link → research.canhav.com (Substack)

Future: contracts/ → Arbitrum Sepolia → Marketplace UI in /marketplace
```

## 3. Repo layout (canonical)

```
canhav-agentmarketplace/
├── frontend/                # Next.js 14 (App Router) — Vercel root
│   ├── app/
│   │   ├── layout.tsx                  # Root layout (fonts, nav, footer, background, toaster)
│   │   ├── page.tsx                    # Landing page (composes 7 landing components)
│   │   ├── market-map/page.tsx         # Coming-soon page (Market Map)
│   │   ├── agents/page.tsx             # Coming-soon page (Agents)
│   │   ├── api/waitlist/route.ts       # POST proxy → backend
│   │   └── globals.css                 # Tailwind base + custom utilities (glass, grid-bg, btn-glow)
│   ├── components/
│   │   ├── landing/                    # Hero, AgentNetwork, SocialProof, ValueProps, Features,
│   │   │                               # Roadmap, WaitlistSection, WaitlistForm, FAQ
│   │   ├── layout/                     # Nav, Footer, Background, ComingSoonShell
│   │   ├── providers/                  # PostHogProvider (+ PostHogPageView) — App Router analytics
│   │   └── ui/                         # Button (with asChild), Input, Card, Logo
│   ├── lib/
│   │   ├── api.ts                      # submitWaitlist(), WaitlistRole/Source types
│   │   └── utils.ts                    # cn() helper, SITE constants (urls, socials)
│   ├── public/
│   ├── tailwind.config.ts              # Custom palette (ink/electric/neon/signal), keyframes
│   ├── next.config.mjs
│   ├── vercel.json                     # Security headers, framework=nextjs
│   ├── .env.local.example
│   └── package.json                    # Next 14.2.35, React 18.3.1, Tailwind 3.4, Framer Motion 11
│
├── backend/                 # FastAPI — Render root
│   ├── app/
│   │   ├── main.py                     # FastAPI app, CORS, mounts /api/health + waitlist router
│   │   ├── schemas.py                  # WaitlistSignup (email/role/source/honeypot), WaitlistResponse
│   │   ├── routes/waitlist.py          # POST /api/waitlist, honeypot handling, error mapping
│   │   └── services/instantly.py       # Instantly.ai v2 leads API client (POST /api/v2/leads)
│   ├── requirements.txt                # fastapi, uvicorn, httpx, pydantic[email], python-dotenv
│   ├── render.yaml                     # Blueprint (free plan, healthcheck=/api/health)
│   ├── .env.example
│   └── README.md
│
├── contracts/               # Solidity (M11 — empty placeholder, README only)
│   └── README.md                       # Plans for Foundry + AgentRegistry/Listing/Escrow/Router on Arbitrum Sepolia
│
├── supabase/                # M8 — Postgres schema + seed for the Market Map data store
│   └── migrations/                     # `<timestamp>_<name>.sql` files, applied via Supabase CLI or MCP apply_migration
│
├── .cursor/skills/market-map/  # M8 — repo-local Claude Skill: how to extend the Market Map
│   ├── SKILL.md                        # entry skill (audited: visibility / determinism / composability)
│   ├── scripts/                        # deterministic CLIs: fetch_sheet, normalize_row, validate_schema, upsert_projects, ingest_subsector, add_sector, add_subsector
│   ├── schemas/                        # JSON Schemas: universal.json + per-sector + per-subsector + column maps
│   └── sectors/<slug>/                 # per-sector SKILL.md + subsectors/<slug>.md reference docs
│
├── .github/workflows/ci.yml # Frontend: typecheck + lint + build. Backend: import smoke test.
├── docs/                    # ← you are here. Persistent agent memory.
│   ├── AI_CONTEXT.md
│   ├── DECISIONS.md
│   └── CHANGELOG_DEV.md
├── DEPLOYMENT.md            # Step-by-step Render + Vercel runbook
├── README.md                # Public-facing project README + milestone status
├── LICENSE                  # MIT
└── .gitignore
```

## 4. Tech stack (locked-in, see DECISIONS.md for *why*)

### Frontend

- **Next.js 14.2.35** App Router, TypeScript strict, deployed on Vercel.
- **Tailwind 3.4** + custom `tailwindcss-animate`. Dark-only theme.
- **Custom design system** (no shadcn yet — we build minimal components in `components/ui/`).
- **Framer Motion 11** for the agent-network SVG animation only. Hero uses CSS keyframes (`animate-fade-in-up`) so content is visible without JS.
- **Sonner** for toasts.
- **lucide-react** for icons.
- **clsx + tailwind-merge** for className composition (`cn()` in `lib/utils.ts`).
- **posthog-js** (+ `posthog-js/react`) for product + web analytics. Initialised in `components/providers/PostHogProvider.tsx` (client) and wrapped in `app/layout.tsx`. SDK requests are proxied through Next.js rewrites at `/ingest/*` → `us.i.posthog.com` (configured in `next.config.mjs`) so ad blockers don't drop events. App Router pageviews fire from `components/providers/PostHogPageView.tsx` (`capture_pageview` is off on init).
- Fonts: **Inter** (sans), **Space Grotesk** (display), **JetBrains Mono** (mono) — all via `next/font/google`.

### Backend

- **FastAPI 0.115.5** + **uvicorn[standard]** on Python 3.11.
- **httpx 0.28** (async) for outbound calls to Instantly **and** to Supabase PostgREST.
- **pydantic[email] 2.10** for validation.
- **jsonschema 4.23** for the M8 ingest-pipeline validator at `.cursor/skills/market-map/scripts/validate_schema.py`.
- Endpoints that matter: `POST /api/waitlist`, and the M8 read-only `/api/market-map/*` family (sectors, subsectors, projects).
- Deployed on **Render** (free plan), not on Vercel. See DECISIONS.md.

### Market Map data store (M8)

- **Supabase Postgres** with three core tables — `sectors`, `subsectors`, `projects` — and two convenience views (`sector_summary`, `subsector_summary`).
- 3-tier project schema: typed universal columns + `sector_attributes jsonb` + `subsector_attributes jsonb`. JSONB shapes are documented in `sectors.common_field_schema` and `subsectors.specific_field_schema` (JSON Schema). See DECISIONS.md entry **M8 Market Map: sector-by-sector rollout with 3-tier JSONB schema**.
- RLS: anon role has SELECT only. All writes happen via the service-role key, exclusively from the ingest scripts under `.cursor/skills/market-map/scripts/` — never from the live web request path.
- Source data: 7 public Google Sheets (one workbook per sector). Pulled via the `gviz/tq?tqx=out:csv` endpoint — no Sheets API creds required.

### Email capture

- **Instantly.ai** API v2: `POST https://api.instantly.ai/api/v2/leads` with `Authorization: Bearer ${INSTANTLY_API_KEY}` and a `campaign` UUID.
- We pass `source` (landing/market-map/agents) and `role` (web3/ai/both) as `custom_variables` so Instantly can segment.
- We set `skip_if_in_workspace: true` to avoid duplicate leads.
- 4xx upstream errors are silently mapped to a 200 success on our side (so we never tell a visitor "you're already on the list" or leak info to bots). 5xx → our own 502 with a friendly message.

## 5. Design system cheat-sheet

Always import classes through Tailwind, never inline hex.

```
Colors:
  ink-{50,100,300,500,700,800,850,900,950}   # neutrals (bg = ink-950)
  electric-{400,500,600,700}                  # primary blue (#3D7BFF)
  neon-{400,500,600}                          # secondary purple (#8B5CF6)
  signal-{400,500}                            # accent cyan (#22D3EE)

Custom utilities (defined in app/globals.css):
  .glass / .glass-strong   # backdrop-blur surfaces
  .grid-bg                 # animated grid background
  .glow-ring               # soft outer ring + drop shadow
  .btn-glow                # primary button glow
  .text-gradient-brand     # blue → violet → cyan gradient text
  .noise                   # 4% opacity SVG noise overlay (use ::before)

Animations (tailwind.config.ts):
  animate-fade-in-up       # 0.6s opacity+translate, forwards (USE THIS for above-fold content)
  animate-blob             # slow drift for ambient blobs
  animate-pulse-soft       # gentle opacity pulse
  animate-shimmer          # gradient sweep
  animate-float
```

**Rule**: above-the-fold content must be visible without JS. Use Tailwind keyframe animations (`animate-fade-in-up`), NOT framer-motion `initial={{ opacity: 0 }}`, for hero copy.

**Copy rule (2026-05-17)**: avoid em dashes (`—`) in user-facing copy. Use a colon, period, or parenthetical instead. The shared-link `<title>` in `app/layout.tsx` uses `:` (e.g. `CanHav: Turn web3 research into products…`). When you edit a landing component, replace any em dashes you find with a colon, comma, or period if it doesn't change meaning. Documentation and code comments may still use them.

## 6. Environment variables

| Where | Name | Required | Purpose |
|-------|------|----------|---------|
| Render (backend) | `INSTANTLY_API_KEY` | yes | Instantly.ai bearer token |
| Render (backend) | `INSTANTLY_CAMPAIGN_ID` | yes | Campaign UUID for waitlist leads |
| Render (backend) | `ALLOWED_ORIGINS` | yes | Comma-separated CORS origins. **Production value:** `http://localhost:3000,https://canhav.com,https://www.canhav.com,https://canhav-agentmarketplace-5cxv27582-wazarats-projects.vercel.app,https://canhav-agentmarketplace.vercel.app` |
| Render (backend) | `SUPABASE_URL` | yes (M8+) | Supabase project URL (`https://<ref>.supabase.co`). If unset, `/api/market-map/*` returns 503. |
| Render (backend) | `SUPABASE_ANON_KEY` | yes (M8+) | Anon (publishable) key. Used by FastAPI for read-only PostgREST calls. |
| Render (backend) | `SUPABASE_SERVICE_ROLE_KEY` | optional | Service-role key. Required only if you run the ingest scripts from the Render shell. Local dev usually keeps this in `backend/.env` only. NEVER ship to the frontend. |
| Render (backend) | `ENVIRONMENT` | no | `production` / `development` |
| Vercel (frontend) | `NEXT_PUBLIC_API_BASE_URL` | yes | Public Render URL — **production value:** `https://canhav-backend.onrender.com` |
| Vercel (frontend) | `NEXT_PUBLIC_POSTHOG_KEY` | yes (prod) | PostHog project token (`phc_...`). If missing, the provider logs a warning and no-ops. |
| Vercel (frontend) | `NEXT_PUBLIC_POSTHOG_HOST` | yes (prod) | UI host for in-app links. Use `https://us.posthog.com` (US Cloud) or `https://eu.posthog.com`. Event ingestion goes through the `/ingest` rewrite to `us.i.posthog.com` regardless. |

**Production deploys (M5 verified 2026-05-15):**
- Frontend: https://canhav-agentmarketplace.vercel.app
- Backend: https://canhav-backend.onrender.com (`/api/health` → `{"ok":true,"instantly_configured":true}`)
- Custom domain `canhav.com` is whitelisted in CORS but DNS is not yet pointed.

The frontend's `/api/waitlist/route.ts` reads `NEXT_PUBLIC_API_BASE_URL` (or falls back to `API_BASE_URL` server-side, then `http://localhost:8000` for local).

## 7. Local dev

```bash
# backend (terminal 1)
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # fill in INSTANTLY_API_KEY + INSTANTLY_CAMPAIGN_ID
uvicorn app.main:app --reload --port 8000

# frontend (terminal 2)
cd frontend
cp .env.local.example .env.local  # NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
npm install
npm run dev
# → http://localhost:3000
```

If the dev server hits `EMFILE: too many open files` on macOS, raise the limit (`ulimit -n 4096`) or use `npm run build && npm run start` instead.

## 8. Milestone protocol

We work milestone-by-milestone. **Do not start a new milestone until the previous one's exit criteria are met.** See `README.md` for the milestone table. Current status: M0–M7 done. M8 (Market Map, Supabase-backed) is decomposed into M8.1–M8.11 — see the active plan under `.cursor/plans/m8_market_map_*.plan.md` and the [`docs/DECISIONS.md`](./DECISIONS.md) entry **M8 Market Map: sector-by-sector rollout with 3-tier JSONB schema** for the rationale. Marketplace remains M11.

### How to add a Market Map sector or subsector (M8+)

The full guide lives in [.cursor/skills/market-map/SKILL.md](../.cursor/skills/market-map/SKILL.md). Quick reference:

1. Scaffold skill stubs locally: `python .cursor/skills/market-map/scripts/add_subsector.py --sector <sector-slug> --slug <new-slug> --name "Display Name" --sheet-id <id> --gid <gid>`.
2. Add the row to a new `supabase/migrations/<timestamp>_<name>.sql`. Apply via Supabase CLI or the Supabase MCP `apply_migration`.
3. Edit `.cursor/skills/market-map/schemas/subsectors/<slug>.json` + `.column_map.json` to declare the subsector's field shape.
4. Dry-run ingest: `python .cursor/skills/market-map/scripts/ingest_subsector.py --slug <slug> --dry-run`.
5. Drop `--dry-run` to commit to Supabase. The script is idempotent — re-running won't duplicate rows.

## 9. Commit convention

`M<N>: <Verb> <thing>` for milestone commits.
For follow-up tweaks within an existing milestone use `M<N>(fix): ...` or `M<N>(refactor): ...`.
For changes that span milestones or are infra/docs, use `chore:`, `docs:`, `ci:` prefixes.

All commits must be authored by `wazarat <wazarat@outlook.com>` (the user's account). The local repo `.git/config` already enforces this.

## 10. What to do before you make changes

1. Read this file (you're here). Re-read sections 4 (stack), 5 (design system), and 8 (milestone protocol).
2. Read [`DECISIONS.md`](./DECISIONS.md) — never re-litigate a decision listed there without explicit user approval.
3. Skim the latest entries in [`CHANGELOG_DEV.md`](./CHANGELOG_DEV.md) so you know what was last touched and why.
4. Then plan your change. If it conflicts with a decision, **ask** before deviating.

## 11. What to do after you make changes

1. Run/verify locally if non-trivial (`npm run build` for frontend; `python -c "from app.main import app"` for backend).
2. Commit with a message that follows section 9.
3. **Append an entry to [`CHANGELOG_DEV.md`](./CHANGELOG_DEV.md)** — what changed, why, files modified, follow-ups. This is non-negotiable. The next agent will rely on it.
4. If you made an architectural decision (e.g. picked a library, changed an API contract, traded off X for Y), also add a row to [`DECISIONS.md`](./DECISIONS.md).
