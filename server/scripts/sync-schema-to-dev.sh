#!/bin/bash
# Sync Production Schema to Development Database
# This script copies your production schema to dev (useful for new dev database setup)

set -e

echo "🔄 Syncing Production Schema to Development Database..."
echo ""
echo "⚠️  WARNING: This will RESET your dev database!"
echo "⚠️  All data in the dev database will be lost."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Check if .env.development exists
if [ ! -f .env.development ]; then
  echo "❌ Error: .env.development not found!"
  exit 1
fi

# Load dev environment
export $(cat .env.development | grep -v '^#' | xargs)

echo ""
echo "📊 Resetting dev database and applying all migrations..."
npx prisma migrate reset --skip-seed --force

echo ""
echo "✅ Development database schema synced successfully!"
echo "💡 You now have a clean dev database with the production schema."
