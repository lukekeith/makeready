#!/bin/bash
# Migrate Development Database
# This script applies all migrations to the dev database

set -e

echo "📊 Migrating Development Database..."
echo ""

# Check if .env.development exists
if [ ! -f .env.development ]; then
  echo "❌ Error: .env.development not found!"
  echo "Please create .env.development with your dev database credentials."
  exit 1
fi

# Load dev environment
export $(cat .env.development | grep -v '^#' | xargs)

echo "Database: ${DATABASE_URL:0:40}..."
echo ""

# Run migrations
npx prisma migrate deploy

echo ""
echo "✅ Development database migrated successfully!"
