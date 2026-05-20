#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/ios-build-check.sh [--test] [--clean]

Runs xcodebuild against an iOS Simulator destination to catch compile errors
before attempting an on-device run.

Options:
  --test   Run `xcodebuild test` (slower). Default: build only.
  --clean  Add a `clean` step before build/test.
EOF
}

RUN_TESTS=false
DO_CLEAN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test)
      RUN_TESTS=true
      shift
      ;;
    --clean)
      DO_CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IPHONE_DIR="$REPO_ROOT/iphone"

PROJECT="MakeReady.xcodeproj"
SCHEME="MakeReady"
CONFIGURATION="Debug"
SDK="iphonesimulator"

if [[ ! -d "$IPHONE_DIR/$PROJECT" ]]; then
  echo "Expected iOS project at: $IPHONE_DIR/$PROJECT" >&2
  exit 1
fi

DEST_ID="$(
  xcrun simctl list devices available -j | python3 -c '
import json, sys

data = json.load(sys.stdin)

def iter_devices():
    devices = data.get("devices", {})
    for _runtime, devs in devices.items():
        for d in devs:
            yield d

booted = [d for d in iter_devices() if d.get("isAvailable") and d.get("state") == "Booted"]
if booted:
    print(booted[0].get("udid", ""))
    raise SystemExit(0)

iphones = [d for d in iter_devices() if d.get("isAvailable") and str(d.get("name", "")).startswith("iPhone")]
if iphones:
    print(iphones[0].get("udid", ""))
    raise SystemExit(0)

print("")
'
)"

if [[ -z "$DEST_ID" ]]; then
  echo "Could not find an available iOS Simulator destination (no Booted device and no available iPhone device)." >&2
  echo "Try opening Simulator once, or run: xcrun simctl list devices available" >&2
  exit 1
fi

cd "$IPHONE_DIR"

echo "Using iOS Simulator destination id: $DEST_ID" >&2

action="build"
if [[ "$RUN_TESTS" == "true" ]]; then
  action="test"
fi

cmd=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -sdk "$SDK"
  -destination "platform=iOS Simulator,id=$DEST_ID"
)

if [[ "$DO_CLEAN" == "true" ]]; then
  cmd+=(clean)
fi

cmd+=("$action")

# Avoid device signing issues; Simulator builds shouldn't require signing.
cmd+=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
)

"${cmd[@]}"
