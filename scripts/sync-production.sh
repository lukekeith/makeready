#!/bin/bash
set -e

# ─── Production Data Sync ────────────────────────────────────────────────────
# Syncs production PostgreSQL data to local Docker environment.
#
# Prerequisites:
#   - Railway CLI installed: npm i -g @railway/cli
#   - Logged in: railway login
#   - Docker Compose running: docker compose up -d postgres
#
# Usage:
#   ./scripts/sync-production.sh
# ──────────────────────────────────────────────────────────────────────────────

DUMP_FILE="/tmp/makeready_prod_dump.sql"
LOCAL_CONTAINER="makeready-postgres"
LOCAL_DB="makeready_dev"
LOCAL_USER="postgres"

echo "==> Checking prerequisites..."

if ! command -v railway &> /dev/null; then
  echo "Error: Railway CLI not installed. Run: npm i -g @railway/cli"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "$LOCAL_CONTAINER"; then
  echo "Error: Local postgres container not running. Run: docker compose up -d postgres"
  exit 1
fi

echo "==> Fetching production DATABASE_URL from Railway..."
PROD_DB_URL=$(railway variables get DATABASE_URL 2>/dev/null || true)

if [ -z "$PROD_DB_URL" ]; then
  echo ""
  echo "Could not auto-detect DATABASE_URL from Railway."
  echo "Make sure you've linked the correct Railway project/service:"
  echo "  railway link"
  echo ""
  echo "Or paste the production DATABASE_URL manually:"
  read -r PROD_DB_URL
fi

echo "==> Dumping production database..."
pg_dump "$PROD_DB_URL" \
  --no-owner \
  --no-acl \
  --clean \
  --if-exists \
  > "$DUMP_FILE"

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "==> Dump complete ($DUMP_SIZE)"

echo "==> Restoring to local database..."
docker exec -i "$LOCAL_CONTAINER" psql -U "$LOCAL_USER" -d "$LOCAL_DB" < "$DUMP_FILE"

echo "==> Cleaning up dump file..."
rm -f "$DUMP_FILE"

echo ""
echo "==> Sync complete! Production data is now in local postgres."
echo "    Local connection: postgresql://postgres:postgres@localhost:5434/makeready_dev"
