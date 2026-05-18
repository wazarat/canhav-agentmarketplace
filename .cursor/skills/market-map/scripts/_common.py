"""Shared helpers for the market-map ingest CLIs.

Pure functions only. No top-level side effects so importing is cheap.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional

REPO_ROOT = Path(__file__).resolve().parents[4]
SKILL_ROOT = Path(__file__).resolve().parents[1]
SCHEMAS_ROOT = SKILL_ROOT / "schemas"
SECTORS_ROOT = SKILL_ROOT / "sectors"


def slugify(value: str) -> str:
    """Lowercase kebab-case slug. Strips non-alphanumeric, collapses runs of '-'."""
    value = value.strip().lower()
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-+", "-", value).strip("-")
    return value


def load_json(path: Path) -> Dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def dump_json(path: Path, payload: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def require_env(*names: str) -> Dict[str, str]:
    missing = [n for n in names if not os.getenv(n)]
    if missing:
        sys.stderr.write(
            "Missing required environment variable(s): " + ", ".join(missing) + "\n"
        )
        sys.stderr.write(
            "Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY before running this script.\n"
        )
        sys.exit(2)
    return {name: os.environ[name] for name in names}


def supabase_headers(service_role_key: str) -> Dict[str, str]:
    return {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
        "Prefer": "return=representation,resolution=merge-duplicates",
    }


def chunked(seq: List[Any], size: int) -> Iterable[List[Any]]:
    for i in range(0, len(seq), size):
        yield seq[i : i + size]


def universal_schema_path() -> Path:
    return SCHEMAS_ROOT / "universal.json"


def sector_schema_path(sector_slug: str) -> Path:
    return SCHEMAS_ROOT / "sectors" / f"{sector_slug}.json"


def subsector_schema_path(subsector_slug: str) -> Path:
    return SCHEMAS_ROOT / "subsectors" / f"{subsector_slug}.json"


def sector_dir(sector_slug: str) -> Path:
    return SECTORS_ROOT / sector_slug


def subsector_md_path(sector_slug: str, subsector_slug: str) -> Path:
    return sector_dir(sector_slug) / "subsectors" / f"{subsector_slug}.md"


def gviz_csv_url(sheet_id: str, gid: str) -> str:
    """Public gviz CSV export URL for a single tab.

    Sheet must be shared as 'anyone with link can view'. Works for both Google Sheets
    and gvis exports regardless of trailing-slash quirks.
    """
    return (
        f"https://docs.google.com/spreadsheets/d/{sheet_id}/gviz/tq?tqx=out:csv&gid={gid}"
    )


def looks_like_url(value: Optional[str]) -> bool:
    if not value:
        return False
    return value.startswith(("http://", "https://"))
