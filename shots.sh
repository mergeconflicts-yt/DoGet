#!/bin/bash
# Deterministic screenshots via -FillShot (DEBUG): build once, launch per
# screen, capture with simctl. No interaction needed.
set -e
cd /Users/nehilsrivastava/Documents/repos/DoGet
UDID=${UDID:-C505C74C-1A63-47C5-8C5B-D6C46F636C24}
OUT=${OUT:-/tmp/shots}
mkdir -p "$OUT"
xcodebuild -project Fill.xcodeproj -scheme Fill \
  -destination 'platform=iOS Simulator,name=iPhone 17' build > /dev/null
APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/Fill-*/Build/Products/Debug-iphonesimulator/Fill.app | head -1)
xcrun simctl install "$UDID" "$APP"
for s in welcome create overview challenge challenge-empty challenge-one challenge-half challenge-done challenge-broken challenge-claimed rescue celebration daywon logtoday; do
  xcrun simctl terminate "$UDID" com.fill.app 2>/dev/null || true
  xcrun simctl launch "$UDID" com.fill.app -FillShot "$s" > /dev/null
  sleep 2
  xcrun simctl io "$UDID" screenshot "$OUT/$s.png"
  echo "shot $s"
done
