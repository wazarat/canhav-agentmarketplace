-- M8.11 — Sector 3 (Monetary & Access Rails) JSON schemas.
--
-- Storage strategy: A++ (per chat decision 2026-05-22). Every token / product / rail is
-- ONE row in public.projects. Scalar fields go into subsector_attributes JSONB. Multi-value
-- cells become string arrays in JSONB. Cross-subsector entity reuse is handled by the
-- existing organizations table -- one organizations row, N projects rows. NO sidecar tables,
-- NO new views, NO _merge_sector*_view extension. The Sector 2 read-path bug class is
-- structurally impossible under this architecture.
--
-- ISS-011 (banks/central-banks/multilateral-institutions/foundations as entity_types) is
-- resolved by extending the documentation comment on organizations.entity_type below.

update public.sectors
   set common_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/sectors/monetary-access-rails.json",
  "title": "Monetary & Access Rails — sector_attributes",
  "description": "Fields shared by every subsector in Monetary & Access Rails (Centralized Stablecoins, Decentralized Stablecoins, Synthetic & Yield-Bearing Dollars, Global On-Ramps, Institutional Payment Rails, Regional Payment Networks). Source: Perplexity v9 bundle (canhav-skills-v9). Storage strategy: A++ — pure JSONB on public.projects; cross-subsector entity reuse goes through the existing organizations table via projects.maintaining_organization. NO sidecar tables, NO _merge_sector_view extension.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "maintaining_organization": {
      "title": "Maintaining organization",
      "type": "string",
      "description": "Display-name fallback while the typed projects.maintaining_organization FK populates. Mirrors the source-sheet column header so no ingest data is lost when an org slug is not yet seeded."
    },
    "issuer_legal_entity": {
      "title": "Issuer legal entity",
      "type": "string",
      "description": "Legal entity name from the source sheet (e.g. 'Tether Holdings Limited', 'Circle Internet Financial, LLC'). Distinct from maintaining_organization — same brand, different legal vehicle."
    },
    "hq_full_text": {
      "title": "HQ — full source text",
      "type": "string",
      "description": "Original parenthetical-preserving HQ string per ISS-003 (e.g. 'United States (Delaware-incorporated)', 'British Virgin Islands (holding structure)'). Universal projects.hq_country carries the cleaned country name only."
    },
    "monetary_role": {
      "title": "Monetary role",
      "type": "string",
      "enum": [
        "ingress",
        "representation",
        "circulation",
        "settlement",
        "egress",
        "access+settlement"
      ],
      "description": "Sector-3 universal. Where this entity sits in the value lifecycle. Sourced from Cross-Subsector_Memberships sheet."
    },
    "ethereum_indispensability": {
      "title": "Ethereum indispensability",
      "type": "string",
      "enum": [
        "indispensable",
        "primary-deployment",
        "one-of-many",
        "incidental"
      ],
      "description": "Sector-3 universal. How load-bearing Ethereum is to this entity's core function."
    },
    "primary_monetary_risk": {
      "title": "Primary monetary risk",
      "type": "array",
      "items": {
        "type": "string",
        "enum": [
          "issuer",
          "protocol",
          "strategy",
          "counterparty",
          "banking",
          "regulatory",
          "market",
          "smart-contract",
          "oracle",
          "governance",
          "collateral-quality",
          "liquidity"
        ]
      },
      "description": "Sector-3 universal. The risk axes that dominate this entity's failure modes. The first element is primary, the rest are secondary."
    },
    "validation_confidence": {
      "title": "Validation confidence",
      "type": "string",
      "enum": [
        "verified",
        "provisional",
        "self-reported"
      ],
      "description": "Per-row validation confidence. 'verified' is the default; 'provisional' for entries with weak Ethereum-role evidence (per ISS-017); 'self-reported' where the only source is the entity itself."
    },
    "reason_for_inclusion": {
      "title": "Reason for inclusion",
      "type": "string",
      "description": "Free-form prose explaining why this row passes the subsector's locked validation question. Multi-line; rendered with whitespace-pre-line on the project page."
    },
    "practitioner_note": {
      "title": "Practitioner note",
      "type": "string",
      "description": "Editorial commentary from the CanHav research team. Source column header uses smart-quote U+2019 ('Practitioner’s Note') and is normalized to ASCII at ingest per ISS-001."
    },
    "practitioner_validation_check": {
      "title": "Practitioner validation check",
      "type": "string",
      "description": "Locked yes/no validation question for the subsector, with the answer recorded inline (e.g. 'Does peg stability depend on discretionary offchain redemption by the issuer? Yes')."
    },
    "data_refreshed_at": {
      "title": "Data refreshed at",
      "type": "string",
      "format": "date-time",
      "description": "Timestamp when this row was last reconciled against source-of-truth. Set by the ingest script."
    },
    "data_confidence": {
      "title": "Data confidence",
      "type": "string",
      "examples": [
        "verified",
        "estimate",
        "stale"
      ]
    }
  }
}
$json$::jsonb
 where slug = 'monetary-access-rails';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/centralized-stablecoins.json",
  "title": "Centralized Stablecoins — subsector_attributes",
  "description": "Per-token JSONB fields for fiat-backed, centrally issued digital currencies on Ethereum. Source: CentralizedStablecoins tab in Monetary-and-Access-Rails_cleaned_v1.xlsx (canhav-skills-v9). Strategy A++: scalars + string arrays; complex 1:N data (per-row reserve composition, per-network deployment addresses) is captured as free-text in v1 and deferred to v2.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "ticker": {
      "title": "Ticker",
      "type": "string",
      "description": "Primary token ticker (e.g. 'USDT', 'USDC'). For Monerium token-family rows, this is the comma-joined list (preserved verbatim from source); the tickers array carries the structured form."
    },
    "tickers": {
      "title": "Tickers (token family)",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Set when the row represents a family of tokens (e.g. Monerium EURe / GBPe / ISKe). ticker_family=true must accompany."
    },
    "ticker_family": {
      "title": "Is a token family",
      "type": "boolean"
    },
    "fiat_currency_peg": {
      "title": "Fiat currency peg",
      "type": "string",
      "description": "ISO 4217 where applicable (USD, EUR, GBP, ISK, SGD)."
    },
    "launch_year": {
      "title": "Launch year",
      "type": "integer"
    },
    "market_tier": {
      "title": "Market tier",
      "type": "string",
      "enum": [
        "tier-1-global-systemic",
        "tier-2-regulated-issuer",
        "tier-3-regional-specialized"
      ]
    },
    "market_tier_label": {
      "title": "Market tier — source label",
      "type": "string",
      "description": "Free-text descriptor preserved from source (e.g. 'Tier 1 - Global Systemic Issuer')."
    },
    "peg_mechanism": {
      "title": "Peg mechanism",
      "type": "string",
      "description": "How the peg is enforced. For centralized stablecoins this is always issuer-redemption; recorded verbatim from source."
    },
    "mint_burn_control": {
      "title": "Mint/burn control",
      "type": "string",
      "description": "e.g. 'Centralized / Permissioned'."
    },
    "is_rebasing": {
      "title": "Is rebasing",
      "type": "boolean"
    },
    "is_yield_bearing": {
      "title": "Is yield bearing",
      "type": "boolean"
    },
    "reserve_composition": {
      "title": "Reserve composition",
      "type": "string",
      "description": "Free-text reserve description from source (e.g. 'Cash, Cash Equivalents, Short-Term T-Bills, Other Assets'). Structured per-class share_pct deferred to v2."
    },
    "custodians": {
      "title": "Custodians",
      "type": "string",
      "description": "Free-text list of custodians from source. 'Multiple (not fully disclosed publicly)' is canonical for opaque cases."
    },
    "attestation_provider": {
      "title": "Attestation provider",
      "type": "string"
    },
    "attestation_frequency": {
      "title": "Attestation frequency",
      "type": "string",
      "examples": [
        "Monthly",
        "Quarterly",
        "Annual",
        "None"
      ]
    },
    "redemption_availability": {
      "title": "Redemption availability",
      "type": "string",
      "description": "e.g. 'Direct', 'Restricted (Institutional / Approved Counterparties)', 'None'."
    },
    "issuer_jurisdiction": {
      "title": "Issuer jurisdiction",
      "type": "string",
      "description": "Cleaned country/region. Parenthetical metadata moves to issuer_jurisdiction_note."
    },
    "issuer_jurisdiction_note": {
      "title": "Issuer jurisdiction — note",
      "type": "string",
      "description": "Per ISS-003: e.g. '(holding structure)' for Tether's BVI vehicle."
    },
    "regulatory_status": {
      "title": "Regulatory status",
      "type": "string"
    },
    "primary_regulators": {
      "title": "Primary regulators",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Multi-value cell exploded on commas/semicolons. Use 'None' as a single-element array when explicitly unregulated."
    },
    "sanction_freeze_authority": {
      "title": "Sanction / freeze authority",
      "type": "boolean"
    },
    "historical_regulatory_actions": {
      "title": "Historical regulatory actions",
      "type": "string",
      "description": "Free-text history. Structured action_date/action_type rows deferred to v2."
    },
    "ethereum_deployment": {
      "title": "Ethereum deployment",
      "type": "string",
      "description": "Free-text deployment description. Use 'Yes' / 'No' for the binary case."
    },
    "primary_networks": {
      "title": "Primary networks",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Networks the token is deployed on. Multi-value cell; first element is the primary."
    },
    "upgradeable_contracts": {
      "title": "Upgradeable contracts",
      "type": "boolean"
    },
    "blacklisting_capability": {
      "title": "Blacklisting capability",
      "type": "boolean"
    },
    "primary_use_cases": {
      "title": "Primary use cases",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "key_dependency_risks": {
      "title": "Key dependency risks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "failure_modes": {
      "title": "Failure modes",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "systemic_importance": {
      "title": "Systemic importance",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    }
  }
}
$json$::jsonb
 where slug = 'centralized-stablecoins';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/decentralized-stablecoins.json",
  "title": "Decentralized Stablecoins — subsector_attributes",
  "description": "Per-token JSONB fields for protocol-issued, non-custodial stablecoins on Ethereum (DAI, LUSD, RAI, FRAX, agEUR). Source: DecentralizedStablecoins tab in Monetary-and-Access-Rails_cleaned_v1.xlsx. Strategy A++: scalars + string arrays.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "ticker": {
      "title": "Ticker",
      "type": "string"
    },
    "launch_year": {
      "title": "Launch year",
      "type": "integer"
    },
    "target_peg": {
      "title": "Target peg",
      "type": "string",
      "examples": [
        "USD",
        "EUR",
        "GBP",
        "SGD",
        "ISK",
        "eth-relative",
        "other"
      ],
      "description": "ISO 4217 where applicable. RAI uses 'eth-relative' (floating redemption price)."
    },
    "protocol_type": {
      "title": "Protocol type",
      "type": "string",
      "examples": [
        "dao-governed",
        "immutable",
        "governed-with-emergency-admin"
      ]
    },
    "protocol_type_label": {
      "title": "Protocol type — source label",
      "type": "string",
      "description": "Free-text descriptor preserved verbatim (e.g. 'DAO-governed protocol', 'Immutable protocol')."
    },
    "decentralized_classification": {
      "title": "Decentralized classification",
      "type": "string",
      "examples": [
        "over-collateralized-onchain-native",
        "hybrid-algorithmic-onchain-governed",
        "non-pegged-reflex-asset"
      ]
    },
    "decentralized_classification_label": {
      "title": "Decentralized classification — source label",
      "type": "string"
    },
    "peg_enforcement_mechanism": {
      "title": "Peg enforcement mechanism",
      "type": "string",
      "description": "Long-form description of how the peg is held. Rendered as PROSE on the project page."
    },
    "collateral_types": {
      "title": "Collateral types",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Multi-value list. e.g. ['ETH', 'LSTs', 'tokenized RWAs', 'other onchain assets'] for DAI."
    },
    "collateralization_requirement": {
      "title": "Collateralization requirement",
      "type": "string",
      "description": "e.g. 'Dynamic (vault-type specific minimums)', '110% minimum'."
    },
    "mint_burn_authority": {
      "title": "Mint/burn authority",
      "type": "string",
      "examples": [
        "permissionless",
        "protocol-controlled",
        "governance-controlled"
      ]
    },
    "mint_burn_authority_label": {
      "title": "Mint/burn authority — source label",
      "type": "string"
    },
    "liquidation_mechanism": {
      "title": "Liquidation mechanism",
      "type": "string",
      "examples": [
        "auction-based",
        "stability-pool",
        "redemption-based",
        "dutch-auction",
        "none"
      ]
    },
    "oracle_dependency": {
      "title": "Oracle dependency",
      "type": "string",
      "examples": [
        "high",
        "medium",
        "low",
        "none"
      ]
    },
    "governance_control": {
      "title": "Governance control",
      "type": "string",
      "description": "Free-text description of who controls governance (e.g. 'MakerDAO governance (MKR holders)')."
    },
    "is_upgradeable": {
      "title": "Is upgradeable",
      "type": "boolean"
    },
    "emergency_controls": {
      "title": "Emergency controls",
      "type": "string",
      "examples": [
        "none",
        "pause",
        "shutdown",
        "discretionary-action"
      ],
      "description": "Per data_fixes: 'None' may conflict with stress-event behavior — DAI's Emergency Shutdown Module exists but is not a routine pause; record nuance in stress_event_behavior."
    },
    "ethereum_deployment": {
      "title": "Ethereum deployment",
      "type": "string"
    },
    "primary_networks": {
      "title": "Primary networks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "composable_in_defi": {
      "title": "Composable in DeFi",
      "type": "string",
      "examples": [
        "high",
        "medium",
        "low"
      ]
    },
    "primary_use_cases": {
      "title": "Primary use cases",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "failure_modes": {
      "title": "Failure modes",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "stress_event_behavior": {
      "title": "Stress event behavior",
      "type": "string",
      "description": "Free-text description of how the protocol behaves under stress. Rendered as PROSE."
    },
    "systemic_importance": {
      "title": "Systemic importance",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    },
    "primary_risk_sources": {
      "title": "Primary risk sources",
      "type": "array",
      "items": {
        "type": "string",
        "examples": [
          "governance",
          "oracle",
          "collateral-quality",
          "liquidity",
          "smart-contract",
          "regulatory",
          "protocol",
          "market"
        ]
      }
    },
    "decentralization_strength": {
      "title": "Decentralization strength",
      "type": "string",
      "examples": [
        "Strong",
        "Moderate",
        "Weak"
      ]
    }
  }
}
$json$::jsonb
 where slug = 'decentralized-stablecoins';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/synthetic-yield-bearing-dollars.json",
  "title": "Synthetic & Yield-Bearing Dollars — subsector_attributes",
  "description": "Per-asset JSONB fields for USD-referenced assets that earn yield or have synthetic peg mechanics (sUSD, OUSG, USDY, sDAI, USDe; sUSDe added per ISS-008). Source: SyntheticYieldDollars tab in Monetary-and-Access-Rails_cleaned_v1.xlsx. These are NOT stablecoins — they are financial instruments dollar-referenced.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "ticker": {
      "title": "Ticker",
      "type": "string",
      "description": "Issuer-published case (sUSD, OUSG, USDY, sDAI, USDe, sUSDe)."
    },
    "legal_name": {
      "title": "Legal name",
      "type": "string",
      "description": "Set when display name differs (e.g. OUSG = 'Ondo Short-Term U.S. Government Bond Fund')."
    },
    "launch_year": {
      "title": "Launch year",
      "type": "integer"
    },
    "target_reference": {
      "title": "Target reference",
      "type": "string",
      "description": "All v1 assets reference USD.",
      "examples": [
        "USD",
        "EUR",
        "GBP",
        "other"
      ]
    },
    "asset_type": {
      "title": "Asset type",
      "type": "string",
      "examples": [
        "yield-bearing",
        "synthetic",
        "rwa-backed"
      ]
    },
    "asset_type_label": {
      "title": "Asset type — source label",
      "type": "string",
      "description": "Preserves descriptive parenthetical (e.g. 'Synthetic Dollar (Debt-Pool Based)')."
    },
    "yield_mechanism": {
      "title": "Yield mechanism",
      "type": "string",
      "examples": [
        "protocol-interest-rate",
        "delta-neutral-strategy",
        "rwa-cash-flows",
        "trading-funding-fees",
        "multi"
      ]
    },
    "yield_mechanism_description": {
      "title": "Yield mechanism description",
      "type": "string",
      "description": "Long-form description. Rendered as PROSE."
    },
    "yield_accrual_method": {
      "title": "Yield accrual method",
      "type": "string",
      "examples": [
        "rebasing",
        "exchange-rate-appreciation",
        "claim-based-redemption",
        "indirect",
        "none-direct-to-staker"
      ]
    },
    "current_yield_apy_pct": {
      "title": "Current yield (APY %)",
      "type": "number"
    },
    "principal_stability_model": {
      "title": "Principal stability model",
      "type": "string",
      "examples": [
        "soft-peg",
        "managed-nav",
        "strategy-dependent",
        "hard-peg-protocol"
      ]
    },
    "underlying_exposures": {
      "title": "Underlying exposures",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Multi-value list. e.g. ['SNX collateral', 'global synthetic asset debt'] for sUSD."
    },
    "downside_scenarios": {
      "title": "Downside scenarios",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "mint_burn_control": {
      "title": "Mint/burn control",
      "type": "string",
      "examples": [
        "permissionless",
        "governed",
        "whitelisted",
        "hybrid"
      ]
    },
    "redemption_model": {
      "title": "Redemption model",
      "type": "string",
      "examples": [
        "instant",
        "delayed",
        "conditional",
        "onchain-via-pool",
        "not-guaranteed-at-par"
      ]
    },
    "redemption_at_par_guaranteed": {
      "title": "Redemption at par guaranteed",
      "type": "boolean"
    },
    "is_permissioned": {
      "title": "Is permissioned",
      "type": "boolean"
    },
    "kyc_required": {
      "title": "KYC required",
      "type": "boolean"
    },
    "minimum_investment_usd": {
      "title": "Minimum investment (USD)",
      "type": "number"
    },
    "governance_control": {
      "title": "Governance control",
      "type": "string"
    },
    "is_upgradeable": {
      "title": "Is upgradeable",
      "type": "boolean"
    },
    "emergency_controls": {
      "title": "Emergency controls",
      "type": "string"
    },
    "ethereum_deployment": {
      "title": "Ethereum deployment",
      "type": "string"
    },
    "primary_networks": {
      "title": "Primary networks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "composable_in_defi": {
      "title": "Composable in DeFi",
      "type": "string",
      "examples": [
        "high",
        "medium",
        "low"
      ]
    },
    "composable_in_defi_label": {
      "title": "Composable in DeFi — source label",
      "type": "string",
      "description": "e.g. 'Medium (integration constrained by peg variability)' for sUSD."
    },
    "primary_use_cases": {
      "title": "Primary use cases",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "liquidity_profile": {
      "title": "Liquidity profile",
      "type": "string",
      "examples": [
        "deep",
        "moderate",
        "thin"
      ]
    },
    "systemic_importance": {
      "title": "Systemic importance",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    },
    "instrument_vs_money": {
      "title": "Instrument vs money classification",
      "type": "string",
      "examples": [
        "financial-instrument",
        "cash-equivalent"
      ]
    },
    "yield_dependence_level": {
      "title": "Yield dependence level",
      "type": "string",
      "examples": [
        "core",
        "secondary"
      ]
    },
    "related_asset_slug": {
      "title": "Related asset slug",
      "type": "string",
      "description": "For staked variants — sUSDe.related_asset_slug = 'usde'."
    },
    "related_asset_relationship": {
      "title": "Related asset relationship",
      "type": "string",
      "examples": [
        "staked-variant",
        "wrapped-variant",
        "bridged-copy",
        "precursor"
      ]
    }
  }
}
$json$::jsonb
 where slug = 'synthetic-yield-bearing-dollars';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/global-on-ramps.json",
  "title": "Global On-Ramps — subsector_attributes",
  "description": "Per-product JSONB fields for fiat-to-crypto on-ramps with global reach (MoonPay, Ramp, Transak, Coinbase Pay, etc.). Source: GlobalOnRamps tab in Monetary-and-Access-Rails_cleaned_v1.xlsx. Aggregators (Onramper, Socket, MetaMask Buy, Trust Wallet) carry is_aggregator=true per ISS-009.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "founded_year": {
      "title": "Founded year",
      "type": "integer"
    },
    "founded_year_confidence": {
      "title": "Founded year confidence",
      "type": "string",
      "description": "ISS-010 — many on-ramps have weak founding date evidence.",
      "examples": [
        "verified",
        "approximate",
        "self-reported",
        "unknown"
      ]
    },
    "headquarters_full_text": {
      "title": "Headquarters — full source text",
      "type": "string",
      "description": "ISS-003: original parenthetical-preserving HQ string."
    },
    "primary_function": {
      "title": "Primary function",
      "type": "string",
      "examples": [
        "fiat-to-crypto",
        "fiat-to-stablecoin",
        "aggregator-routing",
        "mixed"
      ]
    },
    "primary_function_label": {
      "title": "Primary function — source label",
      "type": "string",
      "description": "Source phrasing (e.g. 'Fiat → Crypto Access')."
    },
    "supported_fiat_currencies": {
      "title": "Supported fiat currencies",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "supported_payment_methods": {
      "title": "Supported payment methods",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "supported_crypto_assets": {
      "title": "Supported crypto assets",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "ethereum_support": {
      "title": "Ethereum support",
      "type": "string",
      "description": "Free-text description of Ethereum-network coverage."
    },
    "geographic_coverage": {
      "title": "Geographic coverage",
      "type": "string",
      "examples": [
        "global",
        "multi-region",
        "regional-with-global-reach"
      ]
    },
    "country_count_text": {
      "title": "Country count — source text",
      "type": "string",
      "description": "ISS-019: original e.g. '150+ (approx.)'."
    },
    "country_count_min": {
      "title": "Country count (numeric min)",
      "type": "integer"
    },
    "country_count_modifier": {
      "title": "Country count modifier",
      "type": "string",
      "examples": [
        "exact",
        "approx",
        "plus",
        "range"
      ]
    },
    "regional_restrictions_present": {
      "title": "Regional restrictions present",
      "type": "boolean"
    },
    "regulatory_model": {
      "title": "Regulatory model",
      "type": "string",
      "examples": [
        "licensed",
        "partner-licensed",
        "hybrid",
        "unlicensed"
      ]
    },
    "regulatory_model_label": {
      "title": "Regulatory model — source label",
      "type": "string"
    },
    "primary_regulatory_jurisdictions": {
      "title": "Primary regulatory jurisdictions",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "kyc_aml_requirement": {
      "title": "KYC / AML requirement",
      "type": "string",
      "examples": [
        "mandatory",
        "tiered",
        "optional"
      ]
    },
    "kyc_aml_requirement_label": {
      "title": "KYC / AML requirement — source label",
      "type": "string"
    },
    "custody_of_funds": {
      "title": "Custody of funds",
      "type": "string",
      "examples": [
        "temporary-in-flow",
        "third-party-custodian",
        "self-custody-destination"
      ]
    },
    "custody_of_funds_label": {
      "title": "Custody of funds — source label",
      "type": "string"
    },
    "conversion_control_model": {
      "title": "Conversion control model",
      "type": "string",
      "examples": [
        "centralized",
        "partner-dependent",
        "decentralized"
      ]
    },
    "freeze_denial_capability": {
      "title": "Freeze / denial capability",
      "type": "boolean"
    },
    "primary_dependency_risks": {
      "title": "Primary dependency risks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "failure_modes": {
      "title": "Failure modes",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "role_relative_to_ethereum": {
      "title": "Role relative to Ethereum",
      "type": "string",
      "examples": [
        "access-gateway",
        "distribution-layer",
        "aggregator",
        "embedded-wallet-feature"
      ]
    },
    "role_relative_to_ethereum_label": {
      "title": "Role relative to Ethereum — source label",
      "type": "string"
    },
    "is_ethereum_required": {
      "title": "Is Ethereum required for core function",
      "type": "string",
      "examples": [
        "yes",
        "partial",
        "no"
      ]
    },
    "is_ethereum_required_label": {
      "title": "Is Ethereum required — source label",
      "type": "string"
    },
    "primary_value_flow": {
      "title": "Primary value flow",
      "type": "string",
      "examples": [
        "fiat-to-ethereum",
        "fiat-to-stablecoin-to-ethereum",
        "fiat-to-multichain"
      ]
    },
    "primary_value_flow_label": {
      "title": "Primary value flow — source label",
      "type": "string"
    },
    "primary_user_segment": {
      "title": "Primary user segment",
      "type": "string",
      "examples": [
        "retail",
        "sme",
        "institutional",
        "web3-app-developer",
        "mixed"
      ]
    },
    "primary_user_segment_label": {
      "title": "Primary user segment — source label",
      "type": "string"
    },
    "primary_use_case": {
      "title": "Primary use case",
      "type": "string"
    },
    "systemic_importance": {
      "title": "Systemic importance to Ethereum access",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    },
    "access_bottleneck_type": {
      "title": "Access bottleneck type",
      "type": "array",
      "items": {
        "type": "string",
        "examples": [
          "banking",
          "card-networks",
          "regulation",
          "mixed"
        ]
      }
    },
    "onramp_vs_exchange_bias": {
      "title": "On-ramp vs exchange bias",
      "type": "string",
      "examples": [
        "access-first",
        "trading-adjacent",
        "exchange-primary"
      ]
    },
    "decentralization_impact": {
      "title": "Decentralization impact",
      "type": "string",
      "description": "Free-text qualitative impact statement. PROSE-rendered."
    },
    "is_aggregator": {
      "title": "Is aggregator",
      "type": "boolean",
      "description": "Per ISS-009: Onramper, Socket, MetaMask Buy, Trust Wallet aggregate other on-ramps."
    }
  }
}
$json$::jsonb
 where slug = 'global-on-ramps';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/institutional-payment-rails.json",
  "title": "Institutional Payment Rails — subsector_attributes",
  "description": "Per-product JSONB fields for bank- and treasury-grade Ethereum settlement rails (Circle Payments, JPM Kinexys, Paxos Enterprise, BIS Project Agora pilots, etc.). Source: InstitutionalRails tab in Monetary-and-Access-Rails_cleaned_v1.xlsx. Banks, central banks, multilateral institutions, foundations all valid maintaining_org entity_types per ISS-011.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "founded_year": {
      "title": "Founded year",
      "type": "integer"
    },
    "headquarters_full_text": {
      "title": "Headquarters — full source text",
      "type": "string"
    },
    "deployment_status": {
      "title": "Deployment status",
      "type": "string",
      "description": "ISS-012: many institutional rails are pilots, not production.",
      "examples": [
        "production",
        "pilot",
        "research-pilot",
        "decommissioned"
      ]
    },
    "deployment_status_as_of_date": {
      "title": "Deployment status — as of date",
      "type": "string",
      "format": "date"
    },
    "primary_function": {
      "title": "Primary function",
      "type": "string",
      "description": "Free-text source phrasing."
    },
    "primary_functions": {
      "title": "Primary functions (structured)",
      "type": "array",
      "items": {
        "type": "string",
        "examples": [
          "treasury-settlement",
          "cross-border-payments",
          "b2b-clearing",
          "payroll-disbursements",
          "tokenized-deposits",
          "wholesale-settlement",
          "cbdc-pilot",
          "other"
        ]
      }
    },
    "target_user_segments": {
      "title": "Target user segments",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "primary_use_case": {
      "title": "Primary use case",
      "type": "string"
    },
    "ethereum_role_in_stack": {
      "title": "Ethereum role in stack",
      "type": "string",
      "examples": [
        "native-settlement",
        "anchored-finality",
        "bridging-layer",
        "software-engine-only"
      ]
    },
    "ethereum_role_in_stack_label": {
      "title": "Ethereum role in stack — source label",
      "type": "string"
    },
    "is_ethereum_abstracted": {
      "title": "Is Ethereum abstracted from end users",
      "type": "string",
      "examples": [
        "yes",
        "partial",
        "no"
      ]
    },
    "is_ethereum_abstracted_label": {
      "title": "Is Ethereum abstracted — source label",
      "type": "string"
    },
    "supported_ethereum_networks": {
      "title": "Supported Ethereum networks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "settlement_asset_types": {
      "title": "Settlement asset types",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "e.g. ['Stablecoins (USDC)', 'Tokenized Deposits']."
    },
    "regulatory_posture": {
      "title": "Regulatory posture",
      "type": "string",
      "examples": [
        "regulated",
        "partner-regulated",
        "enterprise-private",
        "central-bank",
        "multilateral-institution"
      ]
    },
    "regulatory_posture_label": {
      "title": "Regulatory posture — source label",
      "type": "string"
    },
    "primary_regulatory_jurisdictions": {
      "title": "Primary regulatory jurisdictions",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "kyc_aml_enforcement_level": {
      "title": "KYC / AML enforcement level",
      "type": "string",
      "examples": [
        "institutional-grade",
        "jurisdiction-dependent",
        "sandbox-only"
      ]
    },
    "kyc_aml_enforcement_label": {
      "title": "KYC / AML enforcement — source label",
      "type": "string"
    },
    "custody_model": {
      "title": "Custody model",
      "type": "string",
      "examples": [
        "self-custody-enterprise",
        "qualified-custodian",
        "platform-managed",
        "mixed"
      ]
    },
    "custody_model_label": {
      "title": "Custody model — source label",
      "type": "string"
    },
    "transaction_scale": {
      "title": "Transaction scale",
      "type": "string",
      "examples": [
        "high-value",
        "high-volume",
        "both"
      ]
    },
    "transaction_scale_label": {
      "title": "Transaction scale — source label",
      "type": "string"
    },
    "availability_sla": {
      "title": "Availability / SLA expectations",
      "type": "string",
      "examples": [
        "enterprise-sla",
        "best-effort",
        "not-applicable-pilot"
      ]
    },
    "availability_sla_label": {
      "title": "Availability / SLA — source label",
      "type": "string"
    },
    "primary_dependency_risks": {
      "title": "Primary dependency risks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "failure_modes": {
      "title": "Failure modes",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "interaction_with_stablecoins": {
      "title": "Interaction with stablecoins",
      "type": "string",
      "examples": [
        "primary-settlement-medium",
        "issuer",
        "optional",
        "none"
      ]
    },
    "interaction_with_stablecoins_label": {
      "title": "Interaction with stablecoins — source label",
      "type": "string"
    },
    "interaction_with_onramps": {
      "title": "Interaction with on-ramps",
      "type": "string",
      "examples": [
        "direct",
        "indirect",
        "none"
      ]
    },
    "interaction_with_defi": {
      "title": "Interaction with DeFi",
      "type": "string",
      "examples": [
        "none",
        "limited",
        "programmatic-escrow-automation"
      ]
    },
    "interaction_with_defi_label": {
      "title": "Interaction with DeFi — source label",
      "type": "string"
    },
    "geographic_scope": {
      "title": "Geographic scope",
      "type": "string",
      "examples": [
        "global",
        "multi-region",
        "regional",
        "single-jurisdiction"
      ]
    },
    "geographic_scope_label": {
      "title": "Geographic scope — source label",
      "type": "string"
    },
    "institutional_adoption_level": {
      "title": "Institutional adoption level",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low",
        "Early"
      ]
    },
    "systemic_importance": {
      "title": "Systemic importance to Ethereum",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    },
    "settlement_vs_access_classification": {
      "title": "Settlement vs access classification",
      "type": "string",
      "examples": [
        "settlement-rail",
        "access-rail",
        "mixed"
      ]
    },
    "programmability_level": {
      "title": "Programmability level",
      "type": "string",
      "examples": [
        "static-payments",
        "conditional-programmable"
      ]
    },
    "programmability_level_label": {
      "title": "Programmability level — source label",
      "type": "string"
    },
    "abstraction_risk": {
      "title": "Abstraction risk",
      "type": "string",
      "examples": [
        "ethereum-visible",
        "ethereum-abstracted"
      ]
    },
    "pilot_project_names": {
      "title": "Pilot project names",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "e.g. ['Project Agora', 'Project Mariana'] for BIS."
    }
  }
}
$json$::jsonb
 where slug = 'institutional-payment-rails';

update public.subsectors
   set specific_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/subsectors/regional-payment-networks.json",
  "title": "Regional Payment Networks — subsector_attributes",
  "description": "Per-product JSONB fields for geography-bound Ethereum-enabled payment networks (Bitso, Yellow Card, Flutterwave, GCash, etc.). Source: RegionalNetworks tab in Monetary-and-Access-Rails_cleaned_v1.xlsx. Multi-jurisdiction operators (Hubpay, Bitybank) use maintaining_org_note='multi-jurisdiction' per ISS-014.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "founded_year": {
      "title": "Founded year",
      "type": "integer"
    },
    "founded_year_confidence": {
      "title": "Founded year confidence",
      "type": "string",
      "examples": [
        "verified",
        "approximate",
        "self-reported",
        "unknown"
      ]
    },
    "primary_region": {
      "title": "Primary region",
      "type": "string",
      "examples": [
        "latam",
        "sub-saharan-africa",
        "mena",
        "sea",
        "europe",
        "americas-global"
      ]
    },
    "primary_region_full_text": {
      "title": "Primary region — full source text",
      "type": "string",
      "description": "e.g. 'Latin America (Mexico core; Brazil, Argentina, Colombia)'."
    },
    "primary_jurisdictions": {
      "title": "Primary jurisdictions",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "primary_function": {
      "title": "Primary function",
      "type": "string",
      "examples": [
        "remittances",
        "domestic-payments",
        "regional-cross-border-settlement",
        "fx-corridor-payments"
      ]
    },
    "primary_function_label": {
      "title": "Primary function — source label",
      "type": "string"
    },
    "local_problem_addressed": {
      "title": "Local problem addressed",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "target_user_segments": {
      "title": "Target user segments",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "ethereum_role_in_stack": {
      "title": "Ethereum role in stack",
      "type": "string",
      "examples": [
        "native-settlement-layer",
        "anchored-bridging-layer"
      ]
    },
    "ethereum_role_in_stack_label": {
      "title": "Ethereum role in stack — source label",
      "type": "string"
    },
    "is_ethereum_abstracted": {
      "title": "Is Ethereum abstracted from end users",
      "type": "string",
      "examples": [
        "yes",
        "partial",
        "no"
      ]
    },
    "is_ethereum_abstracted_label": {
      "title": "Is Ethereum abstracted — source label",
      "type": "string"
    },
    "supported_ethereum_networks": {
      "title": "Supported Ethereum networks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "settlement_asset_types": {
      "title": "Settlement asset types",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "primary_settlement_currency": {
      "title": "Primary settlement currency",
      "type": "string",
      "examples": [
        "usd-stablecoin",
        "local-currency-stablecoin",
        "multi-currency"
      ]
    },
    "primary_settlement_currency_label": {
      "title": "Primary settlement currency — source label",
      "type": "string"
    },
    "local_currency_support": {
      "title": "Local currency support",
      "type": "string",
      "examples": [
        "native",
        "via-fx-conversion",
        "none"
      ]
    },
    "local_currency_support_label": {
      "title": "Local currency support — source label",
      "type": "string",
      "description": "Free-text qualifier (e.g. 'Yes (MXN, BRL, ARS, COP via FX and banking rails)')."
    },
    "fx_model": {
      "title": "FX model",
      "type": "string",
      "examples": [
        "onchain-fx",
        "offchain-fx",
        "hybrid"
      ]
    },
    "fx_model_label": {
      "title": "FX model — source label",
      "type": "string"
    },
    "key_payment_corridors": {
      "title": "Key payment corridors",
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Multi-value list. Source format e.g. 'US → Mexico; US → Brazil; intra-LatAm corridors'."
    },
    "regulatory_posture": {
      "title": "Regulatory posture",
      "type": "string",
      "examples": [
        "licensed-locally",
        "partner-regulated",
        "grey-zone-evolving"
      ]
    },
    "regulatory_posture_label": {
      "title": "Regulatory posture — source label",
      "type": "string"
    },
    "kyc_aml_enforcement": {
      "title": "KYC / AML enforcement level",
      "type": "string",
      "examples": [
        "full",
        "tiered",
        "minimal"
      ]
    },
    "kyc_aml_enforcement_label": {
      "title": "KYC / AML enforcement — source label",
      "type": "string"
    },
    "custody_model": {
      "title": "Custody model",
      "type": "string",
      "examples": [
        "user-self-custody",
        "platform-custody",
        "hybrid"
      ]
    },
    "custody_model_label": {
      "title": "Custody model — source label",
      "type": "string"
    },
    "transaction_scale": {
      "title": "Transaction scale",
      "type": "string",
      "examples": [
        "low-value-high-frequency",
        "mixed",
        "high-value"
      ]
    },
    "transaction_scale_label": {
      "title": "Transaction scale — source label",
      "type": "string"
    },
    "availability_expectation": {
      "title": "Availability expectation",
      "type": "string",
      "examples": [
        "consumer-grade",
        "payments-grade"
      ]
    },
    "primary_dependency_risks": {
      "title": "Primary dependency risks",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "failure_modes": {
      "title": "Failure modes",
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "interaction_with_global_onramps": {
      "title": "Interaction with global on-ramps",
      "type": "string",
      "examples": [
        "direct",
        "indirect",
        "none"
      ]
    },
    "interaction_with_institutional": {
      "title": "Interaction with institutional payment rails",
      "type": "string",
      "examples": [
        "settlement-handoff",
        "direct",
        "indirect",
        "none"
      ]
    },
    "interaction_with_institutional_label": {
      "title": "Interaction with institutional — source label",
      "type": "string"
    },
    "interaction_with_defi": {
      "title": "Interaction with DeFi",
      "type": "string",
      "examples": [
        "none",
        "limited",
        "limited-liquidity-fx"
      ]
    },
    "interaction_with_defi_label": {
      "title": "Interaction with DeFi — source label",
      "type": "string"
    },
    "geographic_scope": {
      "title": "Geographic scope",
      "type": "string",
      "examples": [
        "single-country",
        "multi-country-region"
      ]
    },
    "geographic_scope_label": {
      "title": "Geographic scope — source label",
      "type": "string"
    },
    "regional_adoption_level": {
      "title": "Regional adoption level",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low",
        "Early"
      ]
    },
    "systemic_importance_regional": {
      "title": "Systemic importance to Ethereum (regional)",
      "type": "string",
      "examples": [
        "High",
        "Medium-High",
        "Medium",
        "Low-Medium",
        "Low"
      ]
    },
    "regional_constraint_type": {
      "title": "Regional constraint type",
      "type": "string",
      "examples": [
        "regulatory",
        "fx-currency",
        "banking-access",
        "fx-banking-access"
      ]
    },
    "regional_constraint_type_label": {
      "title": "Regional constraint type — source label",
      "type": "string"
    },
    "settlement_vs_access_orientation": {
      "title": "Settlement vs access orientation",
      "type": "string",
      "examples": [
        "settlement-first",
        "access-first"
      ]
    },
    "ethereum_dependency_level": {
      "title": "Ethereum dependency level",
      "type": "string",
      "examples": [
        "critical",
        "important",
        "replaceable"
      ]
    },
    "ethereum_dependency_level_label": {
      "title": "Ethereum dependency level — source label",
      "type": "string"
    },
    "maintaining_org_note": {
      "title": "Maintaining org — note",
      "type": "string",
      "description": "ISS-014 — set to 'multi-jurisdiction' for Hubpay, Bitybank, etc."
    }
  }
}
$json$::jsonb
 where slug = 'regional-payment-networks';

comment on column public.organizations.entity_type is
  'Type of org: company | dao | foundation | aggregate | individual | bank | central-bank | multilateral-institution | protocol-no-org. '
  'Banks/central-banks/multilaterals/foundations introduced for Sector 3 (Monetary & Access Rails) per ISS-011.';
