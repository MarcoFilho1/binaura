# Binaura

Áudio espacial para o Mac com um fone comum: o som de cada aplicativo parece vir de um lugar fixo ao seu redor, e o espaço "fica parado" quando você vira a cabeça (rastreada pela webcam).

Feito para o fone QCY HT05 no macOS 15+, sem driver de áudio e sem Xcode.

## Como funciona

```
Apps do Mac ─▶ Core Audio Tap (captura e silencia o original) ─▶ Binaura
                                                                 │ HRTF: posiciona cada fonte
Webcam ─▶ Vision ─▶ ângulo da cabeça ─▶ gira o espaço ──────────▶│
                                                                 ▼
                                                       Fone Bluetooth
```

- Cada app vira uma fonte estéreo = dois alto-falantes virtuais (abertura ajustável).
- Mapa 2D arrastável, reverberação de sala, 4 filtros de direção, teste cego, perfis salvos.
- A câmera só fica ligada enquanto há som tocando.
- Se o fone for removido, o app se reconstrói na nova saída em vez de deixar o Mac mudo.
- Áudio de outro dispositivo pela rede local (UDP, versão mínima, sem criptografia).

## Compilar e abrir

```
./scripts/build-app.sh          # gera build/Binaura.app e build/BinauraCLI.app
open build/Binaura.app         # feche com Cmd+Q antes de abrir uma versão nova
```

Permissões pedidas pelo macOS: gravação de áudio e câmera.

## Verificação sem fone

```
swift run binaura-check
```
Renderiza o espaço 3D offline e confere direção, distância, estéreo, filtro da cabeça, cena, perfis, mapa e rede (loopback).

## Documentos

- `PLANO.md`: fases do desenvolvimento.
- `DECISOES.md`: escolhas feitas durante o desenvolvimento.
- `VALIDACAO.md`: checklist de validação manual.
