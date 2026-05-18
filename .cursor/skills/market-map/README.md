# `.cursor/skills/market-map/`

Repo-local Claude Skill for the CanHav Market Map (M8). See [`SKILL.md`](./SKILL.md) for the user-facing guide.

## Layout

```
.cursor/skills/market-map/
├── SKILL.md                              # entry skill, audited for visibility/determinism/composability
├── README.md                             # (this file)
├── scripts/                              # deterministic CLIs, no token cost
│   ├── fetch_sheet.py
│   ├── normalize_row.py
│   ├── validate_schema.py
│   ├── upsert_projects.py
│   ├── ingest_subsector.py
│   ├── add_subsector.py
│   └── add_sector.py
├── schemas/                              # JSON Schemas (drive the validator + the API field labels)
│   ├── universal.json
│   ├── sectors/<sector-slug>.json
│   └── subsectors/<subsector-slug>.json
└── sectors/
    └── <sector-slug>/
        ├── SKILL.md                      # sector-common conventions, user-invocable: false
        └── subsectors/
            └── <subsector-slug>.md       # subsector-specific field doc, user-invocable: false
```

## Running scripts

```bash
# from repo root, with backend venv active
export SUPABASE_URL=https://<ref>.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=eyJ...

python .cursor/skills/market-map/scripts/fetch_sheet.py \
  --sheet-id 1eSqVRbzdd53dbVNJEM5-uH1NKBB8Cmyh4TWrXPCMEBU \
  --gid 0 \
  --output /tmp/consensus-layer.csv

python .cursor/skills/market-map/scripts/ingest_subsector.py \
  --slug consensus-layer --dry-run
```

All scripts have `--help` and exit non-zero on error. Errors are user-fixable — they don't require AI to interpret.
