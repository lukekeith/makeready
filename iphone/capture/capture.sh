#!/usr/bin/env bash
#
# Screenshot capture runner for MakeReady iPhone app.
#
# d2m's render lane (its project setting `renderCmd`). Fixtures are read from
# iphone/capture/fixtures/ via CAPTURE_ROOT.
#
# Usage:
#   bash iphone/capture/capture.sh                        # all workflows
#   bash iphone/capture/capture.sh ztmp-ui2 <key>         # one d2m render job
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IPHONE_ROOT="${IPHONE_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

WORKFLOW="${1:-}"
SCREEN="${2:-}"

export CAPTURE_WORKFLOW="$WORKFLOW"
export CAPTURE_SCREEN="$SCREEN"
export CAPTURE_ROOT="$SCRIPT_DIR/fixtures"

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
