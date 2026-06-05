-- Market Map — Sector 7 (Governance & Enterprise Framework) sector-wide schema.
--
-- WHAT THIS LANDS.
--   1. Rewrites 3 of the 5 Sector 7 subsector rows so their slugs match the v13
--      canonical spelling (the seed used short forms that don't match the
--      field-spec docs the next agent reads). No projects depend on these
--      slugs yet, so a DELETE+INSERT is safe.
--   2. Adds two new sector-wide columns to public.projects:
--        - subsector_scope_of uuid FK → projects(id)
--        - deprecation_note text
--      Used for the 42+ scoped-entity rows (ISS-S7-006) and the Governor Alpha
--      deprecation (ISS-S7-005) respectively.
--   3. Updates sectors.common_field_schema for governance-enterprise-framework
--      so the project page renders humanLabel titles for both the inherited
--      Sector-6 promotions and the two new columns.
--
-- READ-PATH PAIRING REQUIREMENT.
--   This sector ships 5 sidecar tables (one per subsector, in the sibling
--   0002-0006 migrations). Each sidecar landing must be paired with a
--   SUBSECTOR_VIEW_REGISTRY entry in backend/app/routes/market_map.py — without
--   that pairing the project page only shows universal columns. This is the
--   Sector 2 (Rollup & Scaling Frameworks) regression class documented in the
--   data_gaps post-mortem; M8.16 generalized the registry so the fix is now a
--   single entry per subsector instead of a per-sector branch.

-- ---------------------------------------------------------------------------
-- 1. Canonical subsector slugs. The seed used:
--      cbdcs-public-sector-pilots          → cbdcs-and-public-sector-pilots
--      compliance-regulatory-intel         → compliance-and-regulatory-intelligence
--      institutional-custody-security      → institutional-custody-and-security
--    The other two slugs (dao-governance-systems, enterprise-blockchain-adoption)
--    already match canonical. No projects yet, so DELETE+INSERT is safe.
-- ---------------------------------------------------------------------------

delete from public.subsectors
 where sector_slug = 'governance-enterprise-framework'
   and slug in (
     'cbdcs-public-sector-pilots',
     'compliance-regulatory-intel',
     'institutional-custody-security'
   );

insert into public.subsectors
  (slug, sector_slug, name, description, display_order, source_sheet_id, source_sheet_gid)
