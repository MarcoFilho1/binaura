# Anyspace: plano de desenvolvimento completo (v2, 2026-10-28)

> **Estado (2026-10-28):** fases 0–5 implementadas em branches empilhadas; só as fases 0 e 1 (parcialmente) foram ouvidas por você. O restante aguarda `VALIDACAO.md`. Decisões minhas em `DECISOES.md`.

## 1. Objetivo
Fazer o som do Mac parecer vir de lugares fixos no espaço (tela na frente, notebook à esquerda, etc.) usando um fone comum (QCY HT05), e fazer esse espaço "ficar parado" quando você vira a cabeça, medindo a cabeça pela webcam.

## 2. Premissas decididas
- Hub: este Mac (macOS 26, Swift 6.3, só Command Line Tools). Fone ligado direto ao Mac.
- Captura do som do sistema: Core Audio Tap (sem driver). Plano B: BlackHole.
- Renderização 3D: AVAudioEngine + AVAudioEnvironmentNode (HRTF nativo).
- Cabeça: webcam + framework Vision (yaw). Interna para validar, depois a externa C922.
- Sem AirPods, sem celular nesta etapa.
- Sem Xcode: build por Swift Package Manager e um script que monta o `.app`.

## 3. Como o som flui
```
Apps do Mac ─▶ [Tap captura e silencia a saída original] ─▶ Anyspace
                                                            │ posiciona no espaço (HRTF)
Webcam ─▶ Vision ─▶ ângulo da cabeça ─▶ gira o espaço ─────▶│
                                                            ▼
                                                  Fone Bluetooth (HT05)
```

## 4. Divisão do trabalho (para eu trabalhar por horas sozinho)
**Eu faço sozinho, com testes automáticos:** todo o código, testes de matemática (filtros, ângulos, panorâmica), renderização offline de sons de teste, scripts, documentação.

**Só você consegue validar (vão para uma lista de validação):**
- Aceitar permissões do macOS (áudio e câmera), uma vez.
- Ouvir e dizer se o som "vem de onde deveria".
- Virar a cabeça e confirmar o sentido (esquerda/direita) e a sensação de atraso.

**Antes de você sair (3 minutos):** rodar a fase 0 uma vez e aceitar as duas permissões. Assim eu não fico bloqueado esperando clique.

Regras enquanto você estiver fora:
- Cada fase é uma branch (`feature/fase-N-...`); nada vai para `main` sem a sua validação.
- Quando eu precisar escolher algo que seria sua decisão, escolho o padrão mais simples e registro em `DECISOES.md` para você revisar.
- Nenhum teste que mude o som do Mac sem o app ter um "kill switch" (Ctrl+C e timeout automático que devolvem o som).
- Ao terminar, fecho tudo o que abri (câmera, processos, servidores).

## 5. Fases

### Fase 0: Captura e reprodução (em andamento)
Tarefas
1. Pacote Swift, captura com Core Audio Tap excluindo o próprio processo (evita eco).
2. Dispositivo agregado + reprodução no fone, silenciando a saída original.
3. Medidor de nível e relatório de atraso declarado.
4. Script que gera `Anyspace.app` com Info.plist (descrições de permissão) e assinatura ad-hoc.
5. Timeout opcional (`--seconds N`) para devolver o som sozinho.
Entrega: o som do Mac passa pelo app e sai no fone sem cortes.
Validação sua: tocar um vídeo, ouvir sem estalos; aceitar a permissão de áudio.

### Fase 1: Uma fonte no espaço
Tarefas
1. Trocar o passa-direto por AVAudioEngine: entrada do tap → nó de ambiente 3D (HRTF).
2. Comandos de teste: ângulo e distância via linha de comando.
3. Teste automático offline: renderiza uma varredura de ângulos e confere que o canal do lado certo fica mais forte e mais cedo (diferença de nível e de tempo entre os ouvidos).
4. Medir o atraso extra que o motor adiciona (alvo: menos de 20 ms).
Entrega: `anyspace --angle 90` põe o som à direita.
Validação sua: tocar uma música e confirmar esquerda/direita/atrás/frente.

### Fase 2: Cabeça pela webcam
Tarefas
1. Captura da câmera (AVCaptureSession) com escolha de câmera (interna ou C922) e 15–30 fps.
2. Vision: rotação horizontal (yaw) do rosto; tratamento de rosto perdido (mantém o último ângulo e depois volta devagar ao centro).
3. Filtro de suavização (média exponencial + zona morta pequena) com testes sobre sequências sintéticas.
4. Calibração do centro (atalho de teclado ou comando).
5. Ligar o ângulo ao ouvinte do ambiente 3D (o espaço gira ao contrário da cabeça).
6. Medidor de atraso do rastreio (da imagem ao som).
7. Modo de depuração: janelinha com o ângulo atual.
Entrega: virar a cabeça 90° para a esquerda joga a fonte frontal para a direita.
Validação sua: sentido correto, tremor, atraso percebido, funcionar com a interna e depois com a C922.

### Fase 3: Várias fontes e mapa
Tarefas
1. Captura por aplicativo (um tap por app) para separar navegador, música, etc.
2. Modelo de cena: lista de fontes com posição, volume e mudo; salvo em arquivo JSON.
3. Janela SwiftUI com mapa 2D: você no centro, ícones arrastáveis.
4. Ligação em tempo real do mapa ao motor de áudio.
Entrega: arrastar um app no mapa muda de onde o som vem.
Validação sua: usabilidade do mapa, apps que não aparecem, estabilidade.

### Fase 4: Realismo e conforto
Tarefas
1. Reverberação leve de sala, queda de volume com a distância.
2. Comparar perfis HRTF e escolher o melhor para você.
3. Teste cego "de onde vem?" com 3 posições, para você pontuar.
4. Economia de bateria: câmera só quando há som tocando, fps adaptativo.
5. Ícone na barra de menu, abrir no login, botão "desligar efeito".
Entrega: app de uso diário.
Validação sua: teste cego e uso por alguns dias.

### Fase 5: Outros dispositivos (depois, não entra nesta rodada)
Receber áudio de outro notebook ou celular por rede (UDP + Opus) como mais uma fonte do mapa.

## 6. Riscos
- Atraso do Bluetooth do HT05 (100–250 ms) é fixo, e o vídeo pode ficar dessincronizado.
- Webcam perde o rosto com a cabeça muito virada (acima de 60–70°).
- O yaw do Vision pode ser grosseiro (poucos graus de resolução); plano B: MediaPipe Face Mesh.
- HRTF genérico funciona melhor para uns ouvidos do que para outros.
- Se o tap falhar com som protegido (DRM) ou apps específicos, o plano B é o BlackHole.

## 7. Ordem de execução e tempo estimado
Fase 0 (hoje) → 1 → 2 → 3 → 4. Estimativa em trabalho corrido: fases 0–2 em cerca de 1–2 dias de calendário; fases 3–4 depois da sua primeira validação.

## 8. Repositório e fluxo
- `~/anyspace`, git local. Branch por fase, merge só depois de você validar.
- Pendente: criar repositório privado no GitHub para PRs? (precisa da sua autorização)
- Arquivos: `PLANO.md`, `DECISOES.md` (escolhas minhas para você revisar), `VALIDACAO.md` (checklist para você).
