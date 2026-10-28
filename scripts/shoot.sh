#!/bin/zsh
# Tira o print de uma janela do Binaura em modo demonstração (dados de exemplo; sem áudio e sem tocar na sua configuração).
# Precisa da permissão de Gravação de Tela para o app que roda este script.
#   scripts/shoot.sh main|menu|welcome|blind|camera ARQUIVO.png [--dark] [--delay SEGUNDOS]
set -euo pipefail
cd "$(dirname "$0")/.."
name=$1; out=$2; shift 2
delay=4; args=()
while [ $# -gt 0 ]; do
  case $1 in --delay) delay=$2; shift 2 ;; *) args+=("$1"); shift ;; esac
done
log=$(mktemp)
open -n --stdout "$log" build/Binaura.app --args --show "$name" --seconds $((delay + 20)) "${args[@]}"
for _ in {1..60}; do grep -q WINDOW "$log" && break; sleep 0.5; done
wid=$(grep WINDOW "$log" | awk '{print $2}')
[ -n "$wid" ] || { echo "a janela não abriu"; exit 1; }
sleep "$delay"
screencapture -x -l "$wid" "$out"
pkill -n -x Binaura || true
echo "Salvo: $out"
