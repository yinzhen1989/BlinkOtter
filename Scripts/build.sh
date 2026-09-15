#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache build/dmg
export CLANG_MODULE_CACHE_PATH="$PWD/build/module-cache"
export SWIFT_MODULECACHE_PATH="$PWD/build/module-cache"

clang -fobjc-arc -O2 -Wno-deprecated-declarations -I/opt/homebrew/include \
  -c Sources/BlinkOtter/Bridge.m -o build/Bridge.o
swiftc -O -import-objc-header Sources/BlinkOtter/Bridge.h \
  -framework AppKit -framework OpenGL -L/opt/homebrew/lib -lmpv \
  Sources/BlinkOtter/main.swift build/Bridge.o -o build/BlinkOtter
APP="$PWD/build/BlinkOtter.app"
rm -rf "$APP" build/dmg/BlinkOtter.app build/dmg/Applications
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks" "$APP/Contents/Resources"
cp build/BlinkOtter "$APP/Contents/MacOS/BlinkOtter"
cp Resources/Info.plist "$APP/Contents/Info.plist"
python3 Scripts/bundle_deps.py "$APP"

if [[ -f LICENSE ]]; then cp LICENSE "$APP/Contents/Resources/LICENSE"; fi
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname BlinkOtter -srcfolder build/dmg -ov -format UDZO build/BlinkOtter-0.1.0-arm64.dmg
hdiutil verify build/BlinkOtter-0.1.0-arm64.dmg
echo "Built $APP and $PWD/build/BlinkOtter-0.1.0-arm64.dmg"
