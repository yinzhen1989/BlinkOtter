#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v rsvg-convert >/dev/null || { echo "Install librsvg for rsvg-convert" >&2; exit 1; }
mkdir -p build/BlinkOtter.iconset
rsvg-convert -w 1024 -h 1024 Resources/BlinkOtter.svg -o Resources/BlinkOtter-1024.png
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" Resources/BlinkOtter-1024.png \
    --out "build/BlinkOtter.iconset/icon_${size}x${size}.png" >/dev/null
done
for size in 16 32 128 256 512; do
  retina=$((size * 2))
  sips -s format png -z "$retina" "$retina" Resources/BlinkOtter-1024.png \
    --out "build/BlinkOtter.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns build/BlinkOtter.iconset -o Resources/BlinkOtter.icns
echo "Created Resources/BlinkOtter.icns"
