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
