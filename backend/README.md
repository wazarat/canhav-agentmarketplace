# CanHav Backend

FastAPI service that powers waitlist signups (Instantly.ai) and will host the future agent-marketplace APIs.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/` | Service info |
| GET | `/api/health` | Liveness probe (also reports if Instantly is configured) |
| POST | `/api/waitlist` | Create a lead in the configured Instantly campaign |
| GET | `/docs` | Swagger UI |

### `POST /api/waitlist`

Request body:

```json
{
  "email": "founder@web3.xyz",
  "role": "web3",
  "source": "landing"
}
```

`role` is one of `web3 | ai | both` (optional). `source` is one of `landing | market-map | agents | footer | other` (defaults to `landing`). A hidden `company` field acts as a honeypot — bots that fill it get a silent 200.

Response:

```json
{ "ok": true, "lead_id": "<instantly-lead-id>" }
```

Errors:

- `422` — validation (bad email)
- `502` — upstream Instantly failure (5xx or network)
- 4xx upstream errors from Instantly (e.g. duplicate skip) are silently mapped to `200 ok` so we never tell a visitor their email is "already used".

## Local development

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# fill INSTANTLY_API_KEY + INSTANTLY_CAMPAIGN_ID
uvicorn app.main:app --reload --port 8000
```

Smoke test:

```bash
curl -X POST http://localhost:8000/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","role":"web3","source":"landing"}'
```

Visit `http://localhost:8000/docs` for the full Swagger UI.

## Configuration

| Env var | Required | Description |
|---------|----------|-------------|
| `INSTANTLY_API_KEY` | yes | Instantly.ai API key (Bearer token) |
| `INSTANTLY_CAMPAIGN_ID` | yes | Campaign UUID leads should be added to |
| `ALLOWED_ORIGINS` | yes | Comma-separated CORS origins |
| `ENVIRONMENT` | no | `development` / `production` |
| `PORT` | no | Defaults to 8000 (Render injects `$PORT`) |
| `LOG_LEVEL` | no | Defaults to `INFO` |

## Deploy (Render)

`render.yaml` is in the repo root for `backend/`. From Render: New → Blueprint → point at this repo → set the three secrets in the dashboard.
