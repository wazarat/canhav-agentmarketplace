# CanHav Agent Marketplace

> The fastest path from idea to shipped, monetized AI agent.

CanHav Research helps web3 and AI agent developers cut through noise — research, infra, and a marketplace to monetize what you build. This monorepo houses the new CanHav site and the foundation for the upcoming on-chain AI agent marketplace on Arbitrum.

## For AI agents / future contributors

Persistent context lives in [`docs/`](./docs):

- [`docs/AI_CONTEXT.md`](./docs/AI_CONTEXT.md) — read this first. Project purpose, stack, conventions.
- [`docs/DECISIONS.md`](./docs/DECISIONS.md) — locked-in architectural decisions. Don't re-litigate without approval.
- [`docs/CHANGELOG_DEV.md`](./docs/CHANGELOG_DEV.md) — append-only log of what changed and why. **Update this after every meaningful change.**

## Monorepo layout

```
canhav-agentmarketplace/
├── frontend/    # Next.js 14 (App Router) + TypeScript + Tailwind + shadcn/ui — deployed to Vercel
├── backend/     # Python FastAPI service (Instantly.ai waitlist + future APIs) — deployed to Render
├── contracts/   # Solidity contracts for the on-chain marketplace (Arbitrum Sepolia) — future milestone
└── .github/     # CI workflows
```

## Milestone roadmap

This project is built milestone-by-milestone. Each milestone has explicit exit criteria and we don't move on until it is met.

| #   | Milestone                                  | Status        | Exit criteria                                                                          |
| --- | ------------------------------------------ | ------------- | -------------------------------------------------------------------------------------- |
| 0   | Repo bootstrap                             | ✅            | Repo + monorepo skeleton created                                                       |
| 1   | Backend + Instantly waitlist               | ✅            | `POST /api/waitlist` pushes leads into Instantly.ai                                    |
| 2   | Frontend shell + cyber/dark design system  | ✅            | Next.js shell with nav, footer, three skeleton routes                                  |
| 3   | Landing page                               | ✅            | Hero, value props, feature blocks, roadmap, waitlist form, FAQ                         |
| 4   | Three tabs                                 | ✅            | Research (external), Market Map, Agents — all working                                  |
| 5   | Deploy to Vercel + Render                  | ✅            | Public URL live, end-to-end waitlist creates real Instantly leads                      |
| 6   | Brand (logo, favicon, OG) + E2E verified   | ✅            | Custom logo/favicon/OG image shipped, 3 production source-tagged leads in Instantly    |
| 7   | Analytics + privacy                        | ✅            | PostHog Product + Web Analytics wired through the `/ingest` proxy                      |
| 8   | Market Map (Supabase, sector-by-sector)    | ⏳            | All 7 sectors live at `/market-map` with real, sheet-sourced projects in prod          |
| 9   | Auth + roles + Substack paid sync          | 🔜            | Supabase Auth, user profiles, paid-subscriber sync from Substack, admin dashboard      |
| 10  | Agents pillar + skill files                | 🔜            | Agent profile pages, submit-an-agent form, skill `.md` schema defined                  |
| 11  | On-chain marketplace (Arbitrum Sepolia)    | 🔜            | Foundry contracts (`AgentRegistry`, `Listing`, `Escrow`), wagmi/RainbowKit, indexer    |

### M8 sub-milestones (in progress)

M8 is decomposed into 11 sub-milestones so we ship one sector at a time. See the active plan in `.cursor/plans/` and the [`docs/DECISIONS.md`](./docs/DECISIONS.md) entry for the full rationale.

| #     | Sub-milestone                                                | Status |
| ----- | ------------------------------------------------------------ | ------ |
| M8.1  | Supabase schema + seed sectors/subsectors                    | ⏳ (migrations written, project provisioning pending) |
| M8.2  | FastAPI `/api/market-map/*` read-only routes                 | ✅ (live behind `SUPABASE_*` env vars) |
| M8.3  | `/market-map` UI (sector grid + sector + subsector + project)| ✅ (renders against the API; graceful warming-up state) |
| M8.4  | `.cursor/skills/market-map/` bootstrap + scripts             | ✅ (entry SKILL.md, 7 sector + 36 subsector stubs, deterministic scripts) |
| M8.5  | Pilot sector — Core Protocol Architecture                    | 🔜 |
| M8.6  | Rollup & Scaling Frameworks (L3 sheet flagged for cleanup)   | 🔜 |
| M8.7  | Monetary & Access Rails                                      | 🔜 |
| M8.8  | DeFi Systems Architecture                                    | 🔜 |
| M8.9  | Data & Consensus Infrastructure                              | 🔜 |
| M8.10 | Advanced Compute & Integration                               | 🔜 |
| M8.11 | Governance & Enterprise Framework                            | 🔜 |

### Live URLs

- **Frontend (Vercel):** [`canhav-agentmarketplace.vercel.app`](https://canhav-agentmarketplace.vercel.app)
- **Backend (Render):** [`canhav-backend.onrender.com`](https://canhav-backend.onrender.com) — health: [`/api/health`](https://canhav-backend.onrender.com/api/health)
- **Custom domain:** `canhav.com` (planned — already whitelisted in backend `ALLOWED_ORIGINS`)

## Quick start

### Frontend

```bash
cd frontend
cp .env.local.example .env.local   # set NEXT_PUBLIC_API_BASE_URL
npm install
npm run dev
# http://localhost:3000
```

### Backend

```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env                # set INSTANTLY_API_KEY + INSTANTLY_CAMPAIGN_ID
uvicorn app.main:app --reload --port 8000
# http://localhost:8000/docs
```

## Architecture

```
Visitor → Vercel (Next.js) → Render (FastAPI) → Instantly.ai
                          ↘ research.canhav.com (Substack)
```

- **Frontend:** Next.js 14, Tailwind, hand-rolled UI primitives, Framer Motion. Dark cyber aesthetic.
- **Backend:** FastAPI + httpx. `POST /api/waitlist` creates an Instantly lead; `/api/market-map/*` serves the Market Map data over Supabase PostgREST.
- **Email capture:** Instantly.ai REST API. No DB for the waitlist — Instantly is the source of truth.
- **Market Map data:** Supabase Postgres. 3-tier schema (universal columns + `sector_attributes jsonb` + `subsector_attributes jsonb`). Ingest is sector-by-sector via the deterministic scripts in [`.cursor/skills/market-map/`](./.cursor/skills/market-map/).
- **Future on-chain layer:** Solidity contracts on Arbitrum Sepolia testnet, wallet connect via wagmi/RainbowKit.

## Deployment

- **Frontend (Vercel):** Import this repo, set root to `frontend/`, set env `NEXT_PUBLIC_API_BASE_URL` to the Render URL.
- **Backend (Render):** New web service, root `backend/`, env `INSTANTLY_API_KEY`, `INSTANTLY_CAMPAIGN_ID`, `ALLOWED_ORIGINS`. `render.yaml` is provided.

## License

MIT. See [LICENSE](./LICENSE).
