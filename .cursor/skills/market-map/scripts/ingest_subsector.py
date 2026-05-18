#!/usr/bin/env python3
"""End-to-end ingest for one subsector: fetch sheet -> normalize -> validate -> upsert.

Usage:
  ingest_subsector.py --slug consensus-layer [--dry-run] [--keep-tmp]

This is the script you run after editing the column map and JSON schemas for a subsector.

Side effects: writes to Supabase unless --dry-run is set.
"""
from __future__ import annotations

import argparse
import csv
import json
import logging
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

import httpx

import fetch_sheet
import normalize_row
import upsert_projects
import validate_schema
from _common import (
    require_env,
    sector_schema_path,
    subsector_schema_path,
    supabase_headers,
    universal_schema_path,
    load_json,
)

logger = logging.getLogger("ingest_subsector")


def _lookup_subsector(slug: str) -> Dict[str, str]:
    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    url = (
        f"{env['SUPABASE_URL']}/rest/v1/subsectors"
        f"?slug=eq.{slug}&select=slug,sector_slug,source_sheet_id,source_sheet_gid"
    )
    with httpx.Client(timeout=15.0) as client:
        response = client.get(url, headers=supabase_headers(env["SUPABASE_SERVICE_ROLE_KEY"]))
    if response.status_code != 200:
        raise SystemExit(f"Supabase lookup failed: {response.status_code} {response.text}")
    rows = response.json()
    if not rows:
        raise SystemExit(f"No subsector with slug={slug!r} in Supabase.")
    row = rows[0]
    if not row.get("source_sheet_id") or not row.get("source_sheet_gid"):
        raise SystemExit(
            f"Subsector {slug!r} is missing source_sheet_id/source_sheet_gid. "
            "Edit it in supabase/migrations/ or via add_subsector.py."
        )
    return row


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slug", required=True, help="Subsector slug")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-tmp", action="store_true", help="Don't delete intermediate files")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )

    subsector = _lookup_subsector(args.slug)
    sector_slug = subsector["sector_slug"]
    subsector_slug = subsector["slug"]
    sheet_id = subsector["source_sheet_id"]
    gid = subsector["source_sheet_gid"]

    work_dir = Path(tempfile.mkdtemp(prefix=f"ingest-{subsector_slug}-"))
    csv_path = work_dir / "raw.csv"
    jsonl_path = work_dir / "normalized.jsonl"

    logger.info("Fetching sheet %s tab %s -> %s", sheet_id, gid, csv_path)
    csv_body = fetch_sheet.fetch(sheet_id, gid)
    csv_path.write_text(csv_body, encoding="utf-8")

    logger.info("Normalizing rows -> %s", jsonl_path)
    with csv_path.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        rows = list(reader)

    out_lines: List[str] = []
    for row in rows:
        universal, sector_attrs, subsector_attrs, row_hash = normalize_row.normalize(
            row, sector_slug=sector_slug, subsector_slug=subsector_slug
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
    jsonl_path.write_text("\n".join(out_lines) + ("\n" if out_lines else ""), encoding="utf-8")

    logger.info("Validating against JSON schemas...")
    universal_v = validate_schema._validator(universal_schema_path())
    sector_v = validate_schema._validator(sector_schema_path(sector_slug))
    subsector_v = validate_schema._validator(subsector_schema_path(subsector_slug))

    failures = 0
    valid_payloads: List[Dict[str, Any]] = []
    for line_no, line in enumerate(jsonl_path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        record = json.loads(line)
        errors = validate_schema.validate_row(
            record, universal=universal_v, sector=sector_v, subsector=subsector_v
        )
        if errors:
            failures += 1
            name = record.get("universal", {}).get("name", "(unnamed)")
            print(f"line {line_no} [{name}]:", file=sys.stderr)
            for e in errors:
                print(f"  - {e}", file=sys.stderr)
            continue
        valid_payloads.append(upsert_projects.build_payload(record))

    logger.info(
        "Validated %d rows: %d pass, %d fail.",
        len(out_lines),
        len(valid_payloads),
        failures,
    )

    if failures:
        print(
            f"\n{failures} row(s) failed validation. Fix the column map or the schema before "
            "running without --dry-run.",
            file=sys.stderr,
        )

    if not valid_payloads:
        return 1 if failures else 0

    if args.dry_run:
        print(json.dumps(valid_payloads, indent=2, ensure_ascii=False))
        print(
            f"\n(dry-run) Would upsert {len(valid_payloads)} rows for subsector={subsector_slug}.",
            file=sys.stderr,
        )
        return 1 if failures else 0

    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    written = upsert_projects.upsert(
        env["SUPABASE_URL"],
        env["SUPABASE_SERVICE_ROLE_KEY"],
        valid_payloads,
    )
    print(f"Upserted {written} rows into projects (subsector={subsector_slug}).", file=sys.stderr)

    if not args.keep_tmp:
        try:
            csv_path.unlink(missing_ok=True)
            jsonl_path.unlink(missing_ok=True)
            work_dir.rmdir()
        except OSError:
            pass

    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
