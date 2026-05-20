#!/bin/bash
set -e

echo "🚀 Starting MakeReady Server deployment..."

# Run database migrations
echo "📦 Running database migrations..."
if npx prisma migrate deploy; then
  echo "✅ Migrations completed successfully"
else
  echo "⚠️  Migration failed, but continuing with server start..."
  echo "⚠️  Database may not be up to date!"
fi

# Start the server
echo "🌐 Starting server..."
exec node dist/index.js
