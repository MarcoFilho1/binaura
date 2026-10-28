#!/bin/zsh
# Compila e monta build/Anyspace.app (com as descrições de permissão) assinado ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
APP=build/Anyspace.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/anyspace "$APP/Contents/MacOS/anyspace"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.marco.anyspace</string>
  <key>CFBundleName</key><string>Anyspace</string>
  <key>CFBundleExecutable</key><string>anyspace</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.1</string>
  <key>LSMinimumSystemVersion</key><string>14.2</string>
  <key>LSUIElement</key><true/>
  <key>NSAudioCaptureUsageDescription</key><string>O Anyspace captura o som do Mac para posicioná-lo no espaço no seu fone.</string>
  <key>NSCameraUsageDescription</key><string>O Anyspace usa a câmera para medir a rotação da sua cabeça.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"
echo "Pronto: $APP"
