# Start the Capture Comparison System

Bring up everything the `/compare` tooling needs: the capture Postgres database
(`makeready_capture`), the capture UI + API, and the web-capture dependencies
(Laravel `/_capture` server + the client Vite dev server that serves the
component-capture island).

Run the steps in order. Start long-running servers **in the background** so they
persist. Each step is idempotent — skip a server that's already responding.

> **Strictly additive — never disable other apps.** This command MUST NOT kill,
> restart, or `kill -9` any process. The capture system owns these ports and only
> these: **5950** (UI), **5951** (API), **8001** (Laravel `/_capture`), plus a shared
> **client Vite** dev server. If any port it needs is occupied by something that
> isn't the capture app, **report the conflict and skip that step** — do not attempt
> a start that could error, and never touch the other process. Do not change these
> ports. The main stack's ports (8000 client, 3010 server, 5434 postgres, 5174 docker
> vite) are separate and must be left alone.

## 1. Docker + Postgres

```bash
docker info > /dev/null 2>&1 && echo "Docker up" || echo "ERROR: start Docker Desktop first"
cd /Users/lukekeith/www/makeready && docker compose up -d postgres
# wait for health
for i in $(seq 1 30); do PGPASSWORD=postgres pg_isready -h localhost -p 5434 -U postgres >/dev/null 2>&1 && { echo "postgres ready"; break; }; sleep 1; done
```

## 2. Ensure the capture database + schema

```bash
# create the DB if absent (idempotent)
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='makeready_capture'" | grep -q 1 \
  || PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d postgres -c "CREATE DATABASE makeready_capture;"
# apply migrations + generate client
cd /Users/lukekeith/www/makeready/capture && npx prisma migrate deploy && npx prisma generate
```

## 3. Capture UI + API (background)

Start only if `:5950` is free or already the capture app — never kill whatever is there:

```bash
if curl -s http://localhost:5950/api/compare/manifest | grep -q '"viewports"'; then
  echo "capture UI/API already up"
elif lsof -ti tcp:5950 >/dev/null 2>&1 || lsof -ti tcp:5951 >/dev/null 2>&1; then
  echo "WARNING: :5950/:5951 in use by a NON-capture process — skipping (left untouched). Free it manually if you want the capture UI."
else
  echo "starting capture UI/API…"   # run the next line in the BACKGROUND
  ( cd /Users/lukekeith/www/makeready/capture && npm run dev )
fi
```
When started, it serves the UI on **:5950** and the API on **:5951** (Vite proxies
`/api` + `/screenshots`). Run it **in the background**.

## 4. Web-capture dependencies (background)

The **Web** capture button drives Playwright against a Laravel `/_capture` page that
mounts Vue via `@vite`. Start both **in the background**, reusing anything already up —
never kill an existing client Vite or whatever holds :8001.

```bash
# client Vite dev server — REUSE an existing one (don't start a second; two would fight
# over client/public/hot and could break the running client app). Only start if none is up.
HOT=/Users/lukekeith/www/makeready/client/public/hot
if [ -f "$HOT" ] && curl -s -o /dev/null "$(cat "$HOT")/@vite/client"; then
  echo "client vite already up ($(cat "$HOT"))"
else
  echo "starting client vite…"   # BACKGROUND — compiles the ComponentCapture island + @vite assets
  ( cd /Users/lukekeith/www/makeready/client && npm run dev )
fi

# Laravel /_capture server on :8001
if curl -s -o /dev/null http://localhost:8001; then
  echo "laravel :8001 already up"
elif lsof -ti tcp:8001 >/dev/null 2>&1; then
  echo "WARNING: :8001 in use by a NON-capture process — skipping (left untouched)."
else
  echo "starting laravel /_capture on :8001…"   # BACKGROUND
  ( cd /Users/lukekeith/www/makeready/capture && CAPTURE_FIXTURES_PATH="$(pwd)/fixtures/client" php ../client/artisan serve --port=8001 )
fi
```

## 5. Verify + report

```bash
echo "capture UI   :5950 -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:5950/compare)"
echo "capture API  :5951 -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:5950/api/compare/manifest)"
echo "postgres     :5434 -> $(PGPASSWORD=postgres pg_isready -h localhost -p 5434 -U postgres >/dev/null 2>&1 && echo OK || echo DOWN)"
echo "laravel      :8001 -> $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8001)"
echo "client vite        -> $(test -f /Users/lukekeith/www/makeready/client/public/hot && curl -s -o /dev/null -w '%{http_code}' "$(cat /Users/lukekeith/www/makeready/client/public/hot)/@vite/client" || echo 'no hot file')"
```

Report this table:

| Service | URL | Purpose |
|---|---|---|
| Compare UI | http://localhost:5950/compare | Side-by-side comparison + comments |
| Capture API | http://localhost:5951 | DB-backed comments/versions/screenshots |
| Capture DB | postgres://localhost:5434/makeready_capture | Comments, versions, screenshots |
| Laravel `/_capture` | http://localhost:8001 | Renders web fixtures for Playwright |
| Client Vite | (see `client/public/hot`) | Serves the component-capture island |

**Then remind the user:**
- The **`makeready-capture` MCP** (used by `/compare-process` and `/compare-adjust`) is
  launched by Claude from `.mcp.json` — it loads on **Claude restart / `/mcp` reconnect**,
  not by this command.
- **iPhone** captures still need a separate `xcodebuild` run (the user's go-ahead), since
  the simulator can't run headless in the background here.
- Stop everything with **`/capture-stop`**.
