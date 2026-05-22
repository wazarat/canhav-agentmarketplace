-- M8.14 — Sector 4 (DeFi Systems Architecture) JSON schemas.
--
-- Storage strategy: A (per chat decision 2026-05-22, Sector 4 plan). Every protocol / product
-- is ONE row in public.projects. Per-protocol enum / snapshot / note fields go into
-- subsector_attributes JSONB. Eleven sector-common keys go into sector_attributes
-- (maintaining_organization, parent_organization, protocol_status_text/enum, launch_year,
-- governance_model_text/enum, reason_for_inclusion, practitioner_note,
-- practitioner_validation_check, historical_stress_text, systemic_importance_text/enum).
--
-- Cross-subsector orgs (Ether.fi, Synthetix, Notional, dYdX, Swell) get ONE row in
-- public.organizations and N rows in public.projects (one per product surface). The sheet
-- already encodes the split. NO writes to public.subsector_memberships for DeFi v1.
--
-- NO new sidecar tables, NO new views, NO _merge_sector*_view extension. The Sector 2
-- read-path bug class is structurally impossible under this architecture. Mirrors the
-- M8.11 Monetary precedent exactly.

-- ---------------------------------------------------------------------------
-- 1. Sector-common schema on public.sectors
-- ---------------------------------------------------------------------------

update public.sectors
   set common_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/sectors/defi-systems-architecture.json",
  "title": "DeFi Systems Architecture — sector_attributes",
  "description": "Fields shared by every subsector in DeFi Systems Architecture. Strategy A: pure JSONB on public.projects; cross-subsector entity reuse is modeled as multiple projects rows sharing a maintaining_organization slug. NO sidecar tables, NO _merge_sector_view extension.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "maintaining_organization": { "title": "Maintaining organization", "type": "string", "description": "Raw display name from the source sheet. The typed projects.maintaining_organization FK column carries the resolved org slug." },
    "parent_organization": { "title": "Parent organization", "type": "string", "description": "Brand name for cross-subsector orgs (Ether.fi, Synthetix, Notional Finance, dYdX, Swell)." },
    "protocol_status_text": { "title": "Protocol status — source text", "type": "string" },
    "protocol_status_enum": { "title": "Protocol status", "type": "string", "enum": ["active", "active-legacy", "deprecated", "restricted", "forked", "migrated", "sunset", "wind-down"] },
    "launch_year": { "title": "Launch year", "type": ["integer", "null"], "minimum": 2014, "maximum": 2100 },
    "launch_year_text": { "title": "Launch year — source text", "type": "string" },
    "reason_for_inclusion": { "title": "Reason for inclusion", "type": "string" },
    "practitioner_note": { "title": "Practitioner note", "type": "string", "description": "Source header has smart-quote U+2019, normalized to ASCII at ingest." },
    "practitioner_validation_check": { "title": "Practitioner validation check", "type": "string" },
    "governance_model_text": { "title": "Governance model — source text", "type": "string" },
    "governance_model_enum": { "title": "Governance model", "type": "string", "enum": ["dao-token", "multisig", "immutable", "hybrid", "foundation-council", "single-party", "unknown"] },
    "historical_stress_text": { "title": "Historical stress events / behavior", "type": "string" },
    "systemic_importance_text": { "title": "Systemic importance / risk exposure — source text", "type": "string" },
    "systemic_importance_enum": { "title": "Systemic importance", "type": "string", "enum": ["extreme", "high", "medium-high", "medium", "low-medium", "low", "unknown"] },
    "version_label": { "title": "Version label", "type": "string" },
    "smart_quote_normalized": { "title": "Smart quote normalized", "type": "boolean" },
    "data_refreshed_at": { "title": "Data refreshed at", "type": "string", "format": "date-time" },
    "validation_confidence": { "title": "Validation confidence", "type": "string", "enum": ["verified", "provisional", "self-reported"] }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'defi-systems-architecture';

