#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
swift build -c release
APP="MacropadBinder.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacropadBinder "$APP/Contents/MacOS/MacropadBinder"
cp Resources/Info.plist "$APP/Contents/Info.plist"
open "$APP"
echo "launched $PWD/$APP"
