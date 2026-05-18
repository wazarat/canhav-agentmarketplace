#!/usr/bin/env python3
"""Scaffold a new subsector locally: skill stub + JSON schema stub + column-map stub.

This does NOT touch Supabase. To register the subsector in the DB, add it to a new SQL
migration in supabase/migrations/ and apply via the supabase CLI or MCP `apply_migration`.

Usage:
  add_subsector.py --sector core-protocol-architecture --slug new-thing --name "New Thing" \
                   --sheet-id <id> --gid <gid>
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from _common import (
    SCHEMAS_ROOT,
    SECTORS_ROOT,
    dump_json,
    slugify,
    subsector_md_path,
    subsector_schema_path,
)

SKILL_TEMPLATE = """---
name: market-map/{sector_slug}/{subsector_slug}
description: Background reference for the {name} subsector. Auto-loads when the agent is working under .cursor/skills/market-map/sectors/{sector_slug}/. Not surfaced in /menu.
user-invocable: false
---

# {name} — Subsector reference

Sheet: `{sheet_id}` tab `{gid}`

## Subsector-specific fields

Document each field that belongs in `subsector_attributes` for this subsector. Fields shared
across multiple subsectors of `{sector_slug}` belong in the sector SKILL.md instead.

| Field key | Type | Required | Description |
|-----------|------|----------|-------------|
| _example_field_ | string | no | _description_ |

The canonical JSON Schema this list maps to lives at `schemas/subsectors/{subsector_slug}.json`.

## Column map

`schemas/subsectors/{subsector_slug}.column_map.json` maps CSV column headers to either a
universal column or a key in `subsector_attributes`. Edit it whenever the source sheet's
columns change.

## Ingest notes

- Source sheet anomalies, columns to skip, manual fixups, etc.
"""

COLUMN_MAP_TEMPLATE = {
    "_comment_": "Map Google Sheets column headers to (bucket, field) pairs. bucket: universal | sector | subsector.",
    "Project": {"bucket": "universal", "field": "name"},
    "Website": {"bucket": "universal", "field": "website_url", "type": "url"},
    "Twitter": {"bucket": "universal", "field": "twitter_handle", "type": "twitter"},
    "Description": {"bucket": "universal", "field": "description"},
}


def write_files(
    *,
    sector_slug: str,
    subsector_slug: str,
    name: str,
    sheet_id: str,
    gid: str,
) -> list[Path]:
    written: list[Path] = []

    md_path = subsector_md_path(sector_slug, subsector_slug)
    md_path.parent.mkdir(parents=True, exist_ok=True)
    if not md_path.exists():
        md_path.write_text(
            SKILL_TEMPLATE.format(
                sector_slug=sector_slug,
                subsector_slug=subsector_slug,
                name=name,
                sheet_id=sheet_id,
                gid=gid,
            ),
            encoding="utf-8",
        )
        written.append(md_path)

    schema_path = subsector_schema_path(subsector_slug)
    if not schema_path.exists():
        dump_json(
            schema_path,
            {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$id": f"https://canhav.com/schemas/market-map/subsectors/{subsector_slug}.json",
                "title": f"{name} — subsector_attributes",
                "type": "object",
                "additionalProperties": True,
                "properties": {},
            },
        )
        written.append(schema_path)

    column_map_path = SCHEMAS_ROOT / "subsectors" / f"{subsector_slug}.column_map.json"
    if not column_map_path.exists():
        dump_json(column_map_path, COLUMN_MAP_TEMPLATE)
        written.append(column_map_path)

    return written


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sector", required=True, help="Existing sector slug")
    parser.add_argument("--slug", required=True, help="New subsector slug (kebab-case)")
    parser.add_argument("--name", required=True, help="Human-readable name")
    parser.add_argument("--sheet-id", default="", help="Google Sheets workbook ID (optional)")
    parser.add_argument("--gid", default="", help="Sheet tab gid (optional)")
    args = parser.parse_args(argv)

    subsector_slug = slugify(args.slug)
    sector_slug = slugify(args.sector)

    sector_dir = SECTORS_ROOT / sector_slug
    if not sector_dir.exists():
        sys.stderr.write(
            f"Sector folder not found: {sector_dir}\n"
            f"Run add_sector.py --slug {sector_slug} first.\n"
        )
        return 2

    written = write_files(
        sector_slug=sector_slug,
        subsector_slug=subsector_slug,
        name=args.name,
        sheet_id=args.sheet_id,
        gid=args.gid,
    )

    for path in written:
        print(f"created {path.relative_to(Path.cwd()) if path.is_absolute() else path}")
    if not written:
        print("All files already exist. No changes made.", file=sys.stderr)
        return 0

    print(
        "\nNext: add this subsector to a new supabase/migrations/*.sql file so the DB row exists.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
