# Deployment guide

This is the M5 deployment runbook. Follow it once after the repo lives on GitHub.

## 0. Push to GitHub

```bash
# (one-time) create the empty public repo on github.com:
#   https://github.com/new  → name: canhav-agentmarketplace, no README/.gitignore/license

git remote add origin git@github.com:wazarat/canhav-agentmarketplace.git
git push -u origin main
```

If you'd rather use HTTPS:

```bash
git remote add origin https://github.com/wazarat/canhav-agentmarketplace.git
git push -u origin main
```

## 1. Deploy the backend (Render) — do this first

The backend URL needs to exist before the frontend env var can be set.

1. Go to [render.com](https://render.com) → **New** → **Blueprint**.
2. Connect the GitHub repo `wazarat/canhav-agentmarketplace`.
3. Render auto-detects [`backend/render.yaml`](backend/render.yaml) and proposes a service named `canhav-backend`.
4. Set the secrets in the Render dashboard:
   - `INSTANTLY_API_KEY` — your Instantly.ai API key (see `https://app.instantly.ai/app/settings/integrations`)
   - `INSTANTLY_CAMPAIGN_ID` — the campaign UUID where waitlist leads should land
   - `ALLOWED_ORIGINS` — start with `https://canhav.com,https://www.canhav.com`. After Vercel deploys, also append the preview URL pattern (e.g. `https://canhav-agentmarketplace.vercel.app`).
   - `SUPABASE_URL` — your Supabase project URL (e.g. `https://<ref>.supabase.co`). Required for the Market Map API (M8). Without it, `/api/market-map/*` returns 503.
   - `SUPABASE_ANON_KEY` — the **anon** (publishable) key. Read-only via RLS — safe on the backend, do NOT use the service-role key here.
   - `SUPABASE_SERVICE_ROLE_KEY` — the **service_role** key. Used ONLY by the ingest scripts in `.cursor/skills/market-map/scripts/` to write projects. Required on Render only if you run ingest from the Render shell; otherwise set it locally.
5. Click **Apply**. First deploy takes ~3 minutes.
6. Note the public URL Render gives you (e.g. `https://canhav-backend.onrender.com`). You'll need it for the frontend.
7. Smoke test:
   ```bash
   curl https://canhav-backend.onrender.com/api/health
   # → {"ok":true,"service":"canhav-backend","instantly_configured":true,"supabase_configured":true}
   ```

## 2. Deploy the frontend (Vercel)

1. Go to [vercel.com](https://vercel.com) → **Add New** → **Project** → import `wazarat/canhav-agentmarketplace`.
2. **Root Directory:** `frontend` (very important — Vercel must build only the Next.js app, not the monorepo root).
3. **Framework Preset:** Next.js (auto-detected).
4. Set environment variables (Production + Preview + Development):
   | Key | Value |
   |-----|-------|
   | `NEXT_PUBLIC_API_BASE_URL` | `https://canhav-backend.onrender.com` (your Render URL from step 1) |
   | `NEXT_PUBLIC_POSTHOG_KEY` | PostHog project token (us.posthog.com → Project settings → Project API key, starts with `phc_`) |
   | `NEXT_PUBLIC_POSTHOG_HOST` | `https://us.posthog.com` (or `https://eu.posthog.com` for EU Cloud) |
5. Click **Deploy**. First deploy takes ~2 minutes.

> **Note on PostHog.** The SDK posts events through the Next.js rewrite at `/ingest/*` (see `next.config.mjs`), which forwards to `us.i.posthog.com` / `us-assets.i.posthog.com`. This means ad blockers that block `*.posthog.com` won't drop events from the production site. If `NEXT_PUBLIC_POSTHOG_KEY` is unset, the client-side provider logs a warning and no-ops, so the build still works without analytics configured.
6. Once live, copy the Vercel preview URL (e.g. `https://canhav-agentmarketplace.vercel.app`) and add it to `ALLOWED_ORIGINS` on Render so CORS doesn't reject preview deploys.

## 3. Custom domain

Vercel:

1. Project → **Settings** → **Domains** → add `canhav.com` and `www.canhav.com`.
2. Vercel will give DNS records — point them at Vercel from your DNS provider (Cloudflare/Namecheap/etc.).
3. Wait for DNS propagation (usually <10 min on Cloudflare).

Substack subdomain (already done):

- `research.canhav.com` should already be CNAMEd to Substack. The site links to it.

Optional — backend on a custom subdomain:

- Add `api.canhav.com` as a custom domain in Render → point its CNAME at the Render service URL.
- Update `NEXT_PUBLIC_API_BASE_URL` on Vercel to `https://api.canhav.com`.

## 4. End-to-end smoke test

From production URL:

1. Open `https://canhav.com` → hero loads, animations play.
2. Click **Join the waitlist** → form scrolls into view.
3. Enter a real email + pick a role → submit → success toast.
4. Verify the lead appears in your Instantly campaign with `source=landing` and `role=...` custom variables.
5. Repeat from `/market-map` and `/agents` and confirm those leads land with the right `source` tags.

If the production form errors with **"Could not reach our email provider"**:

- The backend can't reach Instantly. Check Render logs and verify `INSTANTLY_API_KEY` is set correctly.

If you get a CORS error in the browser console:

- The Vercel domain isn't in `ALLOWED_ORIGINS` on Render. Add it (comma-separated) and redeploy the backend.

## 5. Market Map (M8) — Supabase

For the M8 Market Map data store:

1. Create a Supabase project (free tier, region matching Vercel — `us-east-1`).
2. Apply the migrations in [`supabase/migrations/`](supabase/migrations/) in order. Either via the [Supabase CLI](https://supabase.com/docs/guides/local-development#manage-environments) (`supabase db push`), the dashboard SQL editor, or the Supabase MCP `apply_migration` tool.
3. Grab the URL + anon key + service_role key from **Project settings → API**, set them in Render (see §1 step 4) and locally in `backend/.env`.
4. Smoke test: `curl https://canhav-backend.onrender.com/api/market-map/sectors` should return the 7 seeded sectors with `project_count: 0`.
5. Ingest sectors one at a time per the skill at [.cursor/skills/market-map/SKILL.md](.cursor/skills/market-map/SKILL.md). Start with **Core Protocol Architecture** (M8.5).

## 6. Done

Site is live. Move to Milestone 9 (auth + Substack paid sync) when M8 wraps.
