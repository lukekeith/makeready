#!/usr/bin/env bash
# Single-command dev environment: Docker stack (website + /admin client :8001,
# API server :3010, Postgres :5434) + the capture compare UI/API (:5950/:5951).
#
# Idempotent: `docker compose up -d` no-ops for running containers, and an
# already-running capture server is reused instead of crashing on EADDRINUSE.
set -euo pipefail
cd "$(dirname "$0")/.."

docker compose up -d

if curl -sf --max-time 2 http://localhost:5950/api/compare/manifest >/dev/null 2>&1; then
  echo "✓ capture UI/API already running — http://localhost:5950/compare"
  echo "  (stop it first if you want it in this terminal)"
elif lsof -ti tcp:5950 >/dev/null 2>&1 || lsof -ti tcp:5951 >/dev/null 2>&1; then
  echo "✗ :5950/:5951 are held by a non-capture process — not starting capture."
  exit 1
else
  echo "→ starting capture UI/API (Ctrl-C stops capture; docker stack keeps running)"
  exec npm run dev --prefix capture
fi