-- ---------------------------------------------------------------------------
-- 2. Lending Markets — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/lending-markets.json",
  "title": "Lending Markets — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "lending_architecture_text": { "title": "Lending architecture — source text", "type": "string" },
    "lending_architecture_enum": { "title": "Lending architecture", "type": "string", "enum": ["pooled", "isolated-pools", "cdp", "p2p-matched", "permissioned-credit", "rwa-credit", "nft-collateral", "protocol-to-protocol", "cross-collateral"] },
    "collateral_class_text": { "title": "Collateral types — source text", "type": "string" },
    "collateral_class_enum": { "title": "Collateral classes accepted", "type": "array", "items": { "type": "string", "enum": ["volatile-crypto", "stablecoin", "lst", "lrt", "rwa", "nft", "permissioned-off-chain", "synthetic"] } },
    "credit_issuance_mechanism": { "title": "Credit issuance mechanism", "type": "string" },
    "interest_rate_model_text": { "title": "Interest rate model — source text", "type": "string" },
    "interest_rate_model_enum": { "title": "Interest rate model", "type": "string", "enum": ["utilization-kink", "adaptive-curve", "governance-set", "pi-controller", "fixed-fee-no-irm", "peer-matched-rate", "auction-based", "off-chain-negotiated"] },
    "liquidation_mechanism_text": { "title": "Liquidation mechanism — source text", "type": "string" },
    "liquidation_mechanism_enum": { "title": "Liquidation mechanism", "type": "string", "enum": ["fixed-discount-keeper", "dutch-auction", "stability-pool", "redemption-arb", "permissioned-workout", "nft-auction", "oracle-only-no-keeper"] },
    "oracle_dependencies_text": { "title": "Oracle dependencies — source text", "type": "string" },
    "oracle_providers_enum": { "title": "Oracle providers", "type": "array", "items": { "type": "string", "enum": ["chainlink", "uniswap-v3-twap", "redstone", "pyth", "maker-oracle-module", "api3", "custom-protocol-oracle"] } },
    "risk_isolation_text": { "title": "Risk isolation — source text", "type": "string" },
    "risk_isolation_enum": { "title": "Risk isolation model", "type": "string", "enum": ["global-pool", "e-mode-segmented", "isolated-per-market", "per-cdp-isolated", "per-pool-permissioned"] },
    "primary_role_in_defi": { "title": "Primary role in DeFi", "type": "string" },
    "upstream_dependencies_text": { "title": "Upstream dependencies", "type": "string" },
    "downstream_consumers_text": { "title": "Downstream consumers", "type": "string" },
    "parameter_control_text": { "title": "Parameter control — source text", "type": "string" },
    "parameter_control_enum": { "title": "Parameter control", "type": "string", "enum": ["dao-only", "risk-steward-delegated", "guardian-multisig", "immutable", "curator-per-market"] },
    "dependency_concentration_risk_text": { "title": "Dependency concentration risk", "type": "string" },
    "tvl_usd_snapshot": { "title": "TVL (USD) — snapshot", "type": ["number", "null"] },
    "tvl_usd_snapshot_as_of_date": { "title": "TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "borrows_usd_snapshot": { "title": "Borrows (USD) — snapshot", "type": ["number", "null"] },
    "borrows_usd_snapshot_as_of_date": { "title": "Borrows (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "utilization_avg_snapshot": { "title": "Average utilization — snapshot", "type": ["number", "null"], "minimum": 0, "maximum": 1 },
    "utilization_avg_snapshot_as_of_date": { "title": "Utilization snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'lending-markets';

-- ---------------------------------------------------------------------------
-- 3. DEXs & Liquidity Protocols — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/dexs-liquidity-protocols.json",
  "title": "DEXs & Liquidity Protocols — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "dex_architecture_text": { "title": "DEX architecture — source text", "type": "string" },
    "dex_architecture_enum": { "title": "DEX architecture", "type": "string", "enum": ["cpmm", "clamm", "stable-invariant", "weighted-pool", "orderbook-onchain", "orderbook-hybrid", "batch-auction", "experimental-invariant"] },
    "dex_architecture_enum_secondary": { "title": "DEX architecture — secondary", "type": ["string", "null"], "enum": ["cpmm", "clamm", "stable-invariant", "weighted-pool", "orderbook-onchain", "orderbook-hybrid", "batch-auction", "experimental-invariant", null] },
    "execution_mechanism_text": { "title": "Execution mechanism — source text", "type": "string" },
    "execution_mechanism_enum": { "title": "Execution mechanism", "type": "string", "enum": ["swap-against-pool", "swap-against-orderbook", "solver-batch-settlement", "rfq-against-market-maker", "aggregated-routing"] },
    "price_discovery_method_text": { "title": "Price discovery — source text", "type": "string" },
    "price_discovery_method_enum": { "title": "Price discovery method", "type": "string", "enum": ["amm-curve", "orderbook-matching", "solver-competition", "rfq", "dynamic-active-lp"] },
    "lp_model_text": { "title": "Liquidity provider model — source text", "type": "string" },
    "lp_model_enum": { "title": "Liquidity provider model", "type": "string", "enum": ["passive-full-range", "passive-concentrated", "active-concentrated", "professional-mm-only", "solver-supplied"] },
    "capital_efficiency_text": { "title": "Capital efficiency — source text", "type": "string" },
    "capital_efficiency_enum": { "title": "Capital efficiency design", "type": "string", "enum": ["none-full-range", "static-concentration", "dynamic-concentration", "invariant-specialized", "vault-curated"] },
    "primary_trading_pairs": { "title": "Primary trading pairs", "type": "string" },
    "oracle_usage_text": { "title": "Oracle usage — source text", "type": "string" },
    "serves_as_oracle_for_others": { "title": "Serves as oracle for others", "type": ["boolean", "null"] },
    "mev_exposure_text": { "title": "MEV exposure — source text", "type": "string" },
    "mev_exposure_profile_enum": { "title": "MEV exposure profile", "type": "string", "enum": ["sandwich-vulnerable", "jit-vulnerable", "mev-resistant-batched", "mev-internalized", "private-orderflow", "low-mev-orderbook"] },
    "integration_footprint": { "title": "Integration footprint", "type": "string" },
    "fee_control_text": { "title": "Fee control — source text", "type": "string" },
    "fee_tier_model_enum": { "title": "Fee tier model", "type": "string", "enum": ["single-global", "multi-tier-static", "dynamic", "governance-set-per-pool", "solver-priced", "pool-owner-set"] },
    "historical_stress_behavior_text": { "title": "Historical stress behavior", "type": "string" },
    "dependency_concentration_risk_text": { "title": "Dependency concentration risk", "type": "string" },
    "tvl_usd_snapshot": { "title": "TVL (USD) — snapshot", "type": ["number", "null"] },
    "tvl_usd_snapshot_as_of_date": { "title": "TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "volume_24h_usd_snapshot": { "title": "24h volume (USD) — snapshot", "type": ["number", "null"] },
    "volume_24h_usd_snapshot_as_of_date": { "title": "24h volume snapshot — as of", "type": ["string", "null"], "format": "date" },
    "fees_24h_usd_snapshot": { "title": "24h fees (USD) — snapshot", "type": ["number", "null"] },
    "fees_24h_usd_snapshot_as_of_date": { "title": "24h fees snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'dexs-liquidity-protocols';

-- ---------------------------------------------------------------------------
-- 4. Yield & Structured Markets — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/yield-structured-markets.json",
  "title": "Yield & Structured Markets — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "yield_model_text": { "title": "Yield model — source text", "type": "string" },
    "yield_model_enum": { "title": "Yield model", "type": "string", "enum": ["aggregated-multi-strategy", "yield-tokenization-pt-yt", "fixed-rate-term", "tranched-senior-junior", "structured-options-vault", "actively-managed-vault", "lst-yield-product", "hybrid"] },
    "strategy_scope": { "title": "Strategy scope", "type": "string" },
    "underlying_yield_sources_text": { "title": "Underlying yield sources — source text", "type": "string" },
    "yield_source_enum": { "title": "Underlying yield sources", "type": "array", "items": { "type": "string", "enum": ["lending-interest", "dex-lp-fees", "lst-staking", "restaking-avs-rewards", "governance-token-emissions", "derivatives-funding", "options-premium", "real-world-assets", "protocol-fee-share"] } },
    "strategy_management_text": { "title": "Strategy management — source text", "type": "string" },
    "strategy_management_enum": { "title": "Strategy management", "type": "string", "enum": ["smart-contract-only", "dao-strategist-committee", "professional-curator", "off-chain-solver", "permissionless-curators"] },
    "rebalancing_logic_text": { "title": "Rebalancing logic — source text", "type": "string" },
    "rebalancing_logic_enum": { "title": "Rebalancing logic", "type": "string", "enum": ["permissionless-keeper", "dao-strategist-triggered", "solver-decided-off-chain", "automatic-invariant", "manual-curator", "no-rebalance-terminal"] },
    "capital_lockups_text": { "title": "Capital lockups — source text", "type": "string" },
    "capital_lockups_enum": { "title": "Capital lockups", "type": "string", "enum": ["none-instant-withdraw", "epoch-withdrawal", "fixed-term-maturity", "cooldown-period", "governance-set-lockup"] },
    "risk_transformation_text": { "title": "Risk transformation — source text", "type": "string" },
    "risk_transformation_enum": { "title": "Risk transformation", "type": "array", "items": { "type": "string", "enum": ["principal-loss-possible", "principal-protected-senior", "levered-junior", "fixed-return-pre-maturity", "variable-return-long-yield", "cap-on-upside", "delta-neutral"] } },
    "principal_protection_text": { "title": "Principal protection — source text", "type": "string" },
    "principal_protection_enum": { "title": "Principal protection", "type": "string", "enum": ["none", "senior-tranche", "coverage-pool", "insurance-purchased", "principal-token-pre-maturity"] },
    "leverage_usage_text": { "title": "Leverage usage — source text", "type": "string" },
    "leverage_usage_enum": { "title": "Leverage usage", "type": "string", "enum": ["none", "internal-borrowing", "external-lending-loop", "derivatives-funding", "yield-multiplying"] },
    "upstream_dependencies_text": { "title": "Upstream dependencies", "type": "string" },
    "downstream_consumers_text": { "title": "Downstream consumers", "type": "string" },
    "strategy_change_control_text": { "title": "Strategy change control — source text", "type": "string" },
    "strategy_change_control_enum": { "title": "Strategy change control", "type": "string", "enum": ["dao-vote-required", "strategist-decision", "multisig-approved", "smart-contract-only-immutable-per-vault"] },
    "historical_stress_behavior_text": { "title": "Historical stress behavior", "type": "string" },
    "dependency_concentration_risk_text": { "title": "Dependency concentration risk", "type": "string" },
    "tvl_usd_snapshot": { "title": "TVL (USD) — snapshot", "type": ["number", "null"] },
    "tvl_usd_snapshot_as_of_date": { "title": "TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "apy_current_snapshot": { "title": "Current APY — snapshot", "type": ["number", "null"] },
    "apy_current_snapshot_as_of_date": { "title": "Current APY snapshot — as of", "type": ["string", "null"], "format": "date" },
    "apy_30d_avg_snapshot": { "title": "30d avg APY — snapshot", "type": ["number", "null"] },
    "apy_30d_avg_snapshot_as_of_date": { "title": "30d avg APY snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'yield-structured-markets';

-- ---------------------------------------------------------------------------
-- 5. Liquid Staking Tokens — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/liquid-staking-tokens.json",
  "title": "Liquid Staking Tokens (LSTs) — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "lst_token_name": { "title": "LST token name / ticker", "type": "string" },
    "token_standard": { "title": "Token standard", "type": "string" },
    "rebasing_model_text": { "title": "Rebasing model — source text", "type": "string" },
    "lst_token_model_enum": { "title": "LST token model", "type": "string", "enum": ["rebasing", "reward-bearing-non-rebasing", "dual-token-split", "vault-wrapper"] },
    "claim_type": { "title": "Claim type", "type": "string" },
    "validator_operator_model_text": { "title": "Validator/operator model — source text", "type": "string" },
    "custody_model_enum": { "title": "Custody model", "type": "string", "enum": ["dao-curated-operators", "permissionless-node-operators", "custodial", "protocol-managed-operators", "vault-per-operator", "dvt-distributed-keys", "infra-provider"] },
    "validator_selection_governance": { "title": "Validator selection & governance", "type": "string" },
    "slashing_risk_bearer_text": { "title": "Slashing risk bearer — source text", "type": "string" },
    "slashing_risk_bearer_enum": { "title": "Slashing risk bearer", "type": "string", "enum": ["token-holder-proportional", "operator-bond-first", "custodian-absorbs", "protocol-insurance-pool", "vault-operator-isolated"] },
    "primary_liquidity_venues": { "title": "Primary liquidity venues", "type": "string" },
    "redemption_mechanism_text": { "title": "Redemption mechanism — source text", "type": "string" },
    "redemption_mechanism_enum": { "title": "Redemption mechanism", "type": "string", "enum": ["in-protocol-burn-with-queue", "dex-only", "instant-via-buffer-or-swap-secondary", "custodian-redemption"] },
    "exit_liquidity_risk": { "title": "Exit liquidity risk", "type": "string" },
    "accepted_as_collateral_text": { "title": "Accepted as collateral — source text", "type": "string" },
    "dex_liquidity_depth": { "title": "DEX liquidity depth", "type": "string" },
    "oracle_availability": { "title": "Oracle availability", "type": "string" },
    "upgrade_admin_controls": { "title": "Upgrade / admin controls", "type": "string" },
    "validator_concentration_risk_text": { "title": "Validator concentration risk", "type": "string" },
    "governance_centralization_risk_text": { "title": "Governance centralization risk", "type": "string" },
    "historical_stress_behavior_text": { "title": "Historical stress behavior", "type": "string" },
    "dependency_concentration_risk_text": { "title": "Dependency concentration risk", "type": "string" },
    "tvl_usd_snapshot": { "title": "TVL (USD) — snapshot", "type": ["number", "null"] },
    "tvl_usd_snapshot_as_of_date": { "title": "TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "staked_eth_snapshot": { "title": "Staked ETH — snapshot", "type": ["number", "null"] },
    "staked_eth_snapshot_as_of_date": { "title": "Staked ETH snapshot — as of", "type": ["string", "null"], "format": "date" },
    "market_share_pct_snapshot": { "title": "Market share % — snapshot", "type": ["number", "null"], "minimum": 0, "maximum": 100 },
    "market_share_pct_snapshot_as_of_date": { "title": "Market share % snapshot — as of", "type": ["string", "null"], "format": "date" },
    "validator_count_snapshot": { "title": "Validator count — snapshot", "type": ["integer", "null"], "minimum": 0 },
    "validator_count_snapshot_as_of_date": { "title": "Validator count snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'liquid-staking-tokens';

-- ---------------------------------------------------------------------------
-- 6. Restaking Systems — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/restaking-systems.json",
  "title": "Restaking Systems — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "restaking_model_text": { "title": "Restaking model — source text", "type": "string" },
    "restaking_model_enum": { "title": "Restaking model", "type": "string", "enum": ["eth-native-restaking", "lst-restaking", "hybrid-native-and-lst", "not-applicable"] },
    "restaking_role_enum": { "title": "Restaking role (gating archetype)", "type": "string", "enum": ["platform", "avs-consumer", "lrt-issuer", "hybrid"], "description": "CRITICAL gating field per v10 handoff §9." },
    "security_scope_text": { "title": "Security scope — source text", "type": "string" },
    "security_scope_enum": { "title": "Security scope", "type": "string", "enum": ["general-purpose-platform", "single-avs-specific", "lrt-aggregator-multi-avs", "selective-avs"] },
    "opt_in_mechanism_text": { "title": "Opt-in mechanism — source text", "type": "string" },
    "opt_in_mechanism_enum": { "title": "Opt-in mechanism", "type": "string", "enum": ["operator-opts-in-per-avs", "depositor-delegates-to-operator", "lrt-aggregator-decides", "network-owner-decides"] },
    "slashing_authority_text": { "title": "Slashing authority — source text", "type": "string" },
    "slashing_authority_enum": { "title": "Slashing authority", "type": "string", "enum": ["platform-governance", "avs-governance", "dao-committee", "protocol-immutable"] },
    "slashing_conditions": { "title": "Slashing conditions", "type": "string" },
    "slashing_enforcement_layer_text": { "title": "Slashing enforcement layer — source text", "type": "string" },
    "slashing_enforcement_layer_enum": { "title": "Slashing enforcement layer", "type": "string", "enum": ["eigenlayer-core-contracts", "symbiotic-core-contracts", "per-avs-contracts", "ethereum-consensus-only"] },
    "assets_at_risk_text": { "title": "Assets at risk — source text", "type": "string" },
    "assets_at_risk_enum": { "title": "Assets at risk", "type": "array", "items": { "type": "string", "enum": ["eth-native-stake", "lst-collateral", "lrt-supply", "protocol-token-bond"] } },
    "risk_isolation_text": { "title": "Risk isolation — source text", "type": "string" },
    "risk_isolation_enum": { "title": "Risk isolation", "type": "string", "enum": ["cross-avs-correlated", "per-avs-isolated", "per-lrt-pool-isolated", "network-level-isolated"] },
    "upstream_dependencies_text": { "title": "Upstream dependencies", "type": "string" },
    "downstream_consumers_text": { "title": "Downstream consumers", "type": "string" },
    "parameter_control_text": { "title": "Parameter control — source text", "type": "string" },
    "slashing_contagion_risk_text": { "title": "Slashing contagion risk", "type": "string" },
    "operator_concentration_risk_text": { "title": "Operator concentration risk", "type": "string" },
    "governance_override_risk_text": { "title": "Governance override risk", "type": "string" },
    "historical_stress_behavior_text": { "title": "Historical stress behavior", "type": "string" },
    "restaked_tvl_usd_snapshot": { "title": "Restaked TVL (USD) — snapshot", "type": ["number", "null"] },
    "restaked_tvl_usd_snapshot_as_of_date": { "title": "Restaked TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "restaked_tvl_eth_snapshot": { "title": "Restaked TVL (ETH) — snapshot", "type": ["number", "null"] },
    "restaked_tvl_eth_snapshot_as_of_date": { "title": "Restaked TVL (ETH) snapshot — as of", "type": ["string", "null"], "format": "date" },
    "avs_count_snapshot": { "title": "AVS count — snapshot", "type": ["integer", "null"], "minimum": 0 },
    "avs_count_snapshot_as_of_date": { "title": "AVS count snapshot — as of", "type": ["string", "null"], "format": "date" },
    "operator_count_snapshot": { "title": "Operator count — snapshot", "type": ["integer", "null"], "minimum": 0 },
    "operator_count_snapshot_as_of_date": { "title": "Operator count snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'restaking-systems';

-- ---------------------------------------------------------------------------
-- 7. Synthetic & Derivatives — subsector_attributes schema
-- ---------------------------------------------------------------------------

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/synthetic-derivatives.json",
  "title": "Synthetic & Derivatives — subsector_attributes",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "derivative_archetype_text": { "title": "Derivative archetype — source text", "type": "string" },
    "derivative_archetype_enum": { "title": "Derivative archetype (gating)", "type": "string", "enum": ["perpetual-futures", "options", "synthetic-assets", "rate-swap", "dated-futures", "prediction-market", "exotic-payoff"] },
    "underlying_exposure_text": { "title": "Underlying exposure — source text", "type": "string" },
    "underlying_exposure_enum": { "title": "Underlying exposure", "type": "array", "items": { "type": "string", "enum": ["single-asset-price", "basket-or-index", "interest-rate", "volatility", "event-based", "multi-asset-portfolio"] } },
    "payoff_structure_text": { "title": "Payoff structure — source text", "type": "string" },
    "payoff_structure_enum": { "title": "Payoff structure", "type": "string", "enum": ["linear-perp", "vanilla-option", "american-option", "exotic-parameterized", "synthetic-1to1", "fixed-vs-variable-rate"] },
    "margin_model_text": { "title": "Margin model — source text", "type": "string" },
    "margin_model_enum": { "title": "Margin model", "type": "string", "enum": ["isolated-margin", "cross-margin", "portfolio-margin", "full-collateral", "debt-pool-collateralized", "pool-backed-no-individual-margin"] },
    "collateral_types": { "title": "Collateral types", "type": "string" },
    "counterparty_model_text": { "title": "Counterparty model — source text", "type": "string" },
    "counterparty_model_enum": { "title": "Counterparty model", "type": "string", "enum": ["traders-vs-traders-orderbook", "traders-vs-pool", "traders-vs-vamm", "traders-vs-debt-pool", "option-buyer-vs-pool-lp", "option-buyer-vs-option-writer-amm"] },
    "liquidation_mechanism_text": { "title": "Liquidation mechanism — source text", "type": "string" },
    "liquidation_mechanism_enum": { "title": "Liquidation mechanism", "type": "string", "enum": ["margin-ratio-keeper", "oracle-triggered-automatic", "funding-driven-liquidation", "option-expiry-settlement", "pool-socialized-loss", "debt-pool-socialized-loss"] },
    "pricing_source_text": { "title": "Pricing source — source text", "type": "string" },
    "pricing_source_enum": { "title": "Pricing source", "type": "array", "items": { "type": "string", "enum": ["orderbook-match", "oracle-fed", "vamm-curve", "optimistic-oracle", "iv-curve-amm"] } },
    "funding_premium_logic_text": { "title": "Funding / premium logic — source text", "type": "string" },
    "funding_rate_design_enum": { "title": "Funding rate design", "type": "string", "enum": ["continuous-funding", "periodic-8h-funding", "pool-imbalance-fee", "n-a"] },
    "settlement_type_text": { "title": "Settlement type — source text", "type": "string" },
    "settlement_type_enum": { "title": "Settlement type", "type": "string", "enum": ["cash-stablecoin", "cash-underlying", "physical-delivery", "synth-burn-mint", "oracle-priced-at-expiry"] },
    "upstream_dependencies_text": { "title": "Upstream dependencies", "type": "string" },
    "downstream_consumers_text": { "title": "Downstream consumers", "type": "string" },
    "risk_parameter_control_text": { "title": "Risk parameter control — source text", "type": "string" },
    "liquidation_cascade_risk_text": { "title": "Liquidation cascade risk", "type": "string" },
    "oracle_dependency_risk_text": { "title": "Oracle dependency risk", "type": "string" },
    "governance_override_risk_text": { "title": "Governance override risk", "type": "string" },
    "historical_stress_behavior_text": { "title": "Historical stress behavior", "type": "string" },
    "volume_24h_usd_snapshot": { "title": "24h volume (USD) — snapshot", "type": ["number", "null"] },
    "volume_24h_usd_snapshot_as_of_date": { "title": "24h volume snapshot — as of", "type": ["string", "null"], "format": "date" },
    "open_interest_usd_snapshot": { "title": "Open interest (USD) — snapshot", "type": ["number", "null"] },
    "open_interest_usd_snapshot_as_of_date": { "title": "Open interest snapshot — as of", "type": ["string", "null"], "format": "date" },
    "tvl_usd_snapshot": { "title": "TVL (USD) — snapshot", "type": ["number", "null"] },
    "tvl_usd_snapshot_as_of_date": { "title": "TVL (USD) snapshot — as of", "type": ["string", "null"], "format": "date" }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'synthetic-derivatives';

-- ---------------------------------------------------------------------------
-- 8. Pre-seed cross-subsector organizations
--
-- The 5 brands below each have N products across multiple DeFi subsectors. We
-- create one organizations row per brand here so the ingest script can resolve
-- maintaining_organization to a stable slug for all N projects rows. Other orgs
-- (Aave DAO, Compound DAO, MakerDAO, Lido, etc.) are created on-demand by the
-- ingest script's _ensure_org helper, matching the Monetary precedent.
-- ---------------------------------------------------------------------------

insert into public.organizations (slug, display_name, entity_type, website_url)
values
  ('ether-fi',         'Ether.fi',         'company', 'https://ether.fi'),
  ('synthetix',        'Synthetix',        'dao',     'https://synthetix.io'),
  ('notional-finance', 'Notional Finance', 'company', 'https://notional.finance'),
  ('dydx',             'dYdX',             'company', 'https://dydx.exchange'),
  ('swell',            'Swell',            'company', 'https://swellnetwork.io')
on conflict (slug) do nothing;

-- ---------------------------------------------------------------------------
-- Done. NO new tables, NO new views, NO indexes, NO RLS changes, NO trigger
-- changes. The frontend's existing /api/market-map/projects/<slug> route reads
-- the JSONB blobs untouched; PROSE_FIELDS additions ship in the frontend PR.
-- ---------------------------------------------------------------------------
