#!/usr/bin/env python3
"""Normalize a single CSV row from a source sheet into a (universal, sector_attrs, subsector_attrs) triple.

The mapping from CSV column header -> bucket is driven by an optional JSON file:

  schemas/subsectors/<subsector-slug>.column_map.json   # subsector-specific overrides
  schemas/sectors/<sector-slug>.column_map.json         # sector-wide
  schemas/universal.column_map.json                     # fallback

Each column_map file is a flat dict:

  {
    "Project Name": { "bucket": "universal", "field": "name" },
    "Consensus":    { "bucket": "sector",    "field": "consensus_mechanism" },
    "Finality":     { "bucket": "subsector", "field": "finality_time_ms", "type": "int" }
  }

If a column has no mapping, the script logs a warning and drops the value. This is intentional:
we'd rather miss data than smuggle un-typed strings into the JSONB blobs.

Deterministic: same CSV row + same column maps -> same output every time.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import logging
import sys
from pathlib import Path
from typing import Any, Dict, Optional, Tuple

from _common import (
    SCHEMAS_ROOT,
    load_json,
    looks_like_url,
    slugify,
)

logger = logging.getLogger("normalize_row")


def _coerce(value: str, type_hint: Optional[str]) -> Any:
    raw = (value or "").strip()
    if raw == "" or raw.lower() in {"n/a", "na", "tbd", "unknown", "-"}:
        return None
    if type_hint in (None, "string"):
        return raw
    if type_hint == "int":
        try:
            return int(raw.replace(",", "").replace("$", ""))
        except ValueError:
            return None
    if type_hint == "float":
        try:
            return float(raw.replace(",", "").replace("$", ""))
        except ValueError:
            return None
    if type_hint == "bool":
        return raw.lower() in {"true", "yes", "y", "1"}
    if type_hint == "date":
        # Accept YYYY-MM-DD only. Anything else passes through as a string and the JSON Schema
        # validator will reject it loudly.
        return raw
    if type_hint == "url":
        return raw if looks_like_url(raw) else None
    if type_hint == "twitter":
        return raw.lstrip("@").rsplit("/", 1)[-1] if raw else None
    return raw


def _resolve_column_map(sector_slug: str, subsector_slug: str) -> Dict[str, Dict[str, str]]:
    merged: Dict[str, Dict[str, str]] = {}
    candidates = [
        SCHEMAS_ROOT / "universal.column_map.json",
        SCHEMAS_ROOT / "sectors" / f"{sector_slug}.column_map.json",
        SCHEMAS_ROOT / "subsectors" / f"{subsector_slug}.column_map.json",
    ]
    for path in candidates:
        if path.exists():
            merged.update(load_json(path))
    return merged


def normalize(
    row: Dict[str, str],
    *,
    sector_slug: str,
    subsector_slug: str,
    column_map: Optional[Dict[str, Dict[str, str]]] = None,
) -> Tuple[Dict[str, Any], Dict[str, Any], Dict[str, Any], str]:
    """Returns (universal, sector_attributes, subsector_attributes, row_hash)."""
    column_map = column_map or _resolve_column_map(sector_slug, subsector_slug)
    universal: Dict[str, Any] = {
        "sector_slug": sector_slug,
        "subsector_slug": subsector_slug,
    }
    sector_attrs: Dict[str, Any] = {}
    subsector_attrs: Dict[str, Any] = {}

    # Build a whitespace-insensitive lookup so source sheets with `\n` or trailing spaces
    # in their headers (e.g. the L3 & Appchain Frameworks sheet) still map correctly.
    normalized_map = {k.strip(): v for k, v in column_map.items()}

    for column, raw_value in row.items():
        if column is None:
            continue
        header = column.strip()
        if not header:
            continue
        mapping = normalized_map.get(header)
        if not mapping:
            if raw_value and raw_value.strip():
                logger.debug("Dropping unmapped column %r (value=%r)", header, raw_value)
            continue
        coerced = _coerce(raw_value, mapping.get("type"))
        if coerced is None:
            continue
        bucket = mapping.get("bucket")
        field = mapping.get("field")
        if not field:
            continue
        if bucket == "universal":
            universal[field] = coerced
        elif bucket == "sector":
            sector_attrs[field] = coerced
        elif bucket == "subsector":
            subsector_attrs[field] = coerced
        else:
            logger.warning("Unknown bucket %r for column %r", bucket, header)

    # Backfill slug if the column map didn't include one.
    if "slug" not in universal and universal.get("name"):
        universal["slug"] = slugify(str(universal["name"]))

    # Stable hash of the original row -> source_row_hash for change detection.
    canonical = json.dumps(row, sort_keys=True, ensure_ascii=False).encode("utf-8")
    row_hash = hashlib.sha256(canonical).hexdigest()

    return universal, sector_attrs, subsector_attrs, row_hash


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=Path, required=True, help="Input CSV file")
    parser.add_argument("--sector", required=True)
    parser.add_argument("--subsector", required=True)
    parser.add_argument("--output", type=Path, help="Write JSON Lines to this path (default stdout)")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )

    with args.csv.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)

    out_lines = []
    for row in rows:
        universal, sector_attrs, subsector_attrs, row_hash = normalize(
            row, sector_slug=args.sector, subsector_slug=args.subsector
        )
        if not universal.get("name"):
            continue
        out_lines.append(
            json.dumps(
                {
                    "universal": universal,
                    "sector_attributes": sector_attrs,
                    "subsector_attributes": subsector_attrs,
                    "source_row_hash": row_hash,
                },
                ensure_ascii=False,
            )
        )

    output_text = "\n".join(out_lines) + ("\n" if out_lines else "")
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output_text, encoding="utf-8")
        print(f"Wrote {len(out_lines)} rows to {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(output_text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
