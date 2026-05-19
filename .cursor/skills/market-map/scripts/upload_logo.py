#!/usr/bin/env python3
"""Upload a single project logo: optimize -> Supabase Storage -> update projects.logo_url.

Usage:
  upload_logo.py --project lighthouse --file ~/logos/Sigma\\ Prime.jpg
  upload_logo.py --project lighthouse --file ./sigma-prime.png --dry-run

How it works:
  1. Looks up the project in Supabase and reads `sector_attributes.maintaining_organization`.
  2. Slugifies that org name (e.g. "Sigma Prime" -> "sigma-prime"). That becomes the
     storage object key: <org-slug>.webp.
  3. Opens the input file with Pillow, fits it into a 256x256 canvas (preserving aspect
     ratio, transparent padding), and re-encodes as WebP quality=85.
  4. Uploads to bucket `project-logos` (created in migration 20260519_0002).
  5. Updates `projects.logo_url` to the public URL.

If multiple projects share the same maintaining_organization (e.g. several Consensys-
maintained tools), they end up pointing at the same single file — uploads after the
first are basically free.

Requires: Pillow, httpx. Env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
"""
from __future__ import annotations

import argparse
import io
import logging
import sys
from pathlib import Path
from typing import Optional, Tuple

import httpx

try:
    from PIL import Image
except ImportError:
    sys.stderr.write("Pillow is required. Install with: pip install Pillow\n")
    sys.exit(2)

from _common import require_env, slugify, supabase_headers

logger = logging.getLogger("upload_logo")

BUCKET = "project-logos"
TARGET_SIZE = 256
WEBP_QUALITY = 85


def _fetch_project(supabase_url: str, key: str, slug: str) -> dict:
    url = (
        f"{supabase_url}/rest/v1/projects"
        f"?slug=eq.{slug}&select=slug,name,sector_attributes,logo_url"
    )
    with httpx.Client(timeout=15.0) as client:
        response = client.get(url, headers=supabase_headers(key))
    if response.status_code != 200:
        raise SystemExit(f"Supabase project lookup failed: {response.status_code} {response.text}")
    rows = response.json()
    if not rows:
        raise SystemExit(f"No project with slug={slug!r} in Supabase.")
    return rows[0]


def _derive_org_slug(project: dict, override: Optional[str]) -> Tuple[str, str]:
    """Returns (org_display_name, org_slug). Override takes precedence."""
    if override:
        return override, slugify(override)
    attrs = project.get("sector_attributes") or {}
    org = (attrs.get("maintaining_organization") or "").strip()
    if not org:
        raise SystemExit(
            f"Project {project['slug']!r} has no sector_attributes.maintaining_organization. "
            "Pass --org-name to override."
        )
    return org, slugify(org)


def optimize_logo(input_path: Path, target_size: int = TARGET_SIZE) -> bytes:
    """Open, resize-to-fit, and re-encode as WebP. Returns the bytes."""
    with Image.open(input_path) as img:
        img.load()
        # Convert anything to RGBA so transparency survives; we'll flatten to white if
        # the source has no alpha channel.
        if img.mode in ("P", "L"):
            img = img.convert("RGBA")
        if img.mode == "RGB":
            img = img.convert("RGBA")
        # Resize preserving aspect ratio
        img.thumbnail((target_size, target_size), Image.LANCZOS)
        # Center on a square transparent canvas so all logos have the same footprint
        canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
        offset = (
            (target_size - img.width) // 2,
            (target_size - img.height) // 2,
        )
        canvas.paste(img, offset, img if img.mode == "RGBA" else None)
        buf = io.BytesIO()
        canvas.save(buf, format="WEBP", quality=WEBP_QUALITY, method=6)
        return buf.getvalue()


def upload_to_storage(
    supabase_url: str,
    service_role_key: str,
    object_key: str,
    payload: bytes,
    *,
    upsert: bool = True,
) -> str:
    """Upload bytes to the project-logos bucket. Returns the public URL."""
    url = f"{supabase_url}/storage/v1/object/{BUCKET}/{object_key}"
    headers = {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "image/webp",
        "Cache-Control": "public, max-age=31536000, immutable",
    }
    if upsert:
        headers["x-upsert"] = "true"
    with httpx.Client(timeout=30.0) as client:
        response = client.post(url, headers=headers, content=payload)
    if response.status_code not in (200, 201):
        raise SystemExit(
            f"Supabase Storage upload failed: {response.status_code}\n{response.text[:500]}"
        )
    return f"{supabase_url}/storage/v1/object/public/{BUCKET}/{object_key}"


def patch_project_logo_url(
    supabase_url: str,
    service_role_key: str,
    project_slug: str,
    logo_url: str,
) -> None:
    url = f"{supabase_url}/rest/v1/projects?slug=eq.{project_slug}"
    headers = supabase_headers(service_role_key)
    with httpx.Client(timeout=15.0) as client:
        response = client.patch(url, headers=headers, json={"logo_url": logo_url})
    if response.status_code not in (200, 204):
        raise SystemExit(
            f"Supabase project patch failed: {response.status_code} {response.text[:500]}"
        )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True, help="Project slug (e.g. lighthouse)")
    parser.add_argument("--file", type=Path, required=True, help="Path to the source logo file")
    parser.add_argument(
        "--org-name",
        help="Override the maintaining organization name (skips the DB lookup for the slug derivation).",
    )
    parser.add_argument("--dry-run", action="store_true", help="Optimize + log, don't upload or patch")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)

    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )

    if not args.file.exists():
        raise SystemExit(f"Logo file not found: {args.file}")

    env = require_env("SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY")
    supabase_url = env["SUPABASE_URL"]
    key = env["SUPABASE_SERVICE_ROLE_KEY"]

    project = _fetch_project(supabase_url, key, args.project)
    org_name, org_slug = _derive_org_slug(project, args.org_name)
    object_key = f"{org_slug}.webp"

    logger.info("Project:   %s (%s)", project["slug"], project.get("name"))
    logger.info("Org:       %s -> %s", org_name, org_slug)
    logger.info("Source:    %s (%d bytes)", args.file, args.file.stat().st_size)

    payload = optimize_logo(args.file)
    logger.info("Optimized: %d bytes WebP @ %dx%d q=%d", len(payload), TARGET_SIZE, TARGET_SIZE, WEBP_QUALITY)

    public_url = f"{supabase_url}/storage/v1/object/public/{BUCKET}/{object_key}"
    logger.info("Target:    %s", public_url)

    if args.dry_run:
        logger.info("(dry-run) skipping upload + DB patch")
        return 0

    upload_to_storage(supabase_url, key, object_key, payload)
    logger.info("Uploaded to %s", object_key)

    patch_project_logo_url(supabase_url, key, args.project, public_url)
    logger.info("Patched projects.%s.logo_url", args.project)

    print(public_url)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
