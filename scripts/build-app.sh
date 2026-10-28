#!/bin/zsh
# Compila e monta dois apps assinados ad-hoc em build/:
#   Anyspace.app     interface gráfica (mapa, barra de menu)
#   AnyspaceCLI.app  linha de comando, para testes (abra com `open -n -W --stdout log AnyspaceCLI.app --args ...`)
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

make_app() {  # nome, executável compilado, id do bundle, LSUIElement
  local app="build/$1.app"
  rm -rf "$app"
  mkdir -p "$app/Contents/MacOS"
  cp ".build/release/$2" "$app/Contents/MacOS/$1"
  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$3</string>
  <key>CFBundleName</key><string>$1</string>
  <key>CFBundleExecutable</key><string>$1</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>0.4</string>
  <key>CFBundleShortVersionString</key><string>0.4</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><$4/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAudioCaptureUsageDescription</key><string>O Anyspace captura o som do Mac para posicioná-lo no espaço no seu fone.</string>
  <key>NSCameraUsageDescription</key><string>O Anyspace usa a câmera para medir a rotação da sua cabeça.</string>
</dict>
</plist>
PLIST
  codesign --force --sign - "$app"
  echo "Pronto: $app"
}

make_app Anyspace AnyspaceApp dev.marco.anyspace false
make_app AnyspaceCLI anyspace dev.marco.anyspace.cli true
