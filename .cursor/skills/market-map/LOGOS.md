# Market Map — logo best practices

How we handle organization / project logos for the Market Map. **Read this before uploading any new logo** so they all stay visually consistent.

---

## TL;DR

```bash
# Single project
python upload_logo.py --project lighthouse --file ~/Downloads/sigma-prime.svg

# Whole folder, one shot — file names must be the maintaining-org name
python bulk_upload_logos.py --dir ~/logos                          # everything
python bulk_upload_logos.py --dir ~/logos --subsector consensus-layer   # one subsector only
```

The script optimizes the image to **256×256 WebP @ q=85**, uploads to the Supabase Storage bucket `project-logos`, then patches `projects.logo_url` for every matching project.

---

## What gets stored

- **Bucket:** `project-logos` (public read, service-role write — see `supabase/migrations/20260519_0002_project_logos_storage_bucket.sql`).
- **Object key:** `<maintaining-org-slug>.webp`. Examples: `sigma-prime.webp`, `consensys.webp`, `ethereum-foundation.webp`.
- **One file per maintaining organization** — not one per project. If `Consensys` maintains both Teku and (later) MetaMask SDK, both projects' `logo_url` point at the same `consensys.webp`. This is by design.
- **DB column:** `projects.logo_url` (already on the table; nothing to migrate).

The public URL pattern is:
```
https://<project-ref>.supabase.co/storage/v1/object/public/project-logos/<org-slug>.webp
```

---

## File naming convention for sources

The bulk uploader matches `~/logos/<File Name>.{png,jpg,jpeg,webp,gif}` to projects by slugifying the **file stem** and comparing to the slug of every project's `sector_attributes.maintaining_organization`.

✅ `Sigma Prime.jpg` → `sigma-prime` → matches Lighthouse (maintaining_organization = "Sigma Prime").
✅ `ChainSafe.jpeg`  → `chainsafe`   → matches Lodestar.
✅ `Ethereum Foundation.png` → `ethereum-foundation` → matches Ethereum Consensus Specifications.

❌ `lighthouse-logo.png` → `lighthouse-logo` → matches nothing (project's org is "Sigma Prime", not "Lighthouse").

If the file you have is named by *project* instead of by *org*, just rename it before running the bulk uploader, or use the single-shot `upload_logo.py --org-name "Sigma Prime"` to override.

---

## Source file requirements

Aim for, in order of preference:

1. **SVG** — vector, scales perfectly. Strip embedded `<script>` tags before commit. Pillow will rasterize, but if the SVG is clean enough you could also commit it raw and skip the optimizer for that file.
2. **Transparent-background PNG** at ≥256×256. WebP also fine.
3. **JPEG** — acceptable but always has a background fill (white or colored). Fine for marks that are already designed to live on a colored card (most logos in the wild).

Avoid:
- Photographs, headshots, screenshots. We render a flat **mark**, not a banner.
- Logos with text-only treatment when an icon variant exists — use the icon, not the wordmark. The UI provides the name as text already.
- Images larger than ~2 MB. The pipeline handles them, but you're burning local CPU for no reason.

---

## What the optimizer does

`upload_logo.optimize_logo()` runs on every upload (see `scripts/upload_logo.py`):

1. Open with Pillow → convert mode to RGBA.
2. `thumbnail()` to fit inside a 256×256 box, preserving aspect ratio (Lanczos resample).
3. Center on a transparent 256×256 canvas — so portrait, landscape, and square sources all produce the same final footprint.
4. Save as WebP, `quality=85`, `method=6` (slow encode, best compression).
5. Typical output: **1.5–6 KB per logo**.

The cache header on upload is `public, max-age=31536000, immutable` — once a file is up, the CDN caches it for a year. If you replace a logo, **bump the file's mtime in source control** (or use a query string in the UI) so the year-long cache doesn't bite you.

---

## How the UI renders logos

`frontend/components/market-map/ProjectLogo.tsx` — single source of truth. Three sizes:

| Size | Used in | Pixel box | Padding inside tile |
|------|---------|-----------|---------------------|
| `sm` | `ProjectTable` rows | 28 × 28 | ~10 % all sides |
| `md` | `CanonicalSpecCard` header | 48 × 48 | ~10 % all sides |
| `lg` | `/market-map/project/[slug]` header | 80 × 80 | ~10 % all sides |

Treatment rules (do not break these without a design discussion):

- **Always inside a neutral-background tile** (`bg-ink-800/70`, `border-ink-700/60`, `rounded-md|lg|xl`). Light, dark, and colored logos all read the same way against the page.
- **`object-contain`**, never `cover`. We don't crop marks.
- **No drop shadow, no glow, no border-radius on the image itself.** The tile owns the geometry.
- **Fallback:** if `logo_url` is null, render a 2-letter monogram in the same tile. Layout never shifts when logos arrive late for a subsector.
- **No `next/image` optimizer** (`unoptimized` prop). Sources are already 256×256 WebPs; running them through Vercel's optimizer is wasted bandwidth.

---

## When you have a new sector / subsector

1. Drop the org logo files in `~/logos` named after the **maintaining organization**, not the project.
2. Run `python bulk_upload_logos.py --dir ~/logos --subsector <subsector-slug> --dry-run` to see what will get matched. The output lists every (file → project) pair, plus any files with no match.
3. Re-run without `--dry-run` to push.
4. The Market Map pages are `dynamic = "force-dynamic"` during the M8 build phase, so the new logos appear on the next pageview. No deploy needed.

## When the same org maintains a project across two subsectors

Just run the upload again from any one of the projects, or rely on `bulk_upload_logos.py` — both will set `logo_url` on every project whose `maintaining_organization` matches that org slug. The single file in storage is shared, no duplication.

## When you need to delete a logo

Until we hit ~50 logos, easiest path:
```sql
update public.projects set logo_url = null where slug = '<slug>';
```
…and (optional, doesn't affect UI) delete the storage object from the Supabase dashboard under Storage → project-logos.
