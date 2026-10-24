#!/usr/bin/env bash
#
# d2m video-captures — the recording runner, MakeReady's `recordCmd`:
#
#   bash capture/runners/iphone/record.sh
#
# d2m's ios-sim adapter runs it from the repo root with CAPTURE_JOB = the job file
# (<renderJobDir>/recordings/<takeId>.json) and TEST_RUNNER_CAPTURE_RECORDING=1 /
# TEST_RUNNER_CAPTURE_JOB, which xcodebuild forwards to the UI test without the prefix.
#
#   1. maps the job's device key to a simulator name (D26) and boots the newest-runtime one by UDID;
#   2. builds the MakeReadyCapture scheme for testing when its sources changed since the last
#      build ("once"; the adapter's 600 s recording timeout starts at the "D2M-RECORD: recording" line);
#   3. starts `simctl io recordVideo`, exports recordStartedAt (epoch ms), runs
#      MakeReadyCaptureUITests/RecordingRunner, and stops the recording with SIGINT (a kill can
#      leave the .mov unfinalized);
#   4. exits with the test's code — on failure the LAST line says why (d2m stores it on the take).
#
# A UI test runs inside the simulator and cannot exec host tools, which is why simctl runs here.
# Only MakeReadyCaptureUITests runs: CaptureRunner (the stills) never does, so no tracked
# screenshot is ever touched.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CAPTURE_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"
IPHONE_ROOT="${IPHONE_ROOT:-$(cd "$CAPTURE_REPO/../iphone" && pwd)}"
DD="$IPHONE_ROOT/build/capture-dd"
JOB="${CAPTURE_JOB:?CAPTURE_JOB is not set — the d2m ios-sim adapter sets it to the recording job file}"

field() { ruby -rjson -e 'print JSON.parse(File.read(ARGV[0])).fetch(ARGV[1])' "$JOB" "$1"; }
DEVICE_KEY="$(field device)"
OUTPUT="$(field output)"

# D26: the fixture's device key → the simulator that records it.
case "$DEVICE_KEY" in
  iphone-se)         SIM_NAME="iPhone SE (3rd generation)" ;;
  iphone-15-pro)     SIM_NAME="iPhone 15 Pro" ;;
  iphone-16-pro-max) SIM_NAME="iPhone 16 Pro Max" ;;
  *) echo "unknown device key $DEVICE_KEY — record.sh maps iphone-se, iphone-15-pro and iphone-16-pro-max"; exit 2 ;;
esac

# The first available simulator of that name on the newest iOS runtime.
UDID="$(xcrun simctl list devices available -j | ruby -rjson -e '
  name = ARGV[0]
  devices = JSON.parse($stdin.read)["devices"].select { |runtime, _| runtime.include?("SimRuntime.iOS-") }
  version = ->(runtime) { runtime[/iOS-([\d-]+)\z/, 1].to_s.split("-").map(&:to_i) }
  devices.keys.sort_by { |runtime| version.(runtime) }.reverse_each do |runtime|
    match = devices[runtime].find { |d| d["name"] == name && d["isAvailable"] }
    if match then print match["udid"]; exit 0 end
  end' "$SIM_NAME")"
if [ -z "$UDID" ]; then
  echo "no simulator installed for $DEVICE_KEY ($SIM_NAME)"
  exit 3
fi

if ! ruby "$IPHONE_ROOT/scripts/capture-targets.rb" --check >/dev/null 2>&1; then
  echo "MakeReadyCapture is out of sync with MakeReady — run: ruby iphone/scripts/capture-targets.rb"
  exit 4
fi

echo "D2M-RECORD: booting $SIM_NAME ($UDID)"
xcrun simctl bootstatus "$UDID" -b >/dev/null

