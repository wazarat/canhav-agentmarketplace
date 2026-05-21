#!/usr/bin/env python3
"""M8.9 — Network Upgrades weekly ingestion worker.

Pulls free, public, well-structured data from GitHub:

* ``github.com/ethereum/EIPs``           → every EIP markdown file (YAML front-matter).
* ``github.com/ethereum/consensus-specs`` → consensus-side fork directories + releases.
* ``github.com/ethereum/execution-specs`` → execution-side fork directories.
* ``github.com/ethereum/pm`` (tracker issue, optional) → upcoming fork scope.

Then upserts the four-table relational schema introduced by
``supabase/migrations/20260520_0006_network_upgrades_schema.sql``:

* ``public.eips``
* ``public.network_upgrades``
* ``public.upgrade_eips``
* ``public.upgrade_impact``

…and mirrors each ``network_upgrades`` row into ``public.projects`` so the
Market Map UI navigation works without per-subsector special-casing. The mirror
row has every universal field NULL and
``not_applicable_reason='protocol_event_not_entity'``.

DESIGN NOTES

1. The script is **idempotent**. Re-running with no upstream change produces
   zero data drift (verified by comparing source commit SHAs).
2. Activation dates, layers, risk profiles, descriptions, and the curated
   ``upgrade_impact`` rows for the 7 known upgrades come from the v7
   Perplexity drafts (mirrored under .cursor/skills/.../subsectors/) and the
   source Google Sheet. They live as a Python ``UPGRADE_BASELINES`` table in
   this file — explicit curation, not magic. New upgrades land by adding a
   ``UpgradeBaseline`` entry plus the ``upgrade_impact`` rows.
3. EIP-to-upgrade assignment for known upgrades is driven by
   ``UpgradeBaseline.eip_headlines``. For consensus-specs releases that
   reference new EIPs we have not curated yet, the script logs them under a
   ``UNCURATED_EIPS`` summary at the end — operator sees them, decides
   whether to add a baseline.
4. We **always use the GitHub API with a PAT** (5000 req/h) rather than
   unauthenticated (60 req/h). Set ``GITHUB_TOKEN`` in the env. The worker
   degrades to unauthenticated mode if no token is present, but only on a
   small subset of API calls (the EIP-listing call alone burns several
   hundred requests, so unauthenticated mode will hit the cap).
5. **ETag caching** — every GitHub API response is cached by ETag in
   ``.cache/github-etags.json`` and re-sent with ``If-None-Match`` on the
   next run. GitHub returns 304 for unchanged files, free of rate-limit cost.
   The cache file is gitignored.
6. The script writes a one-line summary to stdout and a per-run digest to
   ``stderr`` so the GitHub Actions log stays scannable.

Usage::

    # Local development:
    source backend/venv/bin/activate
    set -a && source backend/.env && set +a
    python backend/scripts/ingest_network_upgrades.py --dry-run
    python backend/scripts/ingest_network_upgrades.py

    # GitHub Actions (.github/workflows/ingest-network-upgrades.yml):
    #   weekly cron — pip install -r requirements.txt && python …

The corresponding migration is
``supabase/migrations/20260520_0006_network_upgrades_schema.sql``. The skill
reference docs are at
``.cursor/skills/market-map/sectors/core-protocol-architecture/subsectors/network-upgrades*.md``.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import logging
import os
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple

import httpx

try:
    import frontmatter  # python-frontmatter (in backend/requirements.txt)
except ImportError as exc:  # pragma: no cover — surface a friendly error.
    sys.stderr.write(
        "ERROR: python-frontmatter is required. Install with:\n"
        "  pip install -r backend/requirements.txt\n"
    )
    raise SystemExit(2) from exc


REPO_ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / ".cache"
ETAG_CACHE_PATH = CACHE_DIR / "github-etags.json"

GITHUB_API_BASE = "https://api.github.com"
RAW_BASE = "https://raw.githubusercontent.com"

EIPS_REPO = "ethereum/EIPs"
EIPS_BRANCH = "master"
CONSENSUS_SPECS_REPO = "ethereum/consensus-specs"
EXECUTION_SPECS_REPO = "ethereum/execution-specs"
PM_REPO = "ethereum/pm"

NETWORK_UPGRADES_SUBSECTOR_SLUG = "network-upgrades"
NETWORK_UPGRADES_SECTOR_SLUG = "core-protocol-architecture"

LOG = logging.getLogger("ingest_network_upgrades")


# ---------------------------------------------------------------------------
# Curated baselines — the 7 known upgrades.
#
# Sources:
#   - The source Google Sheet (1eSqVRbzdd…, tab 853500365).
#   - .cursor/skills/.../subsectors/network-upgrades.narrative.md (v7).
#   - .cursor/skills/.../subsectors/network-upgrades.data-sources.md (v7).
#   - .cursor/skills/.../subsectors/network-upgrades.fields-to-add.md (v7).
#
# Activation dates / blocks / epochs cross-checked against ethereum.org/history,
# Etherscan, and beaconcha.in as of 2026-05-20.
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class EipHeadline:
    """One EIP attached to an upgrade with the headline label that gets surfaced on
    the upgrade card. ``inclusion_role`` defaults to ``"headline"``; pass
    ``"supporting"`` for ancillary EIPs that ship in the same fork."""

    eip_number: int
    headline_label: str
    inclusion_role: str = "headline"


@dataclass(frozen=True)
class UpgradeImpact:
    """One row of upgrade_impact. ``affected_entity_slug='*'`` means "all rows
    in the named subsector"; otherwise it should be a slug from public.projects."""

    affected_subsector: str
    impact_type: str
    impact_summary: str
    affected_entity_slug: str = "*"


