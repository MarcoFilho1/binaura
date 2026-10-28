# Checklist de validação (para o Marco)

Comando base (fone conectado, tocando um vídeo ou música; o app encerra sozinho):

    cd ~/anyspace && ./scripts/build-app.sh
    open -n -W --stdout ~/anyspace/build/fase1.log build/BinauraCLI.app --args --angle 90 --seconds 20

## Fase 0: captura (validada em 2026-10-28)
- [x] Só o ouvido esquerdo tocou no modo de teste: o caminho funciona e o original é silenciado.
- [ ] Vídeo sem dessincronização perceptível (você disse que não notou).

## Fase 1: uma fonte no espaço (aguardando você)
Verificação offline já passou (`swift run binaura-check`): a 90° o ouvido direito recebe 14 dB mais forte e ~0,73 ms antes; 1 m → 4 m cai 12 dB.

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
    open -n -W --stdout ~/anyspace/build/fase2.log build/BinauraCLI.app --args --head --angle 0 --seconds 40
    # e em outro terminal: tail -f ~/anyspace/build/fase2.log

Nos 2 primeiros segundos olhe para a tela (calibra o centro). Depois:
- [ ] Vire a cabeça para a DIREITA: o log mostra "direita"? O som da frente vai para o ouvido ESQUERDO?
- [ ] Vire para a ESQUERDA: o log mostra "esquerda"? O som vai para o DIREITO?
- [ ] Se o sentido estiver ao contrário, rode de novo com `--invert` (e me avise).
- [ ] O som treme parado olhando para a tela? Quanto atrasa ao virar?
- [ ] "rosto em X de Y quadros": quantos quadros acham seu rosto (com boa luz deveria ser ~tudo)?
- [ ] Recalibrar: em outro terminal, `pkill -USR1 BinauraCLI`.
- [ ] Com a C922: adicione `--camera C922`.
- [ ] Rosto muito virado (>60°): o som mantém o último ângulo e depois volta ao centro?

## Fase 3 + 4: interface, mapa e conforto (aguardando você)
Agora há dois apps: `build/Binaura.app` (interface) e `build/BinauraCLI.app` (testes por linha de comando, usado nas fases 0–2; os comandos acima foram atualizados). O app gráfico tem outro identificador, então o macOS pode pedir de novo as permissões de áudio e de câmera.

Verificação offline já passou (`swift run binaura-check`): estéreo como dois alto-falantes virtuais (canal esquerdo soa no ouvido esquerdo, ~10 dB), cena JSON, conversão mapa↔ângulo, agrupamento de processos por app, fila circular.

Abrir: `open ~/anyspace/build/Binaura.app` (começa com o efeito ligado; use `--args --no-start` para abrir sem ligar).

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

## Fase 5: áudio de outro dispositivo (versão mínima, aguardando você)
Verificação offline já passou em loopback (pacote, senha errada rejeitada, áudio chega igual). Não testado entre dois aparelhos reais.
- [ ] No app: defina uma senha, porta 5004, "Receber áudio nessa porta". Uma bolinha "Rede 5004" aparece no mapa.
- [ ] Em outro Mac (ou neste, em outro terminal): `build/BinauraCLI.app/Contents/MacOS/BinauraCLI --send IP:5004 --password SENHA`. O som do outro Mac sai na bolinha?
- [ ] Atraso e falhas na sua rede Wi-Fi? (PCM sem compressão ≈ 1,5 Mbit/s)
- [ ] Windows/Android ainda não têm remetente; o formato do pacote está em `NetworkAudio.swift`.

## Perfis (aguardando você)
Verificação offline já passou: salvar, aplicar, substituir, apagar, guardar em disco, e abrir arquivos de versões antigas sem perder a cena.
- [ ] Arrume o mapa (posições, volume, abertura), escreva "Trabalho" e clique em "Salvar atual".
- [ ] Mude tudo, crie "Filme" com outro arranjo e use "Aplicar perfil": as posições voltam exatamente?
- [ ] O menu da barra de menu lista os perfis e troca de perfil?
- [ ] Feche com Cmd+Q e reabra: os perfis continuam lá?

## Interface nativa nova (aguardando você)
Rode: `pkill -x Binaura; sleep 1; open ~/anyspace/build/Binaura.app`. Na primeira vez as boas-vindas aparecem e o efeito só liga em "Ligar e começar". Para vê-las de novo: `defaults delete dev.marco.binaura didSeeWelcome`.

O revisor independente conferiu o palco, o painel da barra de menu, as boas-vindas, o teste cego e o estado desligado/erro por captura. **O inspetor, a janela de câmera e o menu Perfis não puderam ser capturados** (formulários com rolagem), então confira estes com os seus olhos:
- [ ] Inspetor: com 1 app e com 6+ apps, a lista de fontes não colapsa nem tem rolagem estranha, e o detalhe da fonte selecionada fica visível?
- [ ] "Direção" e "Distância": digitar e usar o Stepper move a bolinha no palco?
- [ ] Modo escuro com a janela ativa: o interruptor e os botões da toolbar mostram os símbolos (e não pílulas brancas vazias)?
- [ ] Setas do teclado movem a fonte selecionada; aparece o contorno de foco do palco?
- [ ] Janela de câmera: retângulo do rosto, medidor, e a mensagem de erro se a permissão da câmera for negada.
- [ ] Barra de menu: trocar de perfil, volume por fonte, "Dispensar" no aviso.
- [ ] VoiceOver: as bolinhas do mapa leem nome, direção e distância?
- [ ] Com "Reduzir movimento" ligado nos Ajustes do Sistema, o anel de nível continua visível (só muda de opacidade)?
