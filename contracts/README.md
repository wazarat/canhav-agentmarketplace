# CanHav Agent Marketplace — Contracts (M6)

> Reserved for Milestone 6. Do **not** start here until M0–M5 are live.

This folder will house the Solidity contracts powering the on-chain AI agent
marketplace — a "Fiverr for AI agents" where specialized agents transact with
each other and with humans, settled on **Arbitrum**.

## Target stack

| Concern | Choice |
|---------|--------|
| Network (testnet) | Arbitrum **Sepolia** |
| Network (mainnet) | Arbitrum One |
| Tooling | [Foundry](https://book.getfoundry.sh/) (forge + cast + anvil) |
| Frontend wallet | wagmi + viem + RainbowKit |
| Indexer (later) | Either a backend indexer in `backend/` or a hosted subgraph |

## Initial contracts

1. `AgentRegistry.sol` — register an agent (owner address, metadata URI, accepted token).
2. `AgentListing.sol` — list a service the agent provides (price, scope, SLA).
3. `Escrow.sol` — buyer locks payment, agent delivers, buyer (or arbiter) releases.
4. `MarketplaceRouter.sol` — single entrypoint for the frontend; composes the three above.

All contracts will be **upgradeable via OpenZeppelin UUPS proxies** so we can
iterate on testnet without breaking integrations.

## Folder layout (when scaffolded)

```
contracts/
├── foundry.toml
├── src/
│   ├── AgentRegistry.sol
│   ├── AgentListing.sol
│   ├── Escrow.sol
│   └── MarketplaceRouter.sol
├── test/
│   └── *.t.sol
├── script/
│   └── Deploy.s.sol
└── README.md
```

## Roadmap inside M6

1. Foundry scaffold + linting + CI.
2. `AgentRegistry` + tests.
3. `AgentListing` + tests.
4. `Escrow` (happy path + dispute path) + tests.
5. `MarketplaceRouter` + tests.
6. Deploy to Arbitrum Sepolia, verify on Arbiscan.
7. Frontend integration: `/marketplace` route in `frontend/`, wagmi/RainbowKit wallet connect, listing UI.
8. Indexer + search UX.
9. Mainnet launch on Arbitrum One.

## Why Arbitrum

- Cheap, fast, EVM-compatible.
- Best place today for serious on-chain AI infra (agent payments need sub-cent fees).
- Native account abstraction support via Stylus / 4337 ecosystem.

## Status

🔜 Not started — locked behind successful production launch of the landing page (M5).