values
  ('cbdcs-and-public-sector-pilots', 'governance-enterprise-framework',
   'CBDCs & Public Sector Pilots',
   'Central bank digital currencies, sovereign-issuer programs, and public-sector blockchain pilots with Ethereum anchoring. No Year Launched / Mainnet Status columns; uses Pilot vs Production + Jurisdiction/Authority instead.',
   3, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', null),
  ('compliance-and-regulatory-intelligence', 'governance-enterprise-framework',
   'Compliance & Regulatory Intelligence',
   'Blockchain analytics, transaction monitoring, sanctions screening, travel-rule, and regulator-facing intelligence platforms covering Ethereum L1 + L2s.',
   4, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', null),
  ('institutional-custody-and-security', 'governance-enterprise-framework',
   'Institutional Custody & Security',
   'Regulated custodians, MPC platforms, HSM-backed signing, policy engines, and wallet infrastructure for institutional Ethereum activity. Tab uses Primary Archetype (not Entity Archetype); no Year Launched / One-Line Description columns.',
   5, '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec', null)
on conflict (slug) do update
  set sector_slug      = excluded.sector_slug,
      name             = excluded.name,
      description      = excluded.description,
      display_order    = excluded.display_order,
      source_sheet_id  = excluded.source_sheet_id,
      source_sheet_gid = excluded.source_sheet_gid,
      updated_at       = now();

-- DAO Gov + Enterprise rows already exist on canonical slugs; refresh metadata
-- so display order and descriptions stay aligned with the v13 cleaned workbook.
update public.subsectors
   set description   = 'Onchain governance frameworks, voting platforms, council/role primitives, treasury control, and execution engines used by Ethereum-anchored DAOs.',
       source_sheet_id = '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec',
       updated_at    = now()
 where slug = 'dao-governance-systems';

update public.subsectors
   set description   = 'Enterprise-grade Ethereum platforms, middleware, infrastructure-as-a-service, permissioning, and integration suites targeting banks, governments, and Fortune 1000 customers.',
       source_sheet_id = '1dQr7W47rQ1L83lTIuNrTl324hH6fDB1Lek7kSqgxZec',
       updated_at    = now()
 where slug = 'enterprise-blockchain-adoption';

-- ---------------------------------------------------------------------------
-- 2. Sector-7 promotions onto public.projects.
--    Most of what Sector 7 needs is already on projects from Sector 6
--    (entity_type, entity_archetype, mainnet_status, etc.). The two genuinely
--    new columns are subsector_scope_of (for the 42 scoped-entity rows) and
--    deprecation_note (for Governor Alpha and any future deprecations).
-- ---------------------------------------------------------------------------

alter table public.projects
  add column if not exists subsector_scope_of uuid
    references public.projects(id) on delete set null,
  add column if not exists deprecation_note text;

create index if not exists idx_projects_subsector_scope_of
  on public.projects (subsector_scope_of)
  where subsector_scope_of is not null;

-- ---------------------------------------------------------------------------
-- 3. Sector-common JSON Schema. Documents the inherited Sector-6 promotions
--    plus the two new Sector-7 columns; renders humanLabel titles on the
--    project page without a frontend change.
-- ---------------------------------------------------------------------------

update public.sectors
   set common_field_schema = $json$
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://canhav.com/schemas/market-map/sectors/governance-enterprise-framework.json",
  "title": "Governance & Enterprise Framework — sector_attributes",
  "description": "Fields shared by every subsector in Sector 7. Sidecar tables (0002-0006 migrations) carry the per-subsector typed columns; this schema documents the columns that live on public.projects itself and are surfaced via the universal-column read path + SUBSECTOR_VIEW_REGISTRY merge.",
  "type": "object",
  "additionalProperties": true,
  "properties": {
    "entity_type":                  { "title": "Entity type", "type": "string", "description": "Normalized kebab-case enum (see per-subsector fields-to-add.md §E for the cheat sheet)." },
    "entity_archetype":             { "title": "Entity archetype", "type": "string", "description": "Fine-grained classification used as a UI facet. For the Custody subsector, sourced from the sheet column 'Primary Archetype'." },
    "maintaining_organization":     { "title": "Maintaining organization", "type": "string" },
    "maintaining_organization_raw": { "title": "Maintaining organization (raw)", "type": "string" },
    "year_launched_int":            { "title": "Year launched", "type": ["integer", "null"], "minimum": 1990, "maximum": 2100, "description": "NULL for every CBDC and Custody row (no Year Launched column in those tabs)." },
    "year_launched_text":           { "title": "Year launched (source text)", "type": "string" },
    "mainnet_status":               { "title": "Mainnet status", "type": "string", "description": "Snapshot value; companion mainnet_status_as_of_date is required when set. CBDC rows map 'Pilot vs Production' → mainnet_status." },
    "mainnet_status_as_of_date":    { "title": "Mainnet status as-of date", "type": "string", "format": "date" },
    "deprecation_note":             { "title": "Deprecation note", "type": "string", "description": "Free-form context paired with mainnet_status='deprecated'. Example: 'superseded by Governor Bravo'." },
    "one_line_description":         { "title": "One-line description", "type": "string", "description": "Custody rows have no source column for this; populated from Reason for Inclusion as fallback." },
    "practitioner_note":            { "title": "Practitioner note", "type": "string", "description": "Source header has U+2019 smart apostrophe; normalized to ASCII at ingest." },
    "practitioner_validation_check":{ "title": "Practitioner validation check", "type": "string" },
    "subsector_scope_of":           { "title": "Scope of parent project", "type": "string", "description": "UUID of the canonical primary entity when this row is a parenthetical-scoped variant (e.g. 'Fireblocks (enterprise deployment & ops)' → fireblocks). See ISS-S7-006." },
    "scope_annotation":             { "title": "Scope annotation", "type": "string", "description": "The verbatim parenthetical scope hint from the sheet (e.g. 'enterprise deployment & ops', 'Ethereum-anchored only')." },
    "parent_project_slug":          { "title": "Parent project slug", "type": "string", "description": "Self-FK by slug (alternative to subsector_scope_of when the parent uses an explicit hierarchy rather than scope disambiguation)." },
    "reason_for_inclusion":         { "title": "Reason for inclusion", "type": "string" },
    "description_long":             { "title": "Long-form description", "type": "string" },
    "value_source_attribution":     { "title": "Value source attribution", "type": "string", "description": "Trailing '(<vendor>)' tokens stripped from Compliance subsector free-text fields per ISS-S7-014, preserved here for traceability." }
  }
}
$json$::jsonb,
       updated_at = now()
 where slug = 'governance-enterprise-framework';
