# Checklist de validação (para o Marco)

Comando base (fone conectado, tocando um vídeo ou música; o app encerra sozinho):

    cd ~/anyspace && ./scripts/build-app.sh
    open -n -W --stdout ~/anyspace/build/fase1.log build/Anyspace.app --args --angle 90 --seconds 20

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
    open -n -W --stdout ~/anyspace/build/fase2.log build/Anyspace.app --args --head --angle 0 --seconds 40
    # e em outro terminal: tail -f ~/anyspace/build/fase2.log

Nos 2 primeiros segundos olhe para a tela (calibra o centro). Depois:
- [ ] Vire a cabeça para a DIREITA: o log mostra "direita"? O som da frente vai para o ouvido ESQUERDO?
- [ ] Vire para a ESQUERDA: o log mostra "esquerda"? O som vai para o DIREITO?
- [ ] Se o sentido estiver ao contrário, rode de novo com `--invert` (e me avise).
- [ ] O som treme parado olhando para a tela? Quanto atrasa ao virar?
- [ ] "rosto em X de Y quadros": quantos quadros acham seu rosto (com boa luz deveria ser ~tudo)?
- [ ] Recalibrar: em outro terminal, `pkill -USR1 anyspace`.
- [ ] Com a C922: adicione `--camera C922`.
- [ ] Rosto muito virado (>60°): o som mantém o último ângulo e depois volta ao centro?
