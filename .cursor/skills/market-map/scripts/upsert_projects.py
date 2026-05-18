#!/usr/bin/env python3
"""Upsert validated project rows into Supabase via the PostgREST endpoint.

Reads JSON Lines (one record per line) from --input. Each record must contain:
  { "universal": {...}, "sector_attributes": {...}, "subsector_attributes": {...}, "source_row_hash": "..." }

Side effects: writes to Supabase using the service_role key. NEVER auto-fire.

Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment.

Use --dry-run to print the payload without sending it.
"""
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List

import httpx

from _common import chunked, require_env, supabase_headers


def build_payload(row: Dict[str, Any]) -> Dict[str, Any]:
    universal = dict(row.get("universal") or {})
    payload: Dict[str, Any] = {
        **universal,
        "sector_attributes": row.get("sector_attributes") or {},
        "subsector_attributes": row.get("subsector_attributes") or {},
        "source_row_hash": row.get("source_row_hash"),
        "source_last_synced_at": datetime.now(timezone.utc).isoformat(),
    }
    # Drop unknown universal keys -> we want PostgREST to reject if we typo a column.
    return payload


def upsert(
    supabase_url: str,
    service_role_key: str,
    rows: List[Dict[str, Any]],
    *,
    chunk_size: int = 100,
    timeout: float = 30.0,
) -> int:
    url = f"{supabase_url}/rest/v1/projects?on_conflict=slug"
    headers = supabase_headers(service_role_key)
    written = 0
    with httpx.Client(timeout=timeout) as client:
        for batch in chunked(rows, chunk_size):
            response = client.post(url, headers=headers, content=json.dumps(batch))
            if response.status_code not in (200, 201):
                raise SystemExit(
                    f"Supabase upsert failed: {response.status_code}\n"
                    f"Body: {response.text[:1000]}"
                )
            written += len(batch)
    return written


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="JSON Lines file (post-validation)")
    parser.add_argument("--dry-run", action="store_true", help="Print the payload, don't write")
    parser.add_argument("--chunk-size", type=int, default=100)
    args = parser.parse_args(argv)

    payloads: List[Dict[str, Any]] = []
    with args.input.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"line {line_no}: invalid JSON: {exc}")
            payloads.append(build_payload(row))

    if not payloads:
        print("No rows to upsert.", file=sys.stderr)
        return 0

    if args.dry_run:
        print(json.dumps(payloads, indent=2, ensure_ascii=False))
        print(f"\n(dry-run) Would upsert {len(payloads)} rows.", file=sys.stderr)
        return 0

    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    written = upsert(
        env["SUPABASE_URL"],
        env["SUPABASE_SERVICE_ROLE_KEY"],
        payloads,
        chunk_size=args.chunk_size,
    )
    print(f"Upserted {written} rows into projects.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
