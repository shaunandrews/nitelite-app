#!/bin/bash
# Render the app icon and share card from design/ sources.
#   design/render.sh
# Writes: NiteLite/Assets.xcassets/AppIcon.appiconset/*.png (app icon sizes),
#         site/og.png (1200×630 share card), site/icon-512.png (touch icon).
# Uses headless Chrome with a throwaway profile, so it never touches your browser.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

shot() { # file width height out
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
        --user-data-dir="$TMP/profile" --window-size="$2,$3" --screenshot="$4" "file://$PWD/$1" >/dev/null 2>&1
}

shot design/icon.svg 1024 1024 "$TMP/icon-1024.png"
shot design/og.html 1200 630 site/og.png

ICONSET=NiteLite/Assets.xcassets/AppIcon.appiconset
for s in 16 32 128 256 512; do
    sips -s format png -z $s $s "$TMP/icon-1024.png" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -s format png -z $((s * 2)) $((s * 2)) "$TMP/icon-1024.png" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
sips -s format png -z 512 512 "$TMP/icon-1024.png" --out site/icon-512.png >/dev/null
ls -la site/og.png site/icon-512.png "$ICONSET"/icon_512x512@2x.png
