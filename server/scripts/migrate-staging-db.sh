#!/bin/bash
# Migrate Staging Database
# This script applies all migrations to the staging database

set -e

echo "📊 Migrating Staging Database..."
echo ""

# Check if .env.staging exists
if [ ! -f .env.staging ]; then
  echo "❌ Error: .env.staging not found!"
  echo "Please create .env.staging with your staging database credentials."
  exit 1
fi

# Load staging environment
export $(cat .env.staging | grep -v '^#' | xargs)

echo "Database: ${DATABASE_URL:0:40}..."
echo ""

# Run migrations
npx prisma migrate deploy

echo ""
echo "✅ Staging database migrated successfully!"
