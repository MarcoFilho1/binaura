---
name: Anyspace
description: Mesa de som nativa do macOS; o palco espacial é o protagonista e o resto fala o vocabulário do sistema.
colors:
  accent-user: "#007AFF"
  state-ok: "#34C759"
  state-attention: "#FF9500"
  state-error: "#FF3B30"
  window-background: "#ECECEC"
  text-primary: "#000000"
  text-secondary: "#3C3C4399"
  fill-quaternary: "#74748014"
  separator: "#0000001A"
typography:
  title:
    fontFamily: "SF Pro (system)"
    fontSize: "22px"
    fontWeight: 600
  headline:
    fontFamily: "SF Pro (system)"
    fontSize: "13px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro (system)"
    fontSize: "13px"
    fontWeight: 400
  callout:
    fontFamily: "SF Pro (system)"
    fontSize: "12px"
    fontWeight: 400
  label:
    fontFamily: "SF Pro (system)"
    fontSize: "11px"
    fontWeight: 400
    fontFeature: "tabular-nums on numeric readouts"
rounded:
  row: "6px"
  surface: "10px"
  panel: "14px"
spacing:
  xs: "4px"
  s: "8px"
  m: "12px"
  l: "16px"
  xl: "24px"
components:
  source-disc:
    backgroundColor: "{colors.window-background}"
    size: "48px"
    rounded: "24px"
  notice:
    rounded: "{rounded.surface}"
    padding: "12px"
  off-strip:
    rounded: "{rounded.panel}"
    padding: "16px"
  menu-row:
    rounded: "{rounded.row}"
    padding: "4px 8px"
  menu-bar-panel:
    width: "300px"
    padding: "16px"
---

# Design System: Anyspace

Plataforma: app nativo macOS 15+ em SwiftUI. Os tokens acima são valores SwiftUI/AppKit, não CSS. As cores são aproximações em hex dos estilos semânticos do sistema (o código nunca fixa hex); o valor real vem do sistema, do modo claro/escuro e da cor de destaque escolhida pela pessoa. Tamanhos em px equivalem a pontos.

## Overview

**Creative North Star: "A mesa de som nativa"**

O palco (mapa visto de cima) é o protagonista; tudo ao redor usa o vocabulário padrão do macOS: toolbar unificada, inspetor em Form agrupado, popover da barra de menu em estilo janela, folhas e alertas do sistema. A construção segue a direção: aparência premium porque é fiel ao sistema, não porque tem identidade própria (PRODUCT.md: "sem identidade visual definida"). Não há logotipo nem marca visual além do nome e dos SF Symbols.

Densidade média, calma: poucos controles por vez, estados explicados em texto e símbolo. Modo claro e escuro vêm de graça dos estilos semânticos.

**Key Characteristics:**
- Fontes do sistema (SF), sem fonte própria.
- Neutros do sistema; a cor de destaque do usuário só marca seleção, ação primária e nível.
- Verde, laranja e vermelho só para estado, sempre com símbolo.
- Cada fonte de som é o ícone real do app dentro de um disco com sombra suave.
- Profundidade por materiais (`.regularMaterial`) e sombras difusas, nunca bordas pesadas.

## Colors

Restrained: neutros do sistema mais um acento que pertence à pessoa.

