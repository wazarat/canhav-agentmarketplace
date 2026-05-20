# Future plans

Polish, follow-ups, and out-of-milestone work. Items here are **not milestones** — they get picked up opportunistically or after all milestones (M0–M11) are done. Append newest on top. If an item graduates into milestone scope, move it into the README milestone table or a `.cursor/plans/*.plan.md`.

Each entry should answer:
- **Status** — deferred / on hold / waiting on _x_.
- **What is parked** — the rails (DB columns, scripts, docs, storage objects) we already shipped and want to preserve.
- **To re-enable** — a concrete recipe so future-you doesn't have to re-derive it.

---

## Project logos in the Market Map UI

**Status.** Deferred. Pipeline shipped 2026-05-19 (commit `95a18c5`). UI display reverted 2026-05-20 (the commit that introduced this doc).

**Why deferred.** Visible logos were drawing attention before the Market Map data is broad enough to earn it. We want the canvas clean until more sectors are populated, then re-introduce logos as a single polish pass.

**What is parked (do NOT remove without re-reading this entry).**
- Supabase Storage bucket `project-logos` (`supabase/migrations/20260519_0002_project_logos_storage_bucket.sql`) — public read, service-role write, RLS in place.
- 6 Consensus Layer logos already uploaded to that bucket and patched onto `projects.logo_url`: `ethereum-foundation.webp`, `prysmatic-labs.webp`, `sigma-prime.webp`, `consensys.webp`, `status.webp`, `chainsafe.webp`.
- `projects.logo_url` column on the schema (`supabase/migrations/20260518_0001_market_map_schema.sql`) — predates the logo work, lives in the universal-fields tier.
- `.cursor/skills/market-map/scripts/upload_logo.py` (single-project pipeline).
- `.cursor/skills/market-map/scripts/bulk_upload_logos.py` (folder-scan + match by maintaining-org slug).
- `.cursor/skills/market-map/LOGOS.md` (full convention: source formats, file naming, optimizer behavior, UI rules).
- `.cursor/skills/market-map/SKILL.md` cross-reference rows pointing at the two scripts and LOGOS.md.
- `backend/requirements.txt` → `Pillow==11.3.0` (dormant unless a script is invoked).
- `frontend/next.config.mjs` → `images.remotePatterns` allow-list for `*.supabase.co/storage/v1/object/public/**` (retained on purpose; marker comment in the file points back here).
- The universal JSON schema slot for `logo_url` and the Consensus Layer column-map entry mapping the sheet's `logo_url` column to the universal field.

**To re-enable later** (UI-only change, ~5 minutes once we're ready):
1. Restore `frontend/components/market-map/ProjectLogo.tsx` from commit `95a18c5`.
2. Re-add the three call sites in:
   - `frontend/components/market-map/ProjectTable.tsx` — small (28px) tile leading each row, inside the `Link`.
   - `frontend/components/market-map/CanonicalSpecCard.tsx` — medium (48px) tile next to the gradient title.
   - `frontend/app/market-map/project/[slug]/page.tsx` — large (80px) tile to the left of the H1 (the "Maintained by …" line under the title was kept in place when the logo was reverted).
3. Nothing else is needed: schema, RLS, bucket, scripts, Pillow, `remotePatterns`, and the 6 already-uploaded files are all still live.
4. For brand-new sectors, drop logos in `~/logos` and run `python .cursor/skills/market-map/scripts/bulk_upload_logos.py --dir ~/logos --subsector <slug>`.
