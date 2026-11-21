#!/bin/bash
# Build HopHop in Release mode and install it into /Applications.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="$(cat version.txt 2>/dev/null || echo "0.0.0")"
BUILD="$(git rev-list --count HEAD)"
DERIVED="$(mktemp -d)"
trap 'rm -rf "$DERIVED"' EXIT

xcodebuild build \
  -project HopHop.xcodeproj \
  -scheme HopHop \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD"

osascript -e 'quit app "HopHop"' 2>/dev/null || true
rm -rf /Applications/HopHop.app
cp -R "$DERIVED/Build/Products/Release/HopHop.app" /Applications/HopHop.app

echo "Installed HopHop $VERSION (build $BUILD) in /Applications"
