# Checklist de validação (para o Marco)

Comando base (fone conectado, tocando um vídeo ou música; o app encerra sozinho):

    cd ~/anyspace && ./scripts/build-app.sh
    open -n -W --stdout ~/anyspace/build/fase1.log build/AnyspaceCLI.app --args --angle 90 --seconds 20

## Fase 0: captura (validada em 2026-10-28)
- [x] Só o ouvido esquerdo tocou no modo de teste: o caminho funciona e o original é silenciado.
- [ ] Vídeo sem dessincronização perceptível (você disse que não notou).

## Fase 1: uma fonte no espaço (aguardando você)
Verificação offline já passou (`swift run anyspace-check`): a 90° o ouvido direito recebe 14 dB mais forte e ~0,73 ms antes; 1 m → 4 m cai 12 dB.

Para ouvir, troque o valor de `--angle`:
- [ ] `--angle 90`: o som vem da direita?
- [ ] `--angle -90`: vem da esquerda?
- [ ] `--angle 0`: vem da frente (ou "dentro da cabeça")? Anote como soa.
- [ ] `--angle 180`: vem de trás ou parece à frente? (confusão frente/trás é comum com HRTF genérico)
- [ ] `--angle 45 --distance 3`: parece mais longe e mais baixo que a 1 m?
- [ ] Qualidade: chiado, estalos, o som ficou abafado ou metálico demais?
- [ ] Atraso: o vídeo continua sincronizado?

## Fase 2: cabeça pela webcam (aguardando você)
Verificação offline já passou: com a cabeça virada 45° à direita a fonte da frente vai para o ouvido esquerdo (e vice-versa); fonte a 45° + cabeça 45° volta ao centro; filtro sem tremor, mantém o ângulo por 1,5 s se o rosto sumir e volta ao centro depois.

Comando (câmera do Mac; a primeira vez o macOS pede permissão de câmera, aceite e rode de novo):

    cd ~/anyspace && ./scripts/build-app.sh
    open -n -W --stdout ~/anyspace/build/fase2.log build/AnyspaceCLI.app --args --head --angle 0 --seconds 40
    # e em outro terminal: tail -f ~/anyspace/build/fase2.log

Nos 2 primeiros segundos olhe para a tela (calibra o centro). Depois:
- [ ] Vire a cabeça para a DIREITA: o log mostra "direita"? O som da frente vai para o ouvido ESQUERDO?
- [ ] Vire para a ESQUERDA: o log mostra "esquerda"? O som vai para o DIREITO?
- [ ] Se o sentido estiver ao contrário, rode de novo com `--invert` (e me avise).
- [ ] O som treme parado olhando para a tela? Quanto atrasa ao virar?
- [ ] "rosto em X de Y quadros": quantos quadros acham seu rosto (com boa luz deveria ser ~tudo)?
- [ ] Recalibrar: em outro terminal, `pkill -USR1 AnyspaceCLI`.
- [ ] Com a C922: adicione `--camera C922`.
- [ ] Rosto muito virado (>60°): o som mantém o último ângulo e depois volta ao centro?

## Fase 3 + 4: interface, mapa e conforto (aguardando você)
Agora há dois apps: `build/Anyspace.app` (interface) e `build/AnyspaceCLI.app` (testes por linha de comando, usado nas fases 0–2; os comandos acima foram atualizados). O app gráfico tem outro identificador, então o macOS pode pedir de novo as permissões de áudio e de câmera.

Verificação offline já passou (`swift run anyspace-check`): estéreo como dois alto-falantes virtuais (canal esquerdo soa no ouvido esquerdo, ~10 dB), cena JSON, conversão mapa↔ângulo, agrupamento de processos por app, fila circular.

Abrir: `open ~/anyspace/build/Anyspace.app` (começa com o efeito ligado; use `--args --no-start` para abrir sem ligar).

Interface e mapa
- [ ] A janela abre com o mapa à esquerda e os controles à direita? O ícone na barra de menu aparece?
- [ ] "Efeito espacial ligado" liga/desliga e o som do Mac volta ao normal ao desligar?
- [ ] "Adicionar app ao mapa": o app que está tocando aparece na lista (▶︎)? Ao adicionar, só o som dele vai para a bolinha?
- [ ] Arrastar a bolinha muda de onde o som vem em tempo real? Distância (mais longe = mais baixo)?
- [ ] Volume e mudo por fonte funcionam? Fechar e reabrir o app guarda as posições?
- [ ] Navegador (Chrome/Safari) como fonte: o som sai da bolinha do navegador e não do "Resto do sistema"?
- [ ] Quando um app novo começa a tocar depois de adicionado, ele é pego sozinho (pode levar até 2 s)?

Realismo
- [ ] Abertura do estéreo: com 0° a música fica "em um ponto" e com 30° mais larga? Qual você prefere?
- [ ] Reverberação: soa melhor ou mais "molhado" que o necessário? Ajuste a intensidade.
- [ ] Filtro de direção: compare HRTF alta qualidade, HRTF, cabeça esférica e só pan.
- [ ] Teste cego (12 rodadas, esquerda/frente/direita): quantos acertos com cada filtro? Anote aqui: ____

Cabeça e bateria
- [ ] "Acompanhar a cabeça": mesma checklist da fase 2, agora dentro da janela (o triângulo no mapa gira com a cabeça).
- [ ] Pausa o som por 10 s: a câmera desliga ("Câmera pausada: sem som tocando")? E volta quando o som volta?
- [ ] "Abrir ao iniciar o Mac" funciona? (pode falhar sem o app estar em /Applications; me conte a mensagem)
