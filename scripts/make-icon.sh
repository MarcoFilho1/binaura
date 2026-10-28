#!/bin/zsh
# Desenha o ícone (1024 px, em código) e gera Resources/AppIcon.icns. Só precisa rodar de novo se o desenho mudar.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product BinauraApp
WORK=$(mktemp -d)
.build/release/BinauraApp --icon "$WORK"
SET="$WORK/AppIcon.iconset"; mkdir -p "$SET" Resources
for size in 16 32 128 256 512; do
  sips -z $size $size "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size*2)) $((size*2)) "$WORK/icon-1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Pronto: Resources/AppIcon.icns"
