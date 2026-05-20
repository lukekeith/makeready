#!/bin/bash

# MakeReady iOS Simulator Runner
# Usage: ./run-simulator.sh [device-name]

set -e

# Default device
DEVICE="${1:-iPhone 17 Pro}"

echo "🚀 Building MakeReady for iOS Simulator..."

# Build the app
xcodebuild -scheme MakeReady \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -configuration Debug \
  -derivedDataPath ./build \
  build

echo "✅ Build complete!"

# Get the app path
APP_PATH="$(pwd)/build/Build/Products/Debug-iphonesimulator/MakeReady.app"

# Boot the simulator if it's not running
echo "📱 Launching $DEVICE..."
DEVICE_UUID=$(xcrun simctl list devices available | grep "$DEVICE" | grep -oE '\([0-9A-F-]+\)' | tr -d '()')

if [ -z "$DEVICE_UUID" ]; then
  echo "❌ Error: Device '$DEVICE' not found"
  echo "Available devices:"
  xcrun simctl list devices available | grep "iPhone"
  exit 1
fi

# Boot the device
xcrun simctl boot "$DEVICE_UUID" 2>/dev/null || true

# Open Simulator app
open -a Simulator

# Wait for simulator to boot
echo "⏳ Waiting for simulator to boot..."
sleep 3

# Install the app
echo "📦 Installing MakeReady..."
xcrun simctl install "$DEVICE_UUID" "$APP_PATH"

# Launch the app
echo "🎉 Launching MakeReady..."
xcrun simctl launch "$DEVICE_UUID" com.makeready.MakeReady

echo "✨ MakeReady is now running on $DEVICE!"
echo ""
echo "To rebuild and relaunch, run: ./run-simulator.sh"
