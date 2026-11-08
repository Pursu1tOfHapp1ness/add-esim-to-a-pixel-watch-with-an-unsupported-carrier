#!/usr/bin/env bash
# Grants runtime permissions to the sideloaded Pixel Watch app, pushes a
# QR-only testConfig.json for the given carrier ID and restarts the app.
#
# Usage: ./push-config.sh <carrier_id> [display_name]
#        ./push-config.sh --file <path-to-json>
# Find <carrier_id> in logcat: "Search matching config with sim carrier id: <N>"
set -euo pipefail

P=com.google.android.apps.wear.companion
D=/storage/emulated/0/Android/data/$P/files

usage() { sed -n '5,7p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

command -v adb >/dev/null || { echo "adb not found (macOS: brew install --cask android-platform-tools)"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "No device in 'device' state. Check 'adb devices'."; exit 1; }
adb shell pm path "$P" >/dev/null 2>&1 || { echo "$P is not installed."; exit 1; }

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

case "${1:-}" in
  --file) [[ -f "${2:-}" ]] || usage; cp "$2" "$tmp" ;;
  ''|-h|--help) usage ;;
  *)
    [[ "$1" =~ ^[0-9]+$ ]] || usage
    printf '{\n  "carrier_id": %s,\n  "display_name": "%s",\n  "setup_mechanisms": [0]\n}\n' \
      "$1" "${2:-My carrier}" > "$tmp"
    ;;
esac

if command -v jq >/dev/null; then jq . "$tmp" >/dev/null; fi

for p in BLUETOOTH_CONNECT BLUETOOTH_SCAN READ_PHONE_STATE POST_NOTIFICATIONS \
         ACCESS_FINE_LOCATION ACCESS_COARSE_LOCATION CAMERA; do
  adb shell pm grant "$P" "android.permission.$p" 2>/dev/null || echo "warn: could not grant $p"
done

adb shell "mkdir -p $D"
adb push "$tmp" "$D/testConfig.json"
adb shell am force-stop "$P"
adb shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 >/dev/null

echo "Pushed. Open Settings > Mobile network. In logcat expect:"
echo "  Getting supported flows for <id>"
echo "  device is allowing eSIM setup by Qrcode"
