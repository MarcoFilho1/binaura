# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos
<!-- Nota: o esquema do Impeccable só prevê web/ios/android/adaptive. Este é um app nativo de macOS em SwiftUI (SwiftPM, sem Xcode). -->

## Users
Pessoas com fones de ouvido Bluetooth comuns (sem áudio espacial nem sensor de movimento, ex.: QCY HT05) num Mac, que trabalham ou assistem vídeo com vários apps tocando. Primeiro usuário real: o próprio autor, no dia a dia. A intenção é distribuir para outras pessoas.

## Product Purpose
Dar a um fone comum o áudio espacial que hoje só fones caros têm: o som de cada app parece vir de um lugar fixo ao redor, e o espaço fica parado quando a pessoa vira a cabeça (medida pela webcam). Sucesso: ligar uma vez, ajustar poucas vezes, e o efeito ficar fora do caminho.

## Positioning
Espacial com rastreio de cabeça em qualquer fone, só com o Mac e a webcam, sem driver de áudio e sem hardware novo.

## Operating Context
Uso diário e rápido pela barra de menu (ligar/desligar, trocar perfil); a janela é aberta de vez em quando para arrumar o mapa, volumes, câmera e som. Usado com fone na cabeça, o som tocando, a câmera ligada só enquanto há som.

## Capabilities and Constraints
- Captura o som do sistema por app (Core Audio Tap), mapa 2D arrastável, perfis salvos, reverberação, 4 filtros de direção (HRTF), abertura do estéreo, rastreio da cabeça pela webcam com calibração e janela de debug, teste cego, áudio de outro dispositivo pela rede (mínimo).
- Nativo SwiftUI, macOS 15+, sem Xcode (SwiftPM + script que monta o .app). Interface em português (pt-BR).
- O app silencia o som original dos apps enquanto ligado; falhas precisam sempre devolver o som (ex.: troca de saída).
- Permissões do macOS: gravação de áudio e câmera.
- Decidido: abertura padrão 30°, reverberação ligada, filtro HRTF alta qualidade, sentido da cabeça invertido.

## Brand Commitments
Nome: Binaura. Sem identidade visual definida. A pessoa pediu aparência premium e totalmente nativa do macOS.

## Evidence on Hand
Nenhuma prova de clientes ou métricas. Resultado real do autor: 12 de 12 no teste cego (esquerda/frente/direita) com HRTF de alta qualidade. Não inventar números.

## Product Principles
1. O efeito some da frente: pouco a configurar, estados claros (ligado, pausado, sem câmera, saída trocada).
2. Nunca deixar a pessoa sem som: erros e trocas de dispositivo se explicam e se recuperam sozinhos.
3. A barra de menu é a superfície principal do dia a dia; a janela é a oficina.
4. Quem instala pela primeira vez precisa entender as permissões e o que o app faz antes de tocar no som.

## Accessibility & Inclusion
Respeitar o padrão do macOS: modo escuro e claro, texto dinâmico/legível, contraste, navegação por teclado, rótulos para VoiceOver, reduzir movimento. O mapa deve ter alternativa por teclado/campos numéricos, já que arrastar não é acessível a todos.
