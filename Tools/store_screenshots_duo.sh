#!/bin/zsh
# Render the iPhone Duo App Store screenshots on the open (unfolded) inner display.
# XCUITest captures the open Duo as black frames, so StoreScreenshotsUITests drives the app with
# STORE_HOST_CAPTURE=1 and this script takes each picture with `simctl io screenshot --display`.
# Usage: Tools/store_screenshots_duo.sh <duo-udid> <vi|en>   (unfold the Duo in Xcode's Device Hub first)
# Output: AppStore/screenshots/iphone-duo/<lang>/NN-name.png at 2853 × 2007 (inner display, status bar 9:41).
set -euo pipefail
UDID=$1; LANG_=$2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${STORE_DD:-/tmp/babycare-store-shots-duo}"
OUT="$ROOT/AppStore/screenshots/iphone-duo/$LANG_"
RUNNER=com.vuthanhdo.BabyCareUITests.xctrunner
mkdir -p "$OUT"
xcrun simctl bootstatus "$UDID" -b >/dev/null
INNER=$(xcrun simctl io "$UDID" enumerate | awk '/UUID:/ { id = $2 } /Default width: 2007/ { print id; exit }')
if [[ -z "$INNER" ]]; then echo "inner display of $UDID not found (is it an iPhone Duo?)"; exit 1; fi
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 >/dev/null

LOG="$(mktemp)"
# Parallel testing would run on a fresh clone, which boots folded.
TEST_RUNNER_STORE_SCREENSHOTS=1 TEST_RUNNER_STORE_LANGUAGE="$LANG_" TEST_RUNNER_STORE_HOST_CAPTURE=1 xcodebuild \
  -project "$ROOT/BabyCare.xcodeproj" -scheme BabyCare \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:BabyCareUITests/StoreScreenshotsUITests test > "$LOG" 2>&1 &
PID=$!

count=0
while kill -0 $PID 2>/dev/null; do
  DATA=$(xcrun simctl get_app_container "$UDID" "$RUNNER" data 2>/dev/null || true)
  if [[ -n "$DATA" && -d "$DATA/tmp/store-capture" ]]; then
    for ready in "$DATA"/tmp/store-capture/*.ready(N); do
      name=${ready:t:r}
      [[ -e "$DATA/tmp/store-capture/$name.done" ]] && continue
      xcrun simctl io "$UDID" screenshot --display="$INNER" "$OUT/$name.png" >/dev/null 2>&1
      touch "$DATA/tmp/store-capture/$name.done"
      count=$((count + 1))
      echo "captured $name"
    done
  fi
  sleep 0.5
done
wait $PID || echo "xcodebuild reported failures"
grep -E "Test case .* (passed|failed)|\*\* TEST|error:" "$LOG" | grep -v SourcePackages | sort -u || true
echo "exported $count screenshots to $OUT"
xcrun simctl status_bar "$UDID" clear >/dev/null || true
