#!/usr/bin/env bash
#
# Screenshot capture runner for MakeReady iPhone app.
#
# Runs from the capture repo but invokes xcodebuild in the iPhone repo.
# Fixtures are read from capture/fixtures/iphone/ via CAPTURE_ROOT.
#
# Usage:
#   bash runners/iphone/capture.sh                        # all workflows
#   bash runners/iphone/capture.sh login                  # single workflow
#   bash runners/iphone/capture.sh home 01-with-data      # single screen
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAPTURE_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
IPHONE_ROOT="${IPHONE_ROOT:-$(cd "$CAPTURE_REPO/../iphone" && pwd)}"

WORKFLOW="${1:-}"
SCREEN="${2:-}"

export CAPTURE_WORKFLOW="$WORKFLOW"
export CAPTURE_SCREEN="$SCREEN"
export CAPTURE_ROOT="$CAPTURE_REPO/fixtures/iphone"

echo "📸 MakeReady Capture (iPhone)"
echo "   Fixtures:  $CAPTURE_ROOT"
echo "   iPhone:    $IPHONE_ROOT"
echo "   Workflow:  ${WORKFLOW:-all}"
echo "   Screen:    ${SCREEN:-all}"
echo ""

cd "$IPHONE_ROOT"

xcodebuild test \
  -project MakeReady.xcodeproj \
  -scheme MakeReady \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:MakeReadyCaptureTests/CaptureRunner \
  -testLanguage en \
  -testRegion en_US \
  2>&1 | grep -E '(Test Case|✓|✗|error:|Screenshots written|CAPTURE:)' || true

echo ""
echo "✅ Screenshots written to $CAPTURE_ROOT/*/screenshots/"
