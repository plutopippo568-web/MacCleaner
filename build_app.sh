#!/bin/bash
# Compila MacCleaner.app per Apple silicon (richiede Xcode o Command Line Tools su un Mac).
set -e
swift build -c release --arch arm64
APP=MacCleaner.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
cp .build/arm64-apple-macosx/release/MacCleaner "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MacCleaner</string>
<key>CFBundleIdentifier</key><string>local.maccleaner.app</string>
<key>CFBundleExecutable</key><string>MacCleaner</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PL
codesign --force --deep -s - "$APP"
echo "Fatto: $APP  (clic destro > Apri la prima volta)"
