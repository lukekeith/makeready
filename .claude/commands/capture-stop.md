# Stop the Capture Comparison System

Stop the capture servers started by `/capture-start`. Leaves the shared Postgres
container running (other dev tooling may use it) unless the user asks to stop it.

## 1. Stop the capture servers

```bash
# capture UI (:5950) + API (:5951)
lsof -ti tcp:5950 | xargs kill 2>/dev/null; lsof -ti tcp:5951 | xargs kill 2>/dev/null
# Laravel /_capture server (:8001)
lsof -ti tcp:8001 | xargs kill 2>/dev/null
echo "stopped capture UI/API (:5950/:5951) and Laravel /_capture (:8001)"
```

**Note:** leave the **client Vite** dev server running by default — it's shared with
normal client development. Only stop it if the user explicitly wants to, e.g.:

```bash
# optional: stop the client Vite dev server (reads its port from client/public/hot)
PORT=$(sed -E 's#.*:([0-9]+).*#\1#' /Users/lukekeith/www/makeready/client/public/hot 2>/dev/null)
[ -n "$PORT" ] && lsof -ti tcp:$PORT | xargs kill 2>/dev/null && echo "stopped client vite ($PORT)"
```

## 2. Optional: stop Postgres

Only if the user wants the database container down too (it's shared with `/dev-start`):

```bash
cd /Users/lukekeith/www/makeready && docker compose stop postgres
```

## 3. Report

Confirm what was stopped and what was intentionally left running (Postgres + client Vite
by default).
