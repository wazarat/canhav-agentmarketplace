#!/usr/bin/env python3
"""Scaffold a new sector locally: sector SKILL.md, sector JSON schema, plus N subsector stubs.

This does NOT touch Supabase. Add the rows to supabase/migrations/ separately.

Usage:
  add_sector.py --slug new-sector --name "New Sector"
  add_sector.py --slug new-sector --name "New Sector" --subsector "consensus-layer:Consensus Layer"
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import add_subsector
from _common import (
    SCHEMAS_ROOT,
    SECTORS_ROOT,
    dump_json,
    sector_schema_path,
    slugify,
)

SECTOR_SKILL_TEMPLATE = """---
name: market-map/{sector_slug}
description: Background reference for the {name} sector. Auto-loads when the agent is working under .cursor/skills/market-map/sectors/{sector_slug}/. Not surfaced in /menu.
user-invocable: false
---

# {name} — Sector reference

## Sector-common fields (apply to every subsector)

Document each field that belongs in `sector_attributes` for projects in this sector. Things
that vary per subsector belong in the per-subsector reference doc.

| Field key | Type | Required | Description |
|-----------|------|----------|-------------|
| _example_field_ | string | no | _description_ |

Canonical JSON Schema: `schemas/sectors/{sector_slug}.json`.

## Subsectors in this sector

See `subsectors/` for the per-subsector field docs.

## Notes for ingest

- Sector-specific quirks, sheet-quality flags, anything that helps the next ingest run.
"""


def write_sector_files(sector_slug: str, name: str) -> list[Path]:
    written: list[Path] = []
    sector_dir = SECTORS_ROOT / sector_slug
    sector_dir.mkdir(parents=True, exist_ok=True)
    (sector_dir / "subsectors").mkdir(exist_ok=True)

    skill_path = sector_dir / "SKILL.md"
    if not skill_path.exists():
        skill_path.write_text(
            SECTOR_SKILL_TEMPLATE.format(sector_slug=sector_slug, name=name),
            encoding="utf-8",
        )
        written.append(skill_path)

    schema_path = sector_schema_path(sector_slug)
    if not schema_path.exists():
        dump_json(
            schema_path,
            {
                "$schema": "https://json-schema.org/draft/2020-12/schema",
                "$id": f"https://canhav.com/schemas/market-map/sectors/{sector_slug}.json",
                "title": f"{name} — sector_attributes",
                "type": "object",
                "additionalProperties": True,
                "properties": {},
            },
        )
        written.append(schema_path)

    column_map_path = SCHEMAS_ROOT / "sectors" / f"{sector_slug}.column_map.json"
    if not column_map_path.exists():
        dump_json(
            column_map_path,
            {
                "_comment_": "Sector-wide column-map overrides. Subsector-specific column maps win.",
            },
        )
        written.append(column_map_path)

    return written


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slug", required=True)
    parser.add_argument("--name", required=True)
    parser.add_argument(
        "--subsector",
        action="append",
        default=[],
        help="Repeatable. Format: subsector-slug:Display Name[:sheet_id:gid]",
    )
    args = parser.parse_args(argv)

    sector_slug = slugify(args.slug)
    written = write_sector_files(sector_slug, args.name)

    for sub in args.subsector:
        parts = sub.split(":", 3)
        sub_slug = slugify(parts[0])
        sub_name = parts[1] if len(parts) > 1 else sub_slug
        sheet_id = parts[2] if len(parts) > 2 else ""
        gid = parts[3] if len(parts) > 3 else ""
        written += add_subsector.write_files(
            sector_slug=sector_slug,
            subsector_slug=sub_slug,
            name=sub_name,
            sheet_id=sheet_id,
            gid=gid,
        )

    for path in written:
        print(f"created {path.relative_to(Path.cwd()) if path.is_absolute() else path}")
    if not written:
        print("All files already exist. No changes made.", file=sys.stderr)
        return 0

    print(
        "\nNext: add this sector + its subsectors to a new supabase/migrations/*.sql file.",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
