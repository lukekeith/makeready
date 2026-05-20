#!/bin/bash

# Start Local PostgreSQL for Development
# This uses the same docker-compose file as CI for consistency

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLIENT_DIR="$(dirname "$PROJECT_ROOT")/client"

echo "🐘 Starting local PostgreSQL database..."

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  echo "❌ Docker is not running. Please start Docker first."
  exit 1
fi

# Start just the postgres service
cd "$CLIENT_DIR"
docker compose -f docker-compose.test.yml up -d postgres

# Wait for it to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
for i in {1..30}; do
  if docker compose -f docker-compose.test.yml exec -T postgres pg_isready -U test -d makeready_test > /dev/null 2>&1; then
    echo "✅ PostgreSQL is ready!"
    break
  fi
  echo "   Waiting... ($i/30)"
  sleep 1
done

# Enable pgvector extension
echo "📦 Enabling pgvector extension..."
docker compose -f docker-compose.test.yml exec -T postgres psql -U test -d makeready_test -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1 || true

# Run migrations
echo "🔄 Running database migrations..."
cd "$PROJECT_ROOT"
DATABASE_URL="postgresql://test:test@localhost:5433/makeready_test" npx prisma db push --skip-generate

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 Local database is ready!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Connection URL:"
echo "  postgresql://test:test@localhost:5433/makeready_test"
echo ""
echo "To use in your shell:"
echo "  export DATABASE_URL=\"postgresql://test:test@localhost:5433/makeready_test\""
echo ""
echo "To seed lesson data:"
echo "  cd server && npx tsx prisma/seed-lessons.ts"
echo ""
echo "To run tests:"
echo "  cd server && npm test"
echo ""
echo "To stop the database:"
echo "  cd client && docker compose -f docker-compose.test.yml down"
echo ""
