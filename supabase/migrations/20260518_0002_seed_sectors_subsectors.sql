-- M8.1: Seed all 7 sectors and all 36 subsectors so the Market Map navigation can
-- render before any projects exist. Project rows are filled in sector-by-sector starting
-- with M8.5 (Core Protocol Architecture).
--
-- Sheet IDs / gids are recorded so the ingest scripts in .cursor/skills/market-map/scripts/
-- can pull the source data via the public gviz/CSV endpoint without re-deriving the URLs.

insert into public.sectors (slug, name, description, display_order)
values
  ('core-protocol-architecture',     'Core Protocol Architecture',     'The chains themselves: how blocks get proposed, validated, and ordered.',                   1),
  ('rollup-scaling-frameworks',      'Rollup & Scaling Frameworks',    'L2/L3 execution environments that inherit L1 security.',                                   2),
  ('monetary-access-rails',          'Monetary & Access Rails',        'Stablecoins, on-ramps, and the payment networks that move value in and out of crypto.',   3),
  ('defi-systems-architecture',      'DeFi Systems Architecture',      'Lending, DEXs, structured products, LSTs, restaking, derivatives.',                       4),
  ('data-consensus-infrastructure',  'Data & Consensus Infrastructure', 'RPC, oracles, DA layers, indexing, and the analytics built on top.',                     5),
  ('advanced-compute-integration',   'Advanced Compute & Integration', 'AI agents, RWAs, identity, DePIN, and cross-chain compute.',                              6),
  ('governance-enterprise-framework','Governance & Enterprise Framework','DAOs, enterprise adoption, CBDCs, compliance, and institutional custody.',             7)
on conflict (slug) do update
  set name = excluded.name,
      description = excluded.description,
      display_order = excluded.display_order;