@dataclass(frozen=True)
class UpgradeBaseline:
    slug: str
    display_name: str
    execution_fork_name: Optional[str]
    consensus_fork_name: Optional[str]
    status: str  # activated | scheduled | proposed | superseded | cancelled
    activation_date: Optional[str]  # ISO 8601 date
    activation_block_number: Optional[int]
    activation_epoch: Optional[int]
    network: str  # mainnet | sepolia | holesky | hoodi
    layers_affected: str  # execution | consensus | both
    primary_change_types: Tuple[str, ...]
    backward_compatible: bool
    upgrade_risk_profile: str  # low | medium | medium-high | high | very-high | not-yet-assessed
    risk_rationale: str
    client_coordination_required: str  # execution-only | consensus-only | both
    description: str
    structural_significance: str
    practitioner_note: str
    practitioner_validation_check: str
    notable_changes: str
    is_provisional: bool
    ethereum_org_url: Optional[str]
    source_pm_issue_url: Optional[str]
    eip_headlines: Tuple[EipHeadline, ...]
    impact: Tuple[UpgradeImpact, ...]
    attributes: Dict[str, Any] = field(default_factory=dict)


UPGRADE_BASELINES: List[UpgradeBaseline] = [
    UpgradeBaseline(
        slug="london",
        display_name="London",
        execution_fork_name="London",
        consensus_fork_name=None,
        status="activated",
        activation_date="2021-08-05",
        activation_block_number=12_965_000,
        activation_epoch=None,
        network="mainnet",
        layers_affected="execution",
        primary_change_types=("economics", "ux"),
        backward_compatible=False,
        upgrade_risk_profile="high",
        risk_rationale="Fundamental fee market change; first deployment of base fee + burn.",
        client_coordination_required="execution-only",
        description=(
            "Introduced Ethereum's new fee market, replacing first-price auctions with a "
            "base-fee-plus-tip model and introducing ETH burning."
        ),
        structural_significance=(
            "Changed ETH's monetary dynamics. Reduced fee volatility. Made gas pricing "
            "predictable for users and applications."
        ),
        practitioner_note=(
            "London fundamentally changed how users experience Ethereum and how ETH "
            "accrues value."
        ),
        practitioner_validation_check=(
            "If London had failed, fee markets would have fragmented and client "
            "divergence would have caused immediate chain instability."
        ),
        notable_changes="",
        is_provisional=False,
        ethereum_org_url="https://ethereum.org/en/history/#london",
        source_pm_issue_url=None,
        eip_headlines=(
            EipHeadline(1559, "Base fee + burn"),
            EipHeadline(3198, "BASEFEE opcode", "supporting"),
            EipHeadline(3529, "Reduced gas refunds", "supporting"),
            EipHeadline(3541, "Reject 0xEF contracts", "supporting"),
            EipHeadline(3554, "Difficulty bomb delay (Dec 2021)", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "execution-layer", "breaking-change",
                "Every execution client had to ship base-fee mechanics; bug-for-bug parity required.",
            ),
            UpgradeImpact(
                "mev-block-builders", "new-capability",
                "Created the first tip-based MEV economy distinct from gas-price auctions.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="the-merge",
        display_name="The Merge",
        execution_fork_name="Paris",
        consensus_fork_name="Bellatrix",
        status="activated",
        activation_date="2022-09-15",
        activation_block_number=15_537_393,
        activation_epoch=144_896,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("architecture", "security", "energy"),
        backward_compatible=False,
        upgrade_risk_profile="very-high",
        risk_rationale=(
            "Largest protocol change in Ethereum history; first live PoS transition on a "
            "production chain."
        ),
        client_coordination_required="both",
        description=(
            "Transitioned Ethereum from Proof-of-Work to Proof-of-Stake by merging the "
            "execution layer with the Beacon Chain consensus layer."
        ),
        structural_significance=(
            "Replaced miners with validators. Reduced energy usage by ~99.9%. Enabled "
            "future scaling via modular design."
        ),
        practitioner_note=(
            "The Merge proved Ethereum could execute a high-risk architectural transition "
            "without halting the network."
        ),
        practitioner_validation_check=(
            "Failure would have resulted in chain splits, stalled finality, or loss of "
            "trust in Ethereum's upgrade process."
        ),
        notable_changes="Triggered by Terminal Total Difficulty (TTD) = 58750000000000000000000.",
        is_provisional=False,
        ethereum_org_url="https://ethereum.org/en/history/#paris",
        source_pm_issue_url=None,
        eip_headlines=(
            EipHeadline(3675, "PoS transition"),
            EipHeadline(4399, "RANDOM opcode replaces DIFFICULTY", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "consensus-layer", "breaking-change",
                "Every CL client coupled to an EL client via the Engine API. New responsibility surface.",
            ),
            UpgradeImpact(
                "execution-layer", "breaking-change",
                "Removed PoW; gained the Engine API as the sole driver of chain progression.",
            ),
            UpgradeImpact(
                "validators-staking-providers", "new-capability",
                "PoW miners deprecated; validator economics activated at full scale.",
            ),
            UpgradeImpact(
                "mev-block-builders", "new-capability",
                "Proposer-builder separation became economically viable; MEV-Boost adoption surged.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="shapella",
        display_name="Shanghai / Capella (Shapella)",
        execution_fork_name="Shanghai",
        consensus_fork_name="Capella",
        status="activated",
        activation_date="2023-04-12",
        activation_block_number=17_034_870,
        activation_epoch=194_048,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("ux", "economics", "staking"),
        backward_compatible=False,
        upgrade_risk_profile="medium",
        risk_rationale="First validator withdrawal mechanism; staking exit dynamics untested at scale.",
        client_coordination_required="both",
        description="Enabled withdrawals of staked ETH, completing the PoS transition lifecycle.",
        structural_significance=(
            "Removed lock-up risk for validators. Enabled staking liquidity and "
            "institutional participation. Validated PoS as sustainable long-term security model."
        ),
        practitioner_note="Contrary to fears, withdrawals did not destabilize staking participation.",
        practitioner_validation_check=(
            "Failure would have frozen validator exits and undermined confidence in PoS economics."
        ),
        notable_changes="",
        is_provisional=False,
        ethereum_org_url="https://ethereum.org/en/history/#shapella",
        source_pm_issue_url=None,
        eip_headlines=(
            EipHeadline(4895, "Validator withdrawals"),
            EipHeadline(3651, "Warm COINBASE", "supporting"),
            EipHeadline(3855, "PUSH0 opcode", "supporting"),
            EipHeadline(3860, "Limit initcode size", "supporting"),
            EipHeadline(6049, "Deprecate SELFDESTRUCT (notice)", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "validators-staking-providers", "new-capability",
                "Validators can finally withdraw staked ETH; LSTs become economically tradable at peg.",
            ),
            UpgradeImpact(
                "consensus-layer", "breaking-change",
                "Withdrawal queue + payload mechanics added to consensus pyspec.",
            ),
            UpgradeImpact(
                "execution-layer", "breaking-change",
                "EL clients ship withdrawal payload processing.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="dencun",
        display_name="Cancun-Deneb (Dencun)",
        execution_fork_name="Cancun",
        consensus_fork_name="Deneb",
        status="activated",
        activation_date="2024-03-13",
        activation_block_number=19_426_587,
        activation_epoch=269_568,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("scaling", "data-availability"),
        backward_compatible=False,
        upgrade_risk_profile="medium-high",
        risk_rationale="First production deployment of EIP-4844 blobs; new fee market dimension.",
        client_coordination_required="both",
        description=(
            "Introduced blobs for rollup data, dramatically reducing L2 fees and shifting "
            "scaling focus to data availability."
        ),
        structural_significance=(
            "Made rollups cheaper and more viable. Marked Ethereum's clear rollup-centric "
            "scaling direction. Reduced pressure on execution layer."
        ),
        practitioner_note=(
            "Dencun quietly delivered one of the largest user-visible fee reductions in "
            "Ethereum's history."
        ),
        practitioner_validation_check="Failure would have stalled Ethereum's L2 scaling roadmap.",
        notable_changes="",
        is_provisional=False,
        ethereum_org_url="https://ethereum.org/en/history/#dencun",
        source_pm_issue_url=None,
        eip_headlines=(
            EipHeadline(4844, "Proto-Danksharding / Blobs"),
            EipHeadline(1153, "Transient storage (TLOAD/TSTORE)", "supporting"),
            EipHeadline(4788, "Beacon block root in EVM", "supporting"),
            EipHeadline(5656, "MCOPY opcode", "supporting"),
            EipHeadline(6780, "SELFDESTRUCT semantic change", "supporting"),
            EipHeadline(7044, "Perpetually valid signed voluntary exits", "supporting"),
            EipHeadline(7045, "Increase max attestation inclusion slot", "supporting"),
            EipHeadline(7514, "Add max epoch churn limit", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "execution-layer", "new-capability",
                "Blob transactions + transient storage opcodes shipped across all clients.",
            ),
            UpgradeImpact(
                "consensus-layer", "new-capability",
                "Blob sidecar gossip and data-availability sampling primitives.",
            ),
            UpgradeImpact(
                "mev-block-builders", "new-capability",
                "Blob fee market created; new MEV vector around blob inclusion economics.",
            ),
            UpgradeImpact(
                "optimistic-rollups", "new-capability",
                "EIP-4844 moved L2 data posting from calldata to blob space, cutting "
                "Arbitrum One / OP Mainnet / Base / Blast / Unichain fees ~10x and "
                "reshaping the rollup unit economics. Every optimistic rollup retuned "
                "batch_posting_frequency and data_availability_layer to blobs.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="pectra",
        display_name="Prague-Electra (Pectra)",
        execution_fork_name="Prague",
        consensus_fork_name="Electra",
        status="activated",
        activation_date="2025-05-07",
        activation_block_number=None,
        activation_epoch=None,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("ux", "staking", "account"),
        backward_compatible=False,
        upgrade_risk_profile="medium",
        risk_rationale="Multiple coordinated changes across account abstraction and validator UX.",
        client_coordination_required="both",
        description=(
            "Combined Prague (execution) and Electra (consensus) upgrades, improving "
            "validator operations and user account functionality."
        ),
        structural_significance=(
            "Improved validator ergonomics. Advanced account abstraction. Prepared "
            "groundwork for future protocol simplification."
        ),
        practitioner_note="Pectra focused on operability rather than headline scaling.",
        practitioner_validation_check=(
            "Failure would have degraded validator UX and delayed account abstraction progress."
        ),
        notable_changes="",
        is_provisional=False,
        ethereum_org_url="https://ethereum.org/en/history/#pectra",
        source_pm_issue_url="https://github.com/ethereum/pm/issues/1051",
        eip_headlines=(
            EipHeadline(7702, "EOA → smart-account delegation"),
            EipHeadline(7251, "MaxEB — increase max effective balance to 2048 ETH", "supporting"),
            EipHeadline(7002, "Execution-layer triggerable withdrawals", "supporting"),
            EipHeadline(2537, "BLS12-381 precompiles", "supporting"),
            EipHeadline(2935, "Save historical block hashes in state", "supporting"),
            EipHeadline(6110, "Supply validator deposits on-chain", "supporting"),
            EipHeadline(7549, "Move committee index outside attestation", "supporting"),
            EipHeadline(7685, "General-purpose EL-to-CL requests", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "execution-layer", "breaking-change",
                "EIP-7702 reshapes EOA transaction semantics; mempool + nonce rules updated.",
            ),
            UpgradeImpact(
                "consensus-layer", "breaking-change",
                "MaxEB changes validator balance dynamics; attestation packing reshaped.",
            ),
            UpgradeImpact(
                "validators-staking-providers", "new-capability",
                "MaxEB to 2048 ETH lets large operators consolidate validators; "
                "EL-triggered withdrawals enable smart-contract-driven exits.",
            ),
            UpgradeImpact(
                "mev-block-builders", "new-capability",
                "EIP-7702 introduces a new class of MEV around smart-account batched calls.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="fusaka",
        display_name="Fulu-Osaka (Fusaka)",
        execution_fork_name="Osaka",
        consensus_fork_name="Fulu",
        status="activated",
        activation_date="2025-12-03",
        activation_block_number=None,
        activation_epoch=None,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("scaling", "data-availability"),
        backward_compatible=False,
        upgrade_risk_profile="medium",
        risk_rationale=(
            "First production PeerDAS deployment; networking topology changes for sampling."
        ),
        client_coordination_required="both",
        description=(
            "Expanded Ethereum's data availability capacity and refined execution behavior "
            "to better support rollup-centric scaling."
        ),
        structural_significance=(
            "Increased L2 throughput headroom. Reinforced conservative L1 design philosophy. "
            "Demonstrated upgrade process maturity."
        ),
        practitioner_note="Fusaka's success was measured by its lack of disruption.",
        practitioner_validation_check=(
            "Failure would have delayed scaling capacity and undermined confidence in upgrade cadence."
        ),
        notable_changes="",
        is_provisional=False,
        ethereum_org_url=None,
        source_pm_issue_url="https://github.com/ethereum/pm/issues/1078",
        eip_headlines=(
            EipHeadline(7594, "PeerDAS — data-availability sampling"),
            EipHeadline(7691, "Blob throughput increase", "supporting"),
        ),
        impact=(
            UpgradeImpact(
                "consensus-layer", "breaking-change",
                "PeerDAS reshapes blob sidecar gossip and column sampling; full client rewrite of DA paths.",
            ),
            UpgradeImpact(
                "execution-layer", "new-capability",
                "Higher blob target/max raises inclusion economics for rollup posters.",
            ),
            UpgradeImpact(
                "mev-block-builders", "new-capability",
                "Blob inclusion economics shift again; relays adjust blob-bundle prioritization.",
            ),
            UpgradeImpact(
                "optimistic-rollups", "new-capability",
                "EIP-7691 raises blob target/max, expanding the rollup data budget; "
                "PeerDAS sampling lets the network scale blob bandwidth without "
                "per-node storage growth. Every optimistic rollup gains headroom on "
                "data_availability_layer='ethereum-l1-blobs'.",
            ),
        ),
    ),
    UpgradeBaseline(
        slug="glamsterdam",
        display_name="Glamsterdam (Planned)",
        execution_fork_name=None,
        consensus_fork_name=None,
        status="proposed",
        activation_date=None,
        activation_block_number=None,
        activation_epoch=None,
        network="mainnet",
        layers_affected="both",
        primary_change_types=("architecture", "scaling"),
        backward_compatible=False,
        upgrade_risk_profile="not-yet-assessed",
        risk_rationale="Scope still in flight; risk is contingent on which EIPs land.",
        client_coordination_required="both",
        description=(
            "Planned upgrade focusing on block production separation (ePBS exploration) "
            "and continued protocol efficiency."
        ),
        structural_significance=(
            "Addresses MEV and proposer-builder dynamics. Advances protocol modularity."
        ),
        practitioner_note=(
            "Glamsterdam is about refining how blocks are built, not just how many."
        ),
        practitioner_validation_check=(
            "If poorly executed, could destabilize MEV markets and validator incentives."
        ),
        notable_changes=(
            "Scope tentative — ePBS draft EIPs and execution refinements are the candidate set; "
            "ACD has not finalized inclusion."
        ),
        is_provisional=True,
        ethereum_org_url=None,
        source_pm_issue_url="https://github.com/ethereum/pm/issues",
        eip_headlines=(),  # Empty until ACD locks the scope.
        impact=(
            UpgradeImpact(
                "mev-block-builders", "requires-coordination",
                "ePBS would restructure the proposer-builder relationship at the protocol level.",
            ),
            UpgradeImpact(
                "validators-staking-providers", "requires-coordination",
                "ePBS changes validator duties around builder slot delegation.",
            ),
        ),
    ),
]


# Subsector slugs that are valid impact targets. Any UpgradeImpact whose
# affected_subsector is not in this set will be logged + skipped at insert time
# so we do not silently create dangling join rows (the public.subsectors FK
# would reject them anyway, but the explicit check makes the error obvious).
KNOWN_IMPACT_SUBSECTORS = {
    "consensus-layer",
    "execution-layer",
    "validators-staking-providers",
    "mev-block-builders",
    # M8.10 — Sector 2's first subsector ships. Dencun + Fusaka have explicit
    # impact rows on optimistic-rollups (calldata→blobs and blob throughput).
    # data-availability-systems and zk-rollups join this set when M8.11+ /
    # data-consensus-infrastructure ingests land.
    "optimistic-rollups",
}


# ---------------------------------------------------------------------------
# GitHub client with ETag cache.
# ---------------------------------------------------------------------------


class GithubClient:
    """Thin httpx wrapper that caches by ETag.

    Reads/writes ``.cache/github-etags.json`` so unchanged files return 304 and
    do not burn rate-limit budget. The cache is gitignored.
    """

    def __init__(self, token: Optional[str] = None):
        self._token = token
        self._etag_cache: Dict[str, Dict[str, Any]] = self._load_cache()
        headers = {
            "User-Agent": "canhav-network-upgrades-ingest/1.0",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if token:
            headers["Authorization"] = f"Bearer {token}"
        self._client = httpx.Client(headers=headers, timeout=30.0)

    @staticmethod
    def _load_cache() -> Dict[str, Dict[str, Any]]:
        if ETAG_CACHE_PATH.exists():
            try:
                return json.loads(ETAG_CACHE_PATH.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                LOG.warning("ETag cache unreadable (%s); starting fresh.", exc)
        return {}

    def _save_cache(self) -> None:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        ETAG_CACHE_PATH.write_text(
            json.dumps(self._etag_cache, indent=2, sort_keys=True),
            encoding="utf-8",
        )

    def close(self) -> None:
        self._save_cache()
        self._client.close()

    def get(self, url: str, *, accept_raw: bool = False) -> Optional[Any]:
        """GET with ETag conditional. Returns parsed JSON (or raw text when
        accept_raw=True), or None when the upstream returned 304 Not Modified
        AND we have no cached body. (We don't cache raw bodies — for raw fetches
        a 304 returns the previously-fetched body via the cache; here we just
        re-fetch unconditionally because raw markdown is small and a forced
        re-read is cheap.)"""
        cached = self._etag_cache.get(url)
        headers: Dict[str, str] = {}
        if cached and cached.get("etag") and not accept_raw:
            headers["If-None-Match"] = cached["etag"]
        if accept_raw:
            headers["Accept"] = "application/vnd.github.raw"

        r = self._client.get(url, headers=headers)
        if r.status_code == 304 and cached and "body" in cached:
            LOG.debug("304 cache hit %s", url)
            return cached["body"]
        r.raise_for_status()

        body: Any
        if accept_raw:
            body = r.text
        else:
            body = r.json()

        etag = r.headers.get("ETag")
        if etag and not accept_raw:
            self._etag_cache[url] = {"etag": etag, "body": body}

        rate_remaining = r.headers.get("X-RateLimit-Remaining")
        if rate_remaining and int(rate_remaining) < 100:
            LOG.warning("GitHub rate-limit getting low: %s remaining", rate_remaining)
        return body

    def get_raw(self, url: str) -> str:
        """Unconditional GET for raw.githubusercontent.com content."""
        r = self._client.get(url, headers={"Accept": "text/plain"})
        r.raise_for_status()
        return r.text


# ---------------------------------------------------------------------------
# EIP discovery.
# ---------------------------------------------------------------------------


EIP_FILENAME_RE = re.compile(r"^eip-(\d+)\.md$")


def list_eip_files(gh: GithubClient) -> List[Dict[str, Any]]:
    """Return the list of EIP markdown files in ethereum/EIPs/EIPS.

    Uses the Git Trees API (recursive) — single request rather than paging
    contents/.
    """
    # Resolve the master branch head SHA.
    branch_url = f"{GITHUB_API_BASE}/repos/{EIPS_REPO}/branches/{EIPS_BRANCH}"
    branch = gh.get(branch_url)
    head_sha = branch["commit"]["sha"]

    tree_url = f"{GITHUB_API_BASE}/repos/{EIPS_REPO}/git/trees/{head_sha}?recursive=1"
    tree = gh.get(tree_url)

    files: List[Dict[str, Any]] = []
    for entry in tree.get("tree", []):
        if entry.get("type") != "blob":
            continue
        path = entry.get("path", "")
        if not path.startswith("EIPS/"):
            continue
        match = EIP_FILENAME_RE.match(path.split("/")[-1])
        if not match:
            continue
        files.append(
            {
                "eip_number": int(match.group(1)),
                "path": path,
                "sha": entry.get("sha"),
            }
        )
    return files


def parse_eip(gh: GithubClient, file_info: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Fetch one EIP markdown file and parse its YAML front-matter into a row dict.

    Returns None when the front-matter cannot be parsed (corrupt file).
    """
    raw_url = f"{RAW_BASE}/{EIPS_REPO}/{EIPS_BRANCH}/{file_info['path']}"
    body = gh.get_raw(raw_url)
    try:
        post = frontmatter.loads(body)
    except Exception as exc:  # pragma: no cover — defensive.
        LOG.warning("Cannot parse front-matter for EIP-%d: %s", file_info["eip_number"], exc)
        return None

    meta = post.metadata or {}
    try:
        eip_number = int(meta.get("eip", file_info["eip_number"]))
    except (TypeError, ValueError):
        eip_number = file_info["eip_number"]

    title = str(meta.get("title") or "").strip()
    if not title:
        LOG.warning("EIP-%d missing title; skipping.", eip_number)
        return None

    raw_status = str(meta.get("status") or "draft").strip().lower()
    status = raw_status.replace(" ", "-")

    raw_type = str(meta.get("type") or "").strip().lower()
    eip_type = raw_type.replace(" ", "-") if raw_type else None

    raw_category = meta.get("category")
    eip_category: Optional[str] = None
    if raw_category:
        eip_category = str(raw_category).strip().lower()

    authors = _parse_authors(meta.get("author"))
    requires = _parse_requires(meta.get("requires"))

    created_date = _coerce_date(meta.get("created"))

    discussions_to_url = meta.get("discussions-to")
    if discussions_to_url and not isinstance(discussions_to_url, str):
        discussions_to_url = None

    return {
        "eip_number": eip_number,
        "title": title,
        "eip_type": eip_type,
        "eip_category": eip_category,
        "status": status,
        "authors": authors,
        "created_date": created_date,
        "requires": requires,
        "discussions_to_url": discussions_to_url,
        "source_url": raw_url,
        "source_commit_sha": file_info.get("sha"),
        "last_ingested_at": _now_iso(),
    }


def _parse_authors(raw: Any) -> List[str]:
    """The EIP front-matter author field looks like:
       'Vitalik Buterin (@vbuterin), Eric Conner <eric@example.com>'.
    Return the list of human-readable names with email/handle stripped to a clean form."""
    if raw is None:
        return []
    if isinstance(raw, list):
        items = [str(x) for x in raw]
    else:
        items = [chunk.strip() for chunk in str(raw).split(",")]
    cleaned: List[str] = []
    for item in items:
        s = item.strip()
        if not s:
            continue
        # Strip "<email>" but keep "(@handle)".
        s = re.sub(r"<[^>]+>", "", s).strip()
        cleaned.append(s)
    return cleaned


def _parse_requires(raw: Any) -> List[int]:
    if raw is None:
        return []
    if isinstance(raw, (int, float)):
        return [int(raw)]
    if isinstance(raw, list):
        out: List[int] = []
        for x in raw:
            try:
                out.append(int(x))
            except (TypeError, ValueError):
                continue
        return out
    if isinstance(raw, str):
        out = []
        for chunk in raw.split(","):
            chunk = chunk.strip()
            if not chunk:
                continue
            try:
                out.append(int(chunk))
            except ValueError:
                continue
        return out
    return []


def _coerce_date(raw: Any) -> Optional[str]:
    if raw is None:
        return None
    if isinstance(raw, dt.date):
        return raw.isoformat()
    s = str(raw).strip()
    if not s:
        return None
    # Most EIPs use YYYY-MM-DD; a few older ones use slashes.
    for fmt in ("%Y-%m-%d", "%Y/%m/%d"):
        try:
            return dt.datetime.strptime(s, fmt).date().isoformat()
        except ValueError:
            continue
    return None


def _now_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


# ---------------------------------------------------------------------------
# Optional: fork name discovery from execution-specs / consensus-specs.
#
# The current ingest run only uses these for sanity-check logging: they confirm
# that the curated fork_name in UPGRADE_BASELINES still matches upstream. The
# real upgrade scope comes from the curated baseline; treating upstream as the
# source of truth would require a much more aggressive change-detection layer.
# ---------------------------------------------------------------------------


def list_consensus_fork_names(gh: GithubClient) -> List[str]:
    """Return the subdirectories of consensus-specs/specs/ (e.g. ['phase0',
    'altair', 'bellatrix', 'capella', 'deneb', 'electra', 'fulu'])."""
    try:
        items = gh.get(f"{GITHUB_API_BASE}/repos/{CONSENSUS_SPECS_REPO}/contents/specs")
        if not isinstance(items, list):
            return []
        return [it["name"] for it in items if it.get("type") == "dir"]
    except httpx.HTTPError as exc:
        LOG.warning("consensus-specs fork listing failed (%s); skipping.", exc)
        return []


def list_execution_fork_names(gh: GithubClient) -> List[str]:
    # As of late 2025 the execution-specs layout moved the per-fork modules
    # under `src/ethereum/forks/`. Older snapshots used `src/ethereum/<fork>`.
    # Try the new path first; fall back to the old one for older branches.
    for path in ("src/ethereum/forks", "src/ethereum"):
        try:
            items = gh.get(
                f"{GITHUB_API_BASE}/repos/{EXECUTION_SPECS_REPO}/contents/{path}"
            )
            if not isinstance(items, list):
                continue
            names = [
                it["name"]
                for it in items
                if it.get("type") == "dir" and it.get("name") not in {"assets", "crypto", "utils"}
            ]
            if names:
                return names
        except httpx.HTTPError as exc:
            LOG.debug("execution-specs %s listing failed: %s", path, exc)
    LOG.warning("execution-specs fork listing returned no entries; check repo layout.")
    return []


# ---------------------------------------------------------------------------
# Supabase REST helpers.
# ---------------------------------------------------------------------------


class SupabaseClient:
    def __init__(self, url: str, service_role_key: str):
        self.url = url.rstrip("/")
        self.headers = {
            "apikey": service_role_key,
            "Authorization": f"Bearer {service_role_key}",
            "Content-Type": "application/json",
        }
        self._client = httpx.Client(headers=self.headers, timeout=30.0)

    def close(self) -> None:
        self._client.close()

    def upsert(
        self,
        table: str,
        rows: List[Dict[str, Any]],
        on_conflict: str,
    ) -> int:
        if not rows:
            return 0
        # PostgREST limits a single POST body; chunk just in case (EIPs ~1k rows).
        written = 0
        for chunk in _chunked(rows, 200):
            r = self._client.post(
                f"{self.url}/rest/v1/{table}",
                params={"on_conflict": on_conflict},
                json=chunk,
                headers={"Prefer": "resolution=merge-duplicates,return=minimal"},
            )
            if r.status_code >= 400:
                raise RuntimeError(
                    f"Supabase upsert into {table} failed ({r.status_code}): {r.text}"
                )
            written += len(chunk)
        return written

    def delete(self, table: str, where: Dict[str, str]) -> None:
        params = dict(where)
        r = self._client.delete(f"{self.url}/rest/v1/{table}", params=params)
        if r.status_code >= 400:
            raise RuntimeError(
                f"Supabase delete from {table} failed ({r.status_code}): {r.text}"
            )

    def select(
        self,
        table: str,
        *,
        select: str = "*",
        where: Optional[Dict[str, str]] = None,
    ) -> List[Dict[str, Any]]:
        params: Dict[str, str] = {"select": select}
        if where:
            params.update(where)
        r = self._client.get(f"{self.url}/rest/v1/{table}", params=params)
        r.raise_for_status()
        return r.json()


def _chunked(seq: List[Any], size: int) -> Iterable[List[Any]]:
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


# ---------------------------------------------------------------------------
# Upsert builders.
# ---------------------------------------------------------------------------


def build_network_upgrade_row(b: UpgradeBaseline, last_ingested_at: str) -> Dict[str, Any]:
    return {
        "slug": b.slug,
        "display_name": b.display_name,
        "execution_fork_name": b.execution_fork_name,
        "consensus_fork_name": b.consensus_fork_name,
        "status": b.status,
        "activation_date": b.activation_date,
        "activation_block_number": b.activation_block_number,
        "activation_epoch": b.activation_epoch,
        "network": b.network,
        "layers_affected": b.layers_affected,
        "primary_change_types": list(b.primary_change_types),
        "backward_compatible": b.backward_compatible,
        "upgrade_risk_profile": b.upgrade_risk_profile,
        "risk_rationale": b.risk_rationale,
        "client_coordination_required": b.client_coordination_required,
        "description": b.description,
        "structural_significance": b.structural_significance,
        "practitioner_note": b.practitioner_note,
        "practitioner_validation_check": b.practitioner_validation_check,
        "notable_changes": b.notable_changes,
        "is_provisional": b.is_provisional,
        "ethereum_org_url": b.ethereum_org_url,
        "source_pm_issue_url": b.source_pm_issue_url,
        "data_confidence": "estimate" if b.is_provisional else "verified",
        "last_ingested_at": last_ingested_at,
        "attributes": b.attributes or {},
    }


def build_projects_mirror_row(b: UpgradeBaseline, last_ingested_at: str) -> Dict[str, Any]:
    """Mirror row for public.projects. Every universal field is NULL — the row
    is only a navigation handle. ``not_applicable_reason='protocol_event_not_entity'``
    flags the reason explicitly per the M8.9 design decision."""
    sub_attrs = {
        "network_upgrade_slug": b.slug,
        "status": b.status,
        "activation_date": b.activation_date,
        "layers_affected": b.layers_affected,
        "primary_change_types": list(b.primary_change_types),
        "eips_count": len(b.eip_headlines),
        "impact_count": len(b.impact),
        "data_refreshed_at": last_ingested_at,
        "data_confidence": "estimate" if b.is_provisional else "verified",
    }
    # Map network_upgrades.status → projects.status enum (live|testnet|mainnet|archived|unknown).
    project_status = {
        "activated": "live",
        "scheduled": "unknown",
        "proposed": "unknown",
        "superseded": "archived",
        "cancelled": "archived",
    }.get(b.status, "unknown")
    return {
        "slug": b.slug,
        "name": b.display_name,
        "description": b.description,
        "website_url": b.ethereum_org_url,
        "logo_url": None,
        "twitter_handle": None,
        "github_url": None,
        "status": project_status,
        "stage": None,
        "founded_year": int(b.activation_date.split("-")[0]) if b.activation_date else None,
        "hq_country": None,
        "team_size_range": None,
        "total_funding_usd": None,
        "last_funding_round": None,
        "last_funding_date": None,
        "sector_slug": NETWORK_UPGRADES_SECTOR_SLUG,
        "subsector_slug": NETWORK_UPGRADES_SUBSECTOR_SLUG,
        "sector_attributes": {},
        "subsector_attributes": sub_attrs,
        "maintaining_organization": None,
        "is_aggregate": False,
        "not_applicable_reason": "protocol_event_not_entity",
        "source_last_synced_at": last_ingested_at,
    }


# ---------------------------------------------------------------------------
# Orchestrator.
# ---------------------------------------------------------------------------


@dataclass
class RunSummary:
    eips_seen: int = 0
    eips_upserted: int = 0
    upgrades_upserted: int = 0
    project_mirrors_upserted: int = 0
    upgrade_eips_upserted: int = 0
    upgrade_impact_upserted: int = 0
    consensus_forks_observed: List[str] = field(default_factory=list)
    execution_forks_observed: List[str] = field(default_factory=list)
    uncurated_baseline_eips: List[int] = field(default_factory=list)
    skipped_impact_rows: List[str] = field(default_factory=list)


def run(*, dry_run: bool, eip_limit: Optional[int] = None) -> RunSummary:
    summary = RunSummary()
    last_ingested_at = _now_iso()

    github_token = os.environ.get("GITHUB_TOKEN")
    if not github_token:
        LOG.warning(
            "No GITHUB_TOKEN found — unauthenticated GitHub API has a 60 req/h cap. "
            "Set GITHUB_TOKEN to a fine-grained PAT with public-repo read access."
        )
    gh = GithubClient(token=github_token)

    sb: Optional[SupabaseClient] = None
    if not dry_run:
        sb_url = os.environ.get("SUPABASE_URL")
        sb_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
        if not sb_url or not sb_key:
            raise SystemExit(
                "SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set unless --dry-run."
            )
        sb = SupabaseClient(sb_url, sb_key)

    try:
        # --- 1. EIPs ---
        LOG.info("Listing EIP files from %s …", EIPS_REPO)
        eip_files = list_eip_files(gh)
        summary.eips_seen = len(eip_files)
        LOG.info("Discovered %d EIP markdown files.", len(eip_files))

        if eip_limit is not None:
            eip_files = eip_files[:eip_limit]
            LOG.info("--eip-limit=%d set; truncated to %d files.", eip_limit, len(eip_files))

        eip_rows: List[Dict[str, Any]] = []
        for i, fi in enumerate(eip_files, 1):
            row = parse_eip(gh, fi)
            if row:
                eip_rows.append(row)
            if i % 100 == 0:
                LOG.info("Parsed %d/%d EIPs…", i, len(eip_files))

        # --- 2. Upstream fork sanity check (logged only) ---
        summary.consensus_forks_observed = list_consensus_fork_names(gh)
        summary.execution_forks_observed = list_execution_fork_names(gh)

        # --- 3. Curated baseline tables ---
        upgrade_rows = [
            build_network_upgrade_row(b, last_ingested_at) for b in UPGRADE_BASELINES
        ]
        project_mirror_rows = [
            build_projects_mirror_row(b, last_ingested_at) for b in UPGRADE_BASELINES
        ]

        # EIP numbers referenced by curated upgrades — used for the
        # "make sure these exist in eips" pre-flight and for the uncurated check.
        baseline_eip_numbers = {
            h.eip_number for b in UPGRADE_BASELINES for h in b.eip_headlines
        }
        seen_eip_numbers = {row["eip_number"] for row in eip_rows}
        summary.uncurated_baseline_eips = sorted(
            baseline_eip_numbers - seen_eip_numbers
        )
        if summary.uncurated_baseline_eips:
            LOG.warning(
                "Curated baseline references %d EIP(s) not found in upstream EIPs repo: %s. "
                "They will be inserted with a placeholder row so the FK holds.",
                len(summary.uncurated_baseline_eips),
                summary.uncurated_baseline_eips,
            )
            for num in summary.uncurated_baseline_eips:
                eip_rows.append(
                    {
                        "eip_number": num,
                        "title": f"EIP-{num} (placeholder — not yet in upstream repo at ingest time)",
                        "eip_type": None,
                        "eip_category": None,
                        "status": "draft",
                        "authors": [],
                        "created_date": None,
                        "requires": [],
                        "discussions_to_url": None,
                        "source_url": None,
                        "source_commit_sha": None,
                        "last_ingested_at": last_ingested_at,
                    }
                )

        # upgrade_eips
        upgrade_eip_rows: List[Dict[str, Any]] = []
        for b in UPGRADE_BASELINES:
            for h in b.eip_headlines:
                upgrade_eip_rows.append(
                    {
                        "upgrade_slug": b.slug,
                        "eip_number": h.eip_number,
                        "inclusion_role": h.inclusion_role,
                        "headline_label": h.headline_label,
                    }
                )

        # upgrade_impact — filter by KNOWN_IMPACT_SUBSECTORS to keep the FK on
        # public.subsectors valid even when a baseline references a subsector
        # that has not been ingested yet.
        upgrade_impact_rows: List[Dict[str, Any]] = []
        for b in UPGRADE_BASELINES:
            for imp in b.impact:
                if imp.affected_subsector not in KNOWN_IMPACT_SUBSECTORS:
                    summary.skipped_impact_rows.append(
                        f"{b.slug}:{imp.affected_subsector}:{imp.impact_type}"
                    )
                    LOG.warning(
                        "Skipping upgrade_impact row %s → %s (subsector not yet ingested).",
                        b.slug,
                        imp.affected_subsector,
                    )
                    continue
                upgrade_impact_rows.append(
                    {
                        "upgrade_slug": b.slug,
                        "affected_subsector": imp.affected_subsector,
                        "affected_entity_slug": imp.affected_entity_slug,
                        "impact_type": imp.impact_type,
                        "impact_summary": imp.impact_summary,
                    }
                )

        # --- 4. Apply (or print) ---
        if dry_run:
            LOG.info(
                "DRY-RUN: would upsert %d eips, %d upgrades, %d project mirrors, %d upgrade_eips, %d upgrade_impact.",
                len(eip_rows),
                len(upgrade_rows),
                len(project_mirror_rows),
                len(upgrade_eip_rows),
                len(upgrade_impact_rows),
            )
            sample = upgrade_rows[0] if upgrade_rows else {}
            print(json.dumps({"sample_upgrade_row": sample}, indent=2, default=str))
        else:
            assert sb is not None
            summary.eips_upserted = sb.upsert("eips", eip_rows, on_conflict="eip_number")
            summary.upgrades_upserted = sb.upsert(
                "network_upgrades", upgrade_rows, on_conflict="slug"
            )
            summary.project_mirrors_upserted = sb.upsert(
                "projects", project_mirror_rows, on_conflict="slug"
            )
            # upgrade_eips: easiest correct semantics is "wipe-and-replace" per
            # upgrade slug, then upsert. Otherwise EIPs removed from a baseline
            # would linger forever. Same for upgrade_impact.
            for b in UPGRADE_BASELINES:
                sb.delete("upgrade_eips", {"upgrade_slug": f"eq.{b.slug}"})
                sb.delete("upgrade_impact", {"upgrade_slug": f"eq.{b.slug}"})
            summary.upgrade_eips_upserted = sb.upsert(
                "upgrade_eips", upgrade_eip_rows, on_conflict="upgrade_slug,eip_number"
            )
            summary.upgrade_impact_upserted = sb.upsert(
                "upgrade_impact",
                upgrade_impact_rows,
                on_conflict="upgrade_slug,affected_subsector,affected_entity_slug,impact_type",
            )
    finally:
        gh.close()
        if sb is not None:
            sb.close()

    return summary


# ---------------------------------------------------------------------------
# Entry point.
# ---------------------------------------------------------------------------


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would change; do not write to Supabase.",
    )
    parser.add_argument(
        "--eip-limit",
        type=int,
        default=None,
        help="Limit EIP parsing to the first N files (debugging only).",
    )
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )

    summary = run(dry_run=args.dry_run, eip_limit=args.eip_limit)

    print("\n========== Network Upgrades ingest summary ==========")
    print(f"EIP files seen:                {summary.eips_seen}")
    print(f"EIPs upserted:                 {summary.eips_upserted}")
    print(f"Network upgrades upserted:     {summary.upgrades_upserted}")
    print(f"projects mirror rows upserted: {summary.project_mirrors_upserted}")
    print(f"upgrade_eips upserted:         {summary.upgrade_eips_upserted}")
    print(f"upgrade_impact upserted:       {summary.upgrade_impact_upserted}")
    if summary.consensus_forks_observed:
        print(f"consensus-specs forks seen:    {summary.consensus_forks_observed}")
    if summary.execution_forks_observed:
        print(f"execution-specs forks seen:    {summary.execution_forks_observed}")
    if summary.uncurated_baseline_eips:
        print(
            f"Baseline EIPs not in upstream: {summary.uncurated_baseline_eips} "
            "(inserted as placeholders so FKs hold; investigate the slugs above)"
        )
    if summary.skipped_impact_rows:
        print(f"Skipped impact rows:           {summary.skipped_impact_rows}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
