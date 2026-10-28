#!/bin/zsh
# Cria (uma vez) um certificado de assinatura local, "Binaura Local Signing", no seu chaveiro de login.
# Com ele o app instalado mantém a mesma identidade a cada compilação, e o macOS deixa de pedir
# as permissões de áudio e câmera de novo. O certificado vale só neste Mac (não é um certificado da Apple).
set -euo pipefail
NAME="Binaura Local Signing"
if security find-certificate -c "$NAME" >/dev/null 2>&1; then
  echo "O certificado \"$NAME\" já existe. Nada a fazer."; exit 0
fi
WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/openssl.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CNF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/openssl.cnf" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
  -out "$WORK/cert.p12" -passout pass:binaura 2>/dev/null
security import "$WORK/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P binaura -T /usr/bin/codesign >/dev/null
echo "Certificado \"$NAME\" criado no chaveiro de login."
echo "Na primeira assinatura o macOS pode perguntar se o codesign pode usar a chave: escolha \"Permitir sempre\"."
