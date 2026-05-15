# CanHav Agent Marketplace

> The fastest path from idea to shipped, monetized AI agent.

CanHav Research helps web3 and AI agent developers cut through noise — research, infra, and a marketplace to monetize what you build. This monorepo houses the new CanHav site and the foundation for the upcoming on-chain AI agent marketplace on Arbitrum.

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

| # | Milestone | Status | Exit criteria |
|---|-----------|--------|---------------|
| 0 | Repo bootstrap | ✅ | Repo + monorepo skeleton created |
| 1 | Backend + Instantly waitlist | ✅ | `POST /api/waitlist` pushes leads into Instantly.ai |
| 2 | Frontend shell + cyber/dark design system | ✅ | Next.js shell with nav, footer, three skeleton routes |
| 3 | Landing page | ✅ | Hero, value props, feature blocks, roadmap, waitlist form, FAQ |
| 4 | Three tabs | ✅ | Research (external), Market Map, Agents — all working |
| 5 | Deploy to Vercel + Render | ⏳ | Public URL live, end-to-end waitlist works in production |
| 6 | On-chain marketplace (Arbitrum) | 🔜 | Solidity contracts + wallet connect + listings |

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

- **Frontend:** Next.js 14, Tailwind, shadcn/ui, Framer Motion. Dark cyber aesthetic.
- **Backend:** FastAPI + httpx. One endpoint today (`POST /api/waitlist`) that creates an Instantly lead with `source` + `role` custom variables.
- **Email capture:** Instantly.ai REST API. No DB on day one — Instantly is the source of truth.
- **Future on-chain layer:** Solidity contracts on Arbitrum Sepolia testnet, wallet connect via wagmi/RainbowKit.

## Deployment

- **Frontend (Vercel):** Import this repo, set root to `frontend/`, set env `NEXT_PUBLIC_API_BASE_URL` to the Render URL.
- **Backend (Render):** New web service, root `backend/`, env `INSTANTLY_API_KEY`, `INSTANTLY_CAMPAIGN_ID`, `ALLOWED_ORIGINS`. `render.yaml` is provided.

## License

MIT. See [LICENSE](./LICENSE).
