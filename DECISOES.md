# Decisões tomadas por mim enquanto você estava fora (para revisar)

1. **Estéreo como dois pontos (±30°) em vez de somar em mono.** Você notou o som diferente na fase 1; manter a largura da música é mais natural. Configurável (abertura 0–60°).
2. **Core Audio Tap, sem BlackHole.** Funcionou na fase 0. BlackHole continua como plano B.
3. **Taxa de amostragem:** o motor usa a taxa do dispositivo de saída (antes fixa em 48 kHz).
4. **Apps agrupados pelo app principal** (helpers do Chrome, WebKit do Safari). Regra em `rootBundleID`; apps estranhos podem precisar de ajuste.
5. **Apps não adicionados ao mapa ficam no "Resto do sistema"**, que é um tap global excluindo os apps do mapa e o próprio Anyspace (evita eco).
6. **Câmera só ligada com som tocando** (10 s sem som → desliga). Prioriza bateria sobre resposta instantânea ao voltar o som (~2 s).
7. **Calibração automática nos 2 primeiros segundos** após ligar a câmera, mais o botão "Calibrar centro".
8. **Dois apps:** `Anyspace.app` (interface, id `dev.marco.anyspace`) e `AnyspaceCLI.app` (testes). Assinatura ad-hoc; o macOS pode pedir permissões de novo a cada recompilação.
9. **Sem repositório remoto:** git local, uma branch por etapa. `feature/fase-3-4-mapa-e-conforto` contém tudo depois da fase 2.
10. **Fase 5 (outros dispositivos) em versão mínima:** PCM 16 bits por UDP na rede local, sem Opus e sem criptografia (ver `PLANO.md`).
