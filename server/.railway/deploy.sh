#!/bin/bash
set -e

echo "🚀 Railway Deployment Starting..."
echo "📍 Environment: $NODE_ENV"
echo "📍 Database: ${DATABASE_URL:0:30}..." # Show first 30 chars only

# Run database migrations
echo ""
echo "📊 Running Prisma migrations..."
npx prisma migrate deploy

# Generate Prisma client
echo ""
echo "🔧 Generating Prisma client..."
npx prisma generate

# Run tests (only in development environment)
if [ "$NODE_ENV" = "development" ]; then
  echo ""
  echo "🧪 Running test suite..."
  npm run test:ci

  if [ $? -eq 0 ]; then
    echo "✅ All tests passed!"
  else
    echo "❌ Tests failed! Deployment aborted."
    exit 1
  fi
else
  echo ""
  echo "⏭️  Skipping tests (not in development environment)"
fi

echo ""
echo "✅ Deployment successful!"
echo "🌐 Starting server..."
