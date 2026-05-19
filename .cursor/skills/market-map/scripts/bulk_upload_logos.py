#!/usr/bin/env python3
"""Bulk-upload logos from a folder of `<Org Name>.{png,jpg,jpeg,webp}` files.

Workflow:
  1. Scan --dir for image files; each file's stem is treated as an organization name.
  2. Query Supabase for every project whose sector_attributes.maintaining_organization
     slug matches the file's slug.
  3. For each match, run the same optimize -> upload -> patch pipeline as upload_logo.py.

Idempotent: existing logos in storage are overwritten (x-upsert: true). If a file's
slug matches no projects, it's logged and skipped.

Usage:
  bulk_upload_logos.py --dir ~/logos
  bulk_upload_logos.py --dir ~/logos --dry-run
  bulk_upload_logos.py --dir ~/logos --subsector consensus-layer   # constrain to one subsector
"""
from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path
from typing import Dict, List, Optional

import httpx

from _common import require_env, slugify, supabase_headers
from upload_logo import (
    BUCKET,
    optimize_logo,
    patch_project_logo_url,
    upload_to_storage,
)

logger = logging.getLogger("bulk_upload_logos")

SUPPORTED_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif"}


def _fetch_projects(
    supabase_url: str,
    key: str,
    *,
    subsector: Optional[str] = None,
) -> List[Dict]:
    url = (
        f"{supabase_url}/rest/v1/projects"
        f"?select=slug,name,subsector_slug,sector_attributes,logo_url"
    )
    if subsector:
        url += f"&subsector_slug=eq.{subsector}"
    with httpx.Client(timeout=30.0) as client:
        response = client.get(url, headers=supabase_headers(key))
    if response.status_code != 200:
        raise SystemExit(f"Supabase project list failed: {response.status_code} {response.text}")
    return response.json()


def _index_by_org_slug(projects: List[Dict]) -> Dict[str, List[Dict]]:
    out: Dict[str, List[Dict]] = {}
    for p in projects:
        attrs = p.get("sector_attributes") or {}
        org = (attrs.get("maintaining_organization") or "").strip()
        if not org:
            continue
        out.setdefault(slugify(org), []).append(p)
    return out


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dir", type=Path, required=True, help="Folder containing logo files")
    parser.add_argument("--subsector", help="Limit to projects in this subsector slug")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )

    if not args.dir.exists() or not args.dir.is_dir():
        raise SystemExit(f"Not a directory: {args.dir}")

    files = sorted(
        p for p in args.dir.iterdir()
        if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS and not p.name.startswith(".")
    )
    if not files:
        raise SystemExit(f"No supported logo files in {args.dir}")

    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    supabase_url = env["SUPABASE_URL"]
    key = env["SUPABASE_SERVICE_ROLE_KEY"]

    projects = _fetch_projects(supabase_url, key, subsector=args.subsector)
    by_org = _index_by_org_slug(projects)
    logger.info("Found %d files, %d projects with maintaining_organization set.",
                len(files), sum(len(v) for v in by_org.values()))

    uploaded = 0
    patched = 0
    skipped: List[str] = []

    for file_path in files:
        org_slug = slugify(file_path.stem)
        matches = by_org.get(org_slug, [])
        if not matches:
            skipped.append(f"{file_path.name}  (slug={org_slug!r}, no matching projects)")
            continue

        logger.info("\n=== %s  (org-slug=%s) ===", file_path.name, org_slug)
        for p in matches:
            logger.info("  -> %s (%s)", p["slug"], p.get("name"))

        payload = optimize_logo(file_path)
        object_key = f"{org_slug}.webp"
        public_url = f"{supabase_url}/storage/v1/object/public/{BUCKET}/{object_key}"
        logger.info("  optimized: %d bytes -> %s", len(payload), object_key)

        if args.dry_run:
            continue

        upload_to_storage(supabase_url, key, object_key, payload)
        uploaded += 1

        for p in matches:
            patch_project_logo_url(supabase_url, key, p["slug"], public_url)
            patched += 1

    logger.info("")
    logger.info("Summary: %d file(s) %s, %d project row(s) patched.",
                uploaded, "would be uploaded" if args.dry_run else "uploaded",
                0 if args.dry_run else patched)
    if skipped:
        logger.info("Skipped (%d):", len(skipped))
        for s in skipped:
            logger.info("  - %s", s)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
