#!/bin/zsh
# Compila o Binaura, instala em /Applications e abre.
# Usa o certificado local "Binaura Local Signing" se existir (rode scripts/make-signing-cert.sh uma vez);
# senão assina de forma ad-hoc, e o macOS pode pedir as permissões de novo a cada instalação.
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="Binaura Local Signing"

./scripts/build-app.sh
pkill -x Binaura 2>/dev/null || true; sleep 1

APP=/Applications/Binaura.app
rm -rf "$APP"
cp -R build/Binaura.app "$APP"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  codesign --force --deep --sign "$NAME" "$APP"
  echo "Assinado com \"$NAME\"."
else
  codesign --force --deep --sign - "$APP"
  echo "Assinatura ad-hoc (rode scripts/make-signing-cert.sh para uma identidade estável)."
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
codesign --verify --deep --strict "$APP" && echo "Instalado: $APP"
open "$APP"
