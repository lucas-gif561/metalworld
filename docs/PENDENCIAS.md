# Pendências

Tudo está no Trello (quadro MetalWorld). Arte fica no checklist do card [Sprites](https://trello.com/c/iAyo2Pmc); código tem card próprio em 🎮 To do.

## Sprites (checklist do card Sprites)

- [ ] Atualizar o sprite do Dylan chutando (`personagens/dylan/sprites/chute.png`).
- [ ] Atualizar o sprite do homem com garrafa (o `corredor` da rua 1) atacando (`fases/rua_1/sprites/corredor/attack.png`).
- [ ] Atualizar o sprite do cara com arma (`inimigos/atirador/`): usar um quadro da animação de atirar como pose de carga ("wind up") e sincronizar o tiro com a animação.
- [x] Criar o sprite do boss 1 (`fases/boss_1/`).
- [x] Criar o cenário do boss 1 (`fases/boss_1/boss_1.tscn`).

## Fluxo de fases

- [ ] Se os jogadores morrerem num boss, voltar para a rua anterior: boss 1 → rua 1, boss 2 → rua 2, boss 3 → rua 3 (`sistemas/jogo.gd`). [Trello](https://trello.com/c/QVUBoPC1)

## Riff e boss

- [ ] Tempo de folga (~2 s) sem ataques do boss quando ele volta do descanso ou muda de fase (`bosses/base/boss_base.gd`). [Trello](https://trello.com/c/cvZry7dy)
- [ ] Na troca de fase, em vez de um escudo no boss, o equipamento de som dos jogadores trava e eles não conseguem abrir o Riff (`ativar_escudo` / `escudo_ao_mudar_fase` em `bosses/base/boss_base.gd`). [Trello](https://trello.com/c/Pp0WMOSR)

## Controles

- [ ] Permitir que o player 1 também jogue pelo controle. [Trello](https://trello.com/c/rJctCSuV)