### Primary
- **Acento do usuário** (`Color.accentColor`, padrão ~#007AFF): seleção (anel de 2,5 pt no disco, fundo da etiqueta e da linha a 16-18%), botão `.borderedProminent`, nível de áudio (anel ao redor do disco), cone de visão e marcador da cabeça, indicador do medidor de ângulo, ícones da boas-vindas, marca de verificação de perfil. Nunca fixar um azul próprio.

### Neutral
- **Fundo da janela** (`windowBackgroundColor`): fundo do palco; as etiquetas dos anéis usam a mesma cor para "cortar" a linha.
- **Primário / secundário** (`.primary`, `.secondary`): texto; anéis, eixos e marcas do palco são `.primary` com opacidade (vinheta 4,5%, eixos 6%, anéis 8%, anel de 4 m 16%, marcas de 30° 18%).
- **Quaternary / tertiary**: disco de símbolo substituto e trilho do medidor.
- **Separator** (`.separator`): contorno de avisos, faixa desligada e cápsulas sobre material.

### Estado (somente estado)
- **Verde** (`.green`): rastreio ativo, retângulo do rosto na janela de câmera.
- **Laranja** (`.orange`): aviso, rosto não encontrado, câmera pausada.
- **Vermelho** (`.red`): erro.

### Named Rules
**The Borrowed Accent Rule.** O acento é da pessoa. Nada usa um hex de marca; tudo referencia `accentColor` ou um estilo semântico.
**The Signal Only Rule.** Verde, laranja e vermelho nunca decoram; aparecem apenas junto de um símbolo que diz o estado (StatusLabel, aviso).

## Typography

**Fonte única:** SF Pro do sistema (SwiftUI padrão), sem família alternativa. Algarismos tabulares (`.monospacedDigit()`) em todo valor numérico que muda: ângulo, metros, porcentagem, contagem de acertos.

**Character:** a hierarquia vem do peso e dos estilos de texto do sistema, em volume baixo.

### Hierarchy
- **Title** (`.title.weight(.semibold)` na boas-vindas; `.title2.weight(.semibold)` no teste cego): título de folha.
- **Headline** (`.headline`): título de bloco (faixa "Efeito desligado", passos da boas-vindas, nome do app no painel, subtítulos de Perfis/Rede).
- **Body / callout** (`.body`, `.callout`): texto corrente e descrições; `.callout` em avisos e legendas secundárias.
- **Label** (11 pt fixo, `.regular`, 12 pt `.medium` nos pontos cardeais): rótulos do palco (metros, nome da fonte, Frente/Trás/Esquerda/Direita). Selecionado sobe para `.semibold`.
- **Caption** (`.caption`, `.caption2`): rodapés auxiliares e rótulos de seção do painel da barra de menu.

Fixos usados no código: 9 pt (seta da cabeça, ícone de mudo), 11, 12 e 52 pt (ícone da boas-vindas). A escala 11/13/15/20 da direção não foi implementada literalmente; vale o que está acima.

### Named Rules
**The System Type Rule.** Preferir estilos semânticos (`.headline`, `.callout`, `.caption`); tamanho fixo só dentro do palco, onde o texto acompanha geometria desenhada.
**The Tabular Rule.** Todo número que muda ao vivo usa `.monospacedDigit()`.

## Layout

Janela única unificada: palco à esquerda ocupa o que sobra; inspetor à direita com 340 pt ideal (min 300, max 440). Padrão de abertura 1080x700; mínimo 860x560. A janela de câmera abre 480x680 (mín 460x640). O painel da barra de menu tem 300 pt de largura e 16 pt de respiro. Folhas (boas-vindas e teste cego) têm 460 pt de largura.

Ritmo de espaçamento em múltiplos de 4 (enum `Space`): xs 4, s 8, m 12, l 16, xl 24. Folha de boas-vindas usa 36 (xl x 1,5). Usar sempre `Space`, exceto micro-ajustes de 2 pt entre linhas de texto.

Palco: o raio do mapa é calculado pela janela (mínimo 80 pt); reserva 108 pt embaixo fixos, para que ligar/desligar não mude o tamanho do mapa, e 64-84 pt em cima quando há aviso. "Frente" no topo; você no centro com cone de visão de 70° (150 pt).

### Named Rules
**The Fixed Floor Rule.** A faixa inferior do palco tem altura reservada; estado novo nunca desloca o mapa.

## Elevation & Depth

Híbrido discreto: planos e tonais por padrão, com sombra suave só em objetos que "flutuam" sobre o palco e material translúcido em superfícies sobrepostas.

### Shadow Vocabulary
- **Disco de fonte** (`.black` 22%, raio 6, y 2): o disco de 48 pt.
- **Marcador da cabeça** (`.black` 18%, raio 3, y 1).
- **Faixa desligada** (`.black` 10%, raio 10, y 3).
- **Material** (`.regularMaterial` com contorno `.separator`): aviso, faixa desligada, cápsula do ângulo, etiqueta de fonte não selecionada.

### Named Rules
**The Float Only Rule.** Sombra só em objetos que se movem ou sobrepõem o palco; linhas do mapa e linhas de lista ficam planas.

## Shapes

Cantos contínuos (`style: .continuous`) em tudo. Três raios: 6 pt (linhas selecionáveis, foco do palco, retângulo do rosto), 10 pt (`Space.radius`, avisos) e 14 pt (faixa desligada). Discos e cápsulas para fontes, etiquetas e cápsula de ângulo. O disco substituto de símbolo usa raio proporcional (24% do tamanho). A faixa de 14 pt e o raio de 6 pt estão no código fora de `Space`; são reais, mas ainda não nomeados lá.

## Components

### Disco de fonte (SourceDisc / SourceIconView)
Ícone real do app (NSWorkspace) dentro de um disco `.background` de 48 pt (ícone 36 pt) com sombra suave. Sem ícone real: símbolo SF em disco `.quaternary`. Selecionado: anel de acento de 2,5 pt a 52 pt e etiqueta em cápsula de acento com texto branco. Mudo: ícone em cinza a 55% e selo de alto-falante cortado. Anel de nível a 60 pt: opacidade e escala (até +25%) seguem o nível; com "reduzir movimento" só a opacidade muda.

### Palco (Grid2D, SpreadArc, HeadMarker)
Anéis finos de 1 a 4 m (1 pt), eixos, marcas a cada 30°, vinheta radial de 4,5%. Arco de abertura em traço de 1,5 pt com dois pontos (alto-falantes virtuais); acento quando selecionado. Cone da cabeça: gradiente do acento, 30% com rastreio ativo e 14% sem. Foco do teclado: contorno de 2 pt do acento a 60%.

### Faixa "desligado" (OffState)
Material com raio 14, até 560 pt, ancorada embaixo: título, explicação e o botão `.borderedProminent` grande "Ligar efeito espacial"; com permissão negada, "Abrir Ajustes…" prominent e "Tentar de novo". Fontes ficam a 50% de opacidade.

### Aviso
Material com raio 10 e contorno separator, ícone triângulo laranja, texto `.callout`, ações e botão de dispensar `.borderless`. Máximo 560 pt.

### StatusLabel
Símbolo SF colorido (verde, laranja, vermelho ou cinza) mais texto secundário, nunca só cor. Reutilizado no inspetor, painel da barra de menu e janela de câmera.

### MenuRow
Linha de menu de 4x8 pt, raio 6; hover e foco de teclado pintam o acento a 18%; marca de verificação em acento; atalho em secundário.

### Inspetor (Form agrupado)
`Form` com `.formStyle(.grouped)`: seções Fontes (lista com ícone 24 pt, mudo, adicionar), detalhe da fonte selecionada (volume, Direção e Distância com campo numérico e Stepper, remover), Cabeça, Som, e "Perfis e avançado" recolhido em DisclosureGroup. Rodapés explicativos por seção. Campos numéricos de 52 pt alinhados à direita são a alternativa ao arrasto do mapa.

### Painel da barra de menu
300 pt, `MenuBarExtra` em estilo janela: nome + estado + interruptor, aviso, StatusLabel, perfis (MenuRow), volumes por fonte (ícone 24, slider pequeno, mudo), Divider, Abrir (⌘O) e Sair (⌘Q). Ícone da barra: `waveform.circle(.fill)` ou triângulo de aviso.

### Folhas e janela de câmera
Boas-vindas: ícone 52 pt de acento, título, quatro passos (SF Symbol de acento + headline + callout), botão prominent padrão. Teste cego: ProgressView, "Tocar" prominent, três botões `.bordered` grandes, tabela de confusão com tabulares. Câmera: Form agrupado, visor 4:3 espelhado sobre preto, retângulo verde, AngleGauge (trilho quaternary, indicador de acento de 14 pt).

### Acessibilidade
Rótulos em pt-BR em todo controle só-ícone; disco de fonte com valor falado (direção, distância, volume, mudo) e ação ajustável (±5°); palco focável com setas (±5° e ±0,25 m); anel de foco visível; `accessibilityReduceMotion` respeitado no anel de nível e no giro da cabeça; ícones decorativos ocultos.

## Do's and Don'ts

### Do:
- **Do** usar controles padrão do macOS e estilos semânticos de cor e texto; manter claro e escuro automáticos.
- **Do** usar o acento do usuário apenas para seleção, ação primária e nível.
- **Do** mostrar cada estado com símbolo mais texto (StatusLabel), e dar alternativa por teclado e por campos numéricos a todo gesto de arrasto.
- **Do** usar o ícone real do app como identidade de uma fonte, com SF Symbol de substituição.
- **Do** respeitar `accessibilityReduceMotion` em qualquer animação nova.
- **Do** espaçar com `Space` (4/8/12/16/24).

### Don't:
- **Don't** fixar hex de marca nem uma segunda cor de destaque.
- **Don't** usar verde, laranja ou vermelho como decoração.
- **Don't** voltar ao painel único de formulário longo nem aos círculos coloridos com letra no lugar do ícone do app.
- **Don't** usar emoji ou glifos de texto no lugar de SF Symbols.
- **Don't** deixar um estado novo mover o mapa; reserve espaço fixo.
- **Don't** ancorar novas telas nos valores soltos de raio e fonte (14 pt, 9 pt, texto branco sobre acento a 90%) sem promovê-los antes ao sistema.

## Não verificado visualmente

O revisor não conseguiu capturar nem confirmar: o inspetor (lido só no código), a janela de câmera, o menu Perfis da toolbar, hover e foco reais (MenuRow, anel de foco do palco) e VoiceOver. As descrições desses itens vêm do código, não de captura.
