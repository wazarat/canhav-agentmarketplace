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

Today (M0–M5) the repo ships a polished landing page + waitlist that captures interest in all three pillars. The on-chain marketplace (M6) is intentionally not built yet.

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
├── contracts/               # Solidity (M6 — empty placeholder, README only)
│   └── README.md                       # Plans for Foundry + AgentRegistry/Listing/Escrow/Router on Arbitrum Sepolia
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
- Fonts: **Inter** (sans), **Space Grotesk** (display), **JetBrains Mono** (mono) — all via `next/font/google`.

### Backend

- **FastAPI 0.115.5** + **uvicorn[standard]** on Python 3.11.
- **httpx 0.28** (async) for outbound calls to Instantly.
- **pydantic[email] 2.10** for validation.
- One endpoint that matters: `POST /api/waitlist`.
- Deployed on **Render** (free plan), not on Vercel. See DECISIONS.md.

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

## 6. Environment variables

| Where | Name | Required | Purpose |
|-------|------|----------|---------|
| Render (backend) | `INSTANTLY_API_KEY` | yes | Instantly.ai bearer token |
| Render (backend) | `INSTANTLY_CAMPAIGN_ID` | yes | Campaign UUID for waitlist leads |
| Render (backend) | `ALLOWED_ORIGINS` | yes | Comma-separated CORS origins (include the Vercel preview URL) |
| Render (backend) | `ENVIRONMENT` | no | `production` / `development` |
| Vercel (frontend) | `NEXT_PUBLIC_API_BASE_URL` | yes | Public Render URL (e.g. `https://canhav-backend.onrender.com`) |

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

We work milestone-by-milestone. **Do not start a new milestone until the previous one's exit criteria are met.** See `README.md` for the milestone table. Current status as of latest commit: M0–M5 done (M5 = deploy configs ready; user is currently in the Vercel deploy step). M6 (Arbitrum marketplace) is intentionally not started.

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