cd "$IPHONE_ROOT"
xctestrun() { ls "$DD"/Build/Products/MakeReadyCapture_*.xctestrun 2>/dev/null | head -1 || true; }
STAMP="$(xctestrun)"
if [ -z "$STAMP" ] || [ -n "$(find MakeReady MakeReadyCapture MakeReadyCaptureTests MakeReadyCaptureUITests MakeReady.xcodeproj/project.pbxproj -type f -newer "$STAMP" -print -quit)" ]; then
  echo "D2M-RECORD: building MakeReadyCapture (sources changed since the last build)"
  mkdir -p "$DD"
  if ! xcodebuild build-for-testing -project MakeReady.xcodeproj -scheme MakeReadyCapture \
      -destination "id=$UDID" -derivedDataPath "$DD" > "$DD/build.log" 2>&1; then
    grep -E 'error:' "$DD/build.log" | head -5 || true
    echo "MakeReadyCapture failed to build — see $DD/build.log"
    exit 5
  fi
fi

mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT.mov" "$OUTPUT.timeline.json" "$OUTPUT.app.json" "$OUTPUT".go-*
echo "D2M-RECORD: recording on $SIM_NAME ($UDID)"
REC_LOG="$OUTPUT.recordvideo.log"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$OUTPUT.mov" 2> "$REC_LOG" &
REC_PID=$!
TEST_PID=""
stop_recording() {
  # Already stopped at the timeline (below): let it finish writing — a second INT can cut the file short.
  if [ -s "$OUTPUT.timeline.json" ]; then wait "$REC_PID" 2>/dev/null || true; return; fi
  if kill -0 "$REC_PID" 2>/dev/null; then kill -INT "$REC_PID"; wait "$REC_PID" 2>/dev/null || true; fi
}
on_signal() {
  if [ -n "$TEST_PID" ]; then kill -TERM "$TEST_PID" 2>/dev/null || true; fi
  stop_recording
  echo "recording cancelled"
  exit 143
}
trap on_signal TERM INT
for _ in $(seq 1 100); do grep -q "Recording started" "$REC_LOG" 2>/dev/null && break; sleep 0.05; done

TEST_RUNNER_CAPTURE_RECORD_STARTED_AT="$(perl -MTime::HiRes=time -e 'printf "%d", time() * 1000')"
export TEST_RUNNER_CAPTURE_RECORD_STARTED_AT
export TEST_RUNNER_CAPTURE_DEVICE_NAME="$SIM_NAME"
export TEST_RUNNER_CAPTURE_RECORDING=1
export TEST_RUNNER_CAPTURE_JOB="$JOB"
TEST_LOG="$OUTPUT.test.log"
# In the background + `wait`: bash defers a trap while a FOREGROUND child runs, and the adapter's
# timeout TERM must stop recordVideo at once.
xcodebuild test-without-building -project MakeReady.xcodeproj -scheme MakeReadyCapture \
  -destination "id=$UDID" -derivedDataPath "$DD" \
  -only-testing:MakeReadyCaptureUITests/RecordingRunner/testRecord > "$TEST_LOG" 2>&1 &
TEST_PID=$!
# Relay the runner's "CAPTURE: step n/N" lines live, so d2m can show which step is recording.
( tail -n +1 -F "$TEST_LOG" 2>/dev/null | grep --line-buffered -E 'CAPTURE: step [0-9]+/[0-9]+' ) &
STEP_PID=$!
# Stop the video the moment the runner writes its timeline (after its tail, or at a failed card) —
# the app is still on screen then. Waiting for xcodebuild to return recorded the app quitting and
# the iOS home screen into the end of the take.
( while [ ! -s "$OUTPUT.timeline.json" ]; do kill -0 "$TEST_PID" 2>/dev/null || exit 0; sleep 0.1; done
  kill -INT "$REC_PID" 2>/dev/null || true ) &
WATCH_PID=$!
set +e
wait "$TEST_PID"
CODE=$?
pkill -P "$STEP_PID" 2>/dev/null; kill "$STEP_PID" 2>/dev/null
kill "$WATCH_PID" 2>/dev/null
set -e
TEST_PID=""
stop_recording
trap - TERM INT

grep -E 'CAPTURE:' "$TEST_LOG" | tail -5 || true
if [ "$CODE" -ne 0 ]; then
  LAST="$(grep -E 'CAPTURE: ✗' "$TEST_LOG" | tail -1 | sed -E 's/.*CAPTURE: ✗ //' || true)"
  echo "${LAST:-the recording runner failed (xcodebuild exit $CODE) — see $TEST_LOG}"
fi
exit "$CODE"
