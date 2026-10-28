---
version: 1
slug: "sources-binauraapp"
primary_target: "Sources/BinauraApp"
related_targets: []
---

# Surface brief: Binaura (janela principal, barra de menu, debug da câmera, teste cego)

Modo: Operate. App nativo macOS em SwiftUI. Direção fixada pelo usuário: aparência premium e totalmente nativa do macOS (a direção do brief vence o sorteio; nenhuma rolagem de mundos foi feita).

Audiência/tarefa: quem tem fone comum e quer áudio espacial. Dia a dia pela barra de menu (ligar, trocar perfil, volume); a janela é a oficina (mapa, câmera, som). Vai ser distribuído: primeira execução precisa ensinar permissões e estados.

Estados que a interface deve mostrar: desligado, ligado, câmera pausada sem som, rosto não encontrado, permissão negada, saída trocada, fonte muda, fonte tocando (nível).

Constraints: sem emoji nem glifos no lugar de ícones (SF Symbols); controles padrão do macOS; modo claro e escuro; reduzir movimento; alternativa por teclado e por campos numéricos para o mapa arrastável; pt-BR.

## Direction contract

THESIS: o app é uma mesa de som nativa: o palco (mapa) é o protagonista e tudo ao redor usa o vocabulário do macOS (toolbar unificada, inspetor em Form agrupado, popover da barra de menu). Recusa o painel único de formulário longo e os círculos coloridos com letra.

OWN-WORLD: fontes do sistema (SF) em escala 11/13/15/20 com algarismos tabulares; cor Restrained: neutros do sistema + a cor de destaque do usuário só para seleção, ação primária e nível; verde/laranja/vermelho só para estado. Cada fonte é o ícone real do app dentro de um disco com sombra suave; anéis finos em quaternary; cone de visão da cabeça em gradiente discreto da cor de destaque.

STORY: a pessoa liga, vê onde cada app está ao seu redor, arrasta ou digita para mudar, e percebe que o som segue a cabeça. Na barra de menu, resolve tudo sem abrir janela.

FIRST VIEWPORT: janela unificada 1040x680. Esquerda: palco com anéis de 1 a 4 m, "Frente" no topo, ícones dos apps, você no centro com cone de visão. Direita: inspetor 340 pt com Fontes (lista + detalhe da selecionada), Cabeça, Som, Rede recolhida. Toolbar: interruptor do efeito, menu de Perfis, alternar inspetor. Sem efeito: palco esmaecido com chamada "Ligar efeito espacial".

FORM: padrão macOS (toolbar unificada + inspector + Form agrupado + MenuBarExtra em estilo janela), posição: direção fixada pelo usuário, seed: none (unavailable)

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