-- -----------------------------------------------------------------------------
-- Subsectors
-- -----------------------------------------------------------------------------
insert into public.subsectors (slug, sector_slug, name, description, display_order, source_sheet_id, source_sheet_gid) values
  -- Core Protocol Architecture
  ('consensus-layer',                'core-protocol-architecture',     'Consensus Layer',                  'Protocols that agree on chain state (PoS, PoW, BFT variants).', 1, '1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU', '0'),
  ('execution-layer',                'core-protocol-architecture',     'Execution Layer',                  'EVMs and alt VMs running transactions on top of consensus.',     2, '1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU', '1973587895'),
  ('validators-staking-providers',   'core-protocol-architecture',     'Validators & Staking Providers',   'Operators and services that run validator infrastructure.',      3, '1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU', '1461607073'),
  ('mev-block-builders',             'core-protocol-architecture',     'MEV & Block Builders',             'Block-building marketplaces, relays, and MEV infrastructure.',   4, '1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU', '1892242156'),
  ('network-upgrades',               'core-protocol-architecture',     'Network Upgrades',                 'Fork coordination, hard forks, EIPs/SIPs, and roadmap items.',   5, '1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU', '853500365'),

  -- Rollup & Scaling Frameworks
  ('optimistic-rollups',             'rollup-scaling-frameworks',      'Optimistic Rollups',               'Fraud-proof L2s with a challenge period.',                       1, '1J08OAuQ5UW4HQfoOrInTxYnoKXWqppOCRBr-1PxaKLk', '1623116093'),
  ('zk-rollups',                     'rollup-scaling-frameworks',      'ZK Rollups',                       'Validity-proof L2s using SNARKs/STARKs.',                        2, '1J08OAuQ5UW4HQfoOrInTxYnoKXWqppOCRBr-1PxaKLk', '841503241'),
  ('l3-appchain-frameworks',         'rollup-scaling-frameworks',      'L3 & Appchain Frameworks',         'Rollup-as-a-service and app-specific L3 stacks. Source sheet flagged for manual review before ingest.', 3, '1J08OAuQ5UW4HQfoOrInTxYnoKXWqppOCRBr-1PxaKLk', '698572346'),
  ('validiums-volitions-hybrid',     'rollup-scaling-frameworks',      'Validiums, Volitions & Hybrid Rollups', 'Off-chain DA variants of the rollup design space.',          4, '1J08OAuQ5UW4HQfoOrInTxYnoKXWqppOCRBr-1PxaKLk', '2102310935'),

  -- Monetary & Access Rails
  ('centralized-stablecoins',        'monetary-access-rails',          'Centralized Stablecoins',          'Fiat-backed stablecoins with a centralized issuer.',             1, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '740017838'),
  ('decentralized-stablecoins',      'monetary-access-rails',          'Decentralized Stablecoins',        'Overcollateralized and algorithmic stablecoins.',                2, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '793795651'),
  ('synthetic-yield-bearing-dollars','monetary-access-rails',          'Synthetic & Yield-Bearing Dollars','Cash-and-carry and basis-trade dollar tokens.',                  3, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '2027955655'),
  ('global-on-ramps',                'monetary-access-rails',          'Global On-Ramps',                  'Fiat-to-crypto on/off-ramps and aggregators.',                   4, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '536722612'),
  ('institutional-payment-rails',    'monetary-access-rails',          'Institutional Payment Rails',      'B2B and bank-grade stablecoin settlement networks.',             5, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '1092087303'),
  ('regional-payment-networks',      'monetary-access-rails',          'Regional Payment Networks',        'Local payment rails integrated with crypto stablecoins.',        6, '1MyXItem529dr0NGkXmVQXS0zvzdwm-yNTQoh56LYEtI', '353346319'),

  -- DeFi Systems Architecture
  ('lending-markets',                'defi-systems-architecture',      'Lending Markets',                  'Money markets, isolated lending pools, and credit protocols.',   1, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '1468161002'),
  ('dexs-liquidity-protocols',       'defi-systems-architecture',      'DEXs & Liquidity Protocols',       'AMMs, orderbook DEXs, and aggregators.',                         2, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '1271133982'),
  ('yield-structured-markets',       'defi-systems-architecture',      'Yield & Structured Markets',       'Yield tokenization, principal/yield splitting, structured products.', 3, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '472989866'),
  ('liquid-staking-tokens',          'defi-systems-architecture',      'Liquid Staking Tokens (LSTs)',     'Receipt tokens for staked positions.',                           4, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '104070153'),
  ('restaking-systems',              'defi-systems-architecture',      'Restaking Systems',                'EigenLayer-style restaking and AVSs.',                           5, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '858691553'),
  ('synthetic-derivatives',          'defi-systems-architecture',      'Synthetic & Derivatives',          'Perps, options, futures, synthetic asset protocols.',            6, '1bdcu0UIBvZ6ZLmuG9rTLvXrVEdTh3wg1W9yMZ90K6pU', '970731173'),

  -- Data & Consensus Infrastructure
  ('rpc-node-providers',             'data-consensus-infrastructure',  'RPC & Node Providers',             'Managed nodes, archival RPC, and gateway providers.',            1, '1oxpdT9qsScSl8b3nL543bEO-q8GRTj2CtfACsfu1W8A', '1270499317'),
  ('oracles-data-networks',          'data-consensus-infrastructure',  'Oracles & Data Networks',          'Price feeds, randomness, and off-chain data sources.',           2, '1oxpdT9qsScSl8b3nL543bEO-q8GRTj2CtfACsfu1W8A', '1127240504'),
  ('data-availability-systems',      'data-consensus-infrastructure',  'Data Availability Systems',        'Modular DA layers separating consensus from execution.',         3, '1oxpdT9qsScSl8b3nL543bEO-q8GRTj2CtfACsfu1W8A', '154577554'),
  ('indexing-query-engines',         'data-consensus-infrastructure',  'Indexing & Query Engines',         'Subgraph-style indexers, SQL access layers, and graph DBs.',     4, '1oxpdT9qsScSl8b3nL543bEO-q8GRTj2CtfACsfu1W8A', '1023110846'),
  ('analytics-intelligence',         'data-consensus-infrastructure',  'Analytics & Intelligence',         'On-chain analytics, wallet labeling, and intelligence platforms.', 5, '1oxpdT9qsScSl8b3nL543bEO-q8GRTj2CtfACsfu1W8A', '457625346'),

  -- Advanced Compute & Integration
  ('ai-agents-autonomous-systems',   'advanced-compute-integration',   'AI Agents & Autonomous Systems',   'Agent frameworks, on-chain agents, and agent marketplaces.',     1, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1608239665'),
  ('real-world-assets',              'advanced-compute-integration',   'Real World Assets (RWAs)',         'Tokenized real estate, treasuries, private credit, commodities.', 2, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1894391559'),
  ('identity-social-graphs',         'advanced-compute-integration',   'Identity & Social Graphs',         'On-chain identity, social graphs, and reputation systems.',      3, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '341534256'),
  ('depin',                          'advanced-compute-integration',   'DePIN (Physical Infrastructure)',  'Decentralized physical infrastructure networks.',                4, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '1254628628'),
  ('cross-chain-compute',            'advanced-compute-integration',   'Cross-Chain Compute',              'Cross-chain messaging, shared sequencers, intent networks.',     5, '1mpaWTCz9tTaKiJ1sBENEsetbRo85NX2NrCvOTbVtvZU', '403856203'),

  -- Governance & Enterprise Framework
  ('dao-governance-systems',         'governance-enterprise-framework','DAO Governance Systems',           'Voting frameworks, treasuries, governance tooling.',             1, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', '1800934348'),
  ('enterprise-blockchain-adoption', 'governance-enterprise-framework','Enterprise Blockchain Adoption',   'Enterprise consortium chains and corporate-grade deployments.',  2, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', '2131719987'),
  ('cbdcs-public-sector-pilots',     'governance-enterprise-framework','CBDCs & Public Sector Pilots',     'Central bank digital currencies and government pilots.',         3, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', '652382610'),
  ('compliance-regulatory-intel',    'governance-enterprise-framework','Compliance & Regulatory Intelligence', 'AML/KYC, sanctions screening, regulatory intel.',            4, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', '341111534'),
  ('institutional-custody-security', 'governance-enterprise-framework','Institutional Custody & Security', 'Qualified custodians and institutional security stacks.',        5, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', '1845020211')
on conflict (slug) do update
  set sector_slug = excluded.sector_slug,
      name = excluded.name,
      description = excluded.description,
      display_order = excluded.display_order,
      source_sheet_id = excluded.source_sheet_id,
      source_sheet_gid = excluded.source_sheet_gid;
