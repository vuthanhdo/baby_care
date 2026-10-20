#!/bin/zsh
# Render App Store screenshots with StoreScreenshotsUITests on one simulator.
# Usage: Tools/store_screenshots.sh <simulator-udid> <device-folder> <vi|en>
# Example: Tools/store_screenshots.sh 64A07B86-AFE6-4BD4-82C3-84EA21FFA586 iphone-6.9 vi
# Output: AppStore/screenshots/<device-folder>/<lang>/NN-name.png (full device resolution, status bar 9:41).
set -euo pipefail
UDID=$1; DEVICE=$2; LANG_=$3
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DD="${STORE_DD:-/tmp/babycare-store-shots}"
OUT="$ROOT/AppStore/screenshots/$DEVICE/$LANG_"
mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 >/dev/null
TEST_RUNNER_STORE_SCREENSHOTS=1 TEST_RUNNER_STORE_LANGUAGE="$LANG_" xcodebuild \
  -project "$ROOT/BabyCare.xcodeproj" -scheme BabyCare \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DD" \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:BabyCareUITests/StoreScreenshotsUITests test 2>&1 | grep -E "Test case .* (passed|failed)|\*\* TEST|error:" | grep -v SourcePackages | sort -u \
  || echo "xcodebuild reported failures; exporting whatever was captured"
BUNDLE="$(ls -dt "$DD"/Logs/Test/*.xcresult | head -1)"
TMP="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$BUNDLE" --output-path "$TMP" >/dev/null
python3 - "$TMP" "$OUT" <<'PY'
import json, os, re, shutil, sys
src, out = sys.argv[1], sys.argv[2]
manifest = json.load(open(os.path.join(src, "manifest.json")))
count = 0
for test in manifest:
    for a in test.get("attachments", []):
        name = a.get("suggestedHumanReadableName") or ""
        m = re.match(r"(\d\d-[a-z-]+)_", name)
        if m and name.endswith(".png"):
            shutil.copy(os.path.join(src, a["exportedFileName"]), os.path.join(out, m.group(1) + ".png")); count += 1
print(f"exported {count} screenshots to {out}")
PY
xcrun simctl status_bar "$UDID" clear >/dev/null || true
