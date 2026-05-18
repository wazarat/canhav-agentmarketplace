#!/usr/bin/env python3
"""Validate a normalized project JSON Lines file against the universal + sector + subsector JSON Schemas.

Each line must look like:
  {"universal": {...}, "sector_attributes": {...}, "subsector_attributes": {...}, "source_row_hash": "..."}

Exits 0 on success, 1 if any row fails validation. Prints one error per failing row.

Deterministic: same input + same schemas -> same output.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict

try:
    from jsonschema import Draft202012Validator
except ImportError:
    sys.stderr.write(
        "jsonschema is required. Install with: pip install jsonschema\n"
    )
    sys.exit(2)

from _common import (
    sector_schema_path,
    subsector_schema_path,
    universal_schema_path,
    load_json,
)


def _validator(path: Path) -> Draft202012Validator:
    if not path.exists():
        return Draft202012Validator({"type": "object"})
    return Draft202012Validator(load_json(path))


def validate_row(
    row: Dict[str, Any],
    *,
    universal: Draft202012Validator,
    sector: Draft202012Validator,
    subsector: Draft202012Validator,
) -> list[str]:
    errors: list[str] = []
    for label, validator, payload in (
        ("universal", universal, row.get("universal", {})),
        ("sector_attributes", sector, row.get("sector_attributes", {})),
        ("subsector_attributes", subsector, row.get("subsector_attributes", {})),
    ):
        for err in validator.iter_errors(payload):
            path = ".".join(str(p) for p in err.absolute_path) or "(root)"
            errors.append(f"{label}.{path}: {err.message}")
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="JSON Lines file from normalize_row.py")
    parser.add_argument("--sector", required=True)
    parser.add_argument("--subsector", required=True)
    args = parser.parse_args(argv)

    universal = _validator(universal_schema_path())
    sector = _validator(sector_schema_path(args.sector))
    subsector = _validator(subsector_schema_path(args.subsector))

    failures = 0
    total = 0
    with args.input.open("r", encoding="utf-8") as fh:
        for line_no, line in enumerate(fh, 1):
            line = line.strip()
            if not line:
                continue
            total += 1
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                print(f"line {line_no}: invalid JSON: {exc}", file=sys.stderr)
                failures += 1
                continue
            errors = validate_row(row, universal=universal, sector=sector, subsector=subsector)
            if errors:
                failures += 1
                name = row.get("universal", {}).get("name", "(unnamed)")
                print(f"line {line_no} [{name}]:", file=sys.stderr)
                for e in errors:
                    print(f"  - {e}", file=sys.stderr)

    print(f"Validated {total} rows. {failures} failed.", file=sys.stderr)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
