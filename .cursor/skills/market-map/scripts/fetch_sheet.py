#!/usr/bin/env python3
"""Pull a single Google Sheets tab as CSV via the public gviz endpoint.

Usage:
  fetch_sheet.py --sheet-id <id> --gid <gid> [--output path]
  fetch_sheet.py --subsector <subsector-slug> [--output path]

When --subsector is given the script queries Supabase (sectors/subsectors are seeded with
source_sheet_id and source_sheet_gid) to resolve the workbook + tab automatically.

Deterministic: same (sheet_id, gid) always returns the same CSV. No AI in the loop.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import httpx

from _common import gviz_csv_url, require_env, supabase_headers


def fetch(sheet_id: str, gid: str, *, timeout: float = 30.0) -> str:
    url = gviz_csv_url(sheet_id, gid)
    with httpx.Client(timeout=timeout, follow_redirects=True) as client:
        response = client.get(url)
    if response.status_code != 200:
        raise SystemExit(
            f"gviz fetch failed: {response.status_code} for sheet_id={sheet_id} gid={gid}\n"
            f"Body (first 500 chars): {response.text[:500]}"
        )
    return response.text


def resolve_subsector(slug: str) -> tuple[str, str]:
    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    url = (
        f"{env['SUPABASE_URL']}/rest/v1/subsectors"
        f"?slug=eq.{slug}&select=source_sheet_id,source_sheet_gid"
    )
    with httpx.Client(timeout=15.0) as client:
        response = client.get(url, headers=supabase_headers(env["SUPABASE_SERVICE_ROLE_KEY"]))
    if response.status_code != 200:
        raise SystemExit(f"Supabase lookup failed: {response.status_code} {response.text}")
    rows = response.json()
    if not rows:
        raise SystemExit(f"No subsector with slug={slug!r} found in Supabase.")
    row = rows[0]
    if not row.get("source_sheet_id") or not row.get("source_sheet_gid"):
        raise SystemExit(
            f"Subsector {slug!r} has no source_sheet_id/source_sheet_gid. "
            "Set it via add_subsector.py or by editing supabase/migrations/."
        )
    return row["source_sheet_id"], row["source_sheet_gid"]


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--sheet-id", help="Google Sheets workbook ID")
    group.add_argument("--subsector", help="Subsector slug; resolves sheet_id+gid from Supabase")
    parser.add_argument("--gid", help="Sheet tab gid (required with --sheet-id)")
    parser.add_argument("--output", type=Path, help="Write CSV to this path. Default: stdout.")
    args = parser.parse_args(argv)

    if args.sheet_id:
        if not args.gid:
            parser.error("--gid is required when --sheet-id is given")
        sheet_id, gid = args.sheet_id, args.gid
    else:
        sheet_id, gid = resolve_subsector(args.subsector)

    csv_body = fetch(sheet_id, gid)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(csv_body, encoding="utf-8")
        print(f"Wrote {len(csv_body)} bytes to {args.output}", file=sys.stderr)
    else:
        sys.stdout.write(csv_body)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
