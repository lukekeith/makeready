#!/usr/bin/env bash
#
# Builds the capture UI for production deployment.
# Fixtures and screenshots live directly in fixtures/ — no cross-repo sync needed.
#
# Usage: ./deploy.sh
#
set -euo pipefail
cd "$(dirname "$0")"

echo "Building Vite frontend..."
npm run build

echo ""
echo "Done. Ready to deploy:"
echo "  git add . && git commit && git push"
