# MetalWorld — regras para agentes (Codex, Claude etc.)

Jogo em **Godot 4.7 / GDScript**. Beat 'em up com co-op local de 2 jogadores, em que cada rua leva a um boss que só toma dano pelo **Riff**, um minigame de ritmo. O Riff é o diferencial do jogo e precisa existir nos três bosses.

**MVP (entrega 23/11):** Rua 1 → Boss 1 → Rua 2 → Boss 2 → Rua 3 → Boss 3. A sequência fica em `scripts/systems/jogo.gd` (`FASES`).

Código, comentários, nomes de nós e textos do jogo são em **português**. Siga o estilo dos arquivos existentes: tabs, `snake_case` e funções privadas com `_`.

---

## 1. Quem mexe em quê

| Pasta | Dono | O que tem |
|---|---|---|
| `fases/rua_2/`, `fases/rua_3/` | Colega das ruas | Cena da rua, inimigos novos, scripts e sprites dessas fases |
| `fases/boss_2/`, `fases/boss_3/` | Colega dos bosses | Arena, boss, ataques, projéteis e sprites desses bosses |
| Todo o resto | Responsável pela base | Jogador, HUD, Riff, controles, fluxo de fases, ruas e boss 1 |

**Regra de ouro:** só crie e edite arquivos **dentro da pasta da sua fase**. Precisa de algo fora dela, como um bug no jogador, uma função nova no `Boss` ou uma ação nova de controle? Não edite. Descreva o pedido no PR ou avise o responsável pela base.

Arquivos que **nunca** devem ser editados num PR de fase:
- `project.godot`: comandos, autoloads e configurações;
- `scenes/player/*`, `scripts/player/*`;
- `scripts/systems/*` (`jogo.gd`, `controles.gd`, `enemy_manager.gd`, `ponto_spawn.gd`);
- `scripts/enemies/inimigo.gd`, `scripts/bosses/boss_base.gd`, `scripts/bosses/BossFight.gd`;
- `scenes/ui/*`, `scripts/ui/*`, `scripts/objects/riffHUD.gd`, `scripts/objects/notaRiff.gd`;
- `scenes/main/*` (rua 1 e boss 1 são o exemplo; copie, não altere);
- `tests/*`, exceto para criar um teste novo da sua fase, como `tests/teste_rua_2.gd`.

Não mova nem renomeie arquivos existentes.

---

## 2. Co-op: o que todo código precisa respeitar

O jogo tem **1 ou 2 jogadores**, e o P2 pode entrar no meio da fase. Por isso:

1. **Nunca leia `Input` com o nome cru da ação.** Use:
   - `jogador.acao("atirar")`, que devolve `"p1_atirar"` ou `"p2_atirar"`;
   - `Controles.acao(id_jogador, "atirar")`.
   - Exemplo: `Input.is_action_just_pressed(jogador.acao("interagir"))`.
2. **Nunca guarde "o jogador" numa variável fixa** (`get_first_node_in_group("jogador")`, `$Player` etc.). Pergunte ao autoload `Jogo` na hora:
   - `Jogo.jogador_mais_proximo(posicao)` devolve o jogador vivo mais perto, ou `null`;
   - `Jogo.jogador_aleatorio()` devolve um jogador vivo sorteado, ou `null`;
   - `Jogo.jogadores_vivos()`, `Jogo.jogadores` e `Jogo.todos_caidos()` dão a lista e o estado dos jogadores.
3. **Sempre trate `null`**: se todos caírem, não há alvo.
4. Jogador com vida zero fica **caído** (`jogador.caido == true`), não some da cena. O parceiro pode levantá-lo.
5. Não crie ações novas no Mapa de Entrada. As ações existentes são:

   | Ação | P1 (teclado) | P2 (controle) |
   |---|---|---|
   | `mover_cima` / `mover_baixo` / `mover_esquerda` / `mover_direita` | WASD | analógico e direcional |
   | `atirar` | J | X |
   | `dodge` | K | A / RB |
   | `interagir` (portal, levantar parceiro) | E | B |
   | `riff_mode` | Espaço | LB |
   | `riff_cima` / `riff_baixo` / `riff_esquerda` / `riff_direita` | Setas | Y / A / X / B ou direcional |
   | `reiniciar` | R | Start |
   | `entrar` (P2 entra na partida) | — | Start / A |

   Sem controle, o P2 tem um teclado reserva para testes: setas, Ctrl direito, Shift direito, Enter e Backspace.

---

## 3. Criar uma rua (fases/rua_N)

A cena `fases/rua_N/rua_N.tscn` já funciona: tem 2 arenas, inimigos e um portal no fim.

- **Ondas:** dentro de `Spawns/ArenaX/OndaY`, adicione nós `PontoSpawn` (Marker2D). No Inspector, escolha a `cena_inimigo`.
  - Cada `ArenaX` é uma tela; a câmera anda quando a arena é limpa.
  - Cada `OndaY` só começa quando a anterior morre.
  - A quantidade de arenas e ondas sai da própria árvore, sem código.
  - Cada arena tem 1032 px de largura: a arena 1 é centrada em x=576, a 2 em x=1608, a 3 em x=2640 (a anterior + 1032).
  - Inimigos podem nascer fora da tela, um pouco à direita ou à esquerda.
- **Portal:** coloque o nó `Portal` dentro da última arena. Ele leva sozinho para a próxima fase.
- **Fundo:** troque a textura do nó `Background`.
- **Não precisa de script novo para a fase:** ela usa `scripts/main.gd`.

### Criar um inimigo novo

1. Crie uma **cena herdada** de `res://scenes/enemies/inimigo.tscn` (no editor: Cena → Nova Cena Herdada) e salve em `fases/rua_N/inimigos/`.
2. Crie um script com `extends Inimigo` e sobrescreva **só** `_comportamento(delta)`. O alvo já está em `jogador`, o vivo mais próximo, atualizado sozinho. Exemplos: `scripts/enemies/inimigo_atirador.gd` e `inimigo_tanque.gd`.
3. Use as funções prontas: `_olhar_para_jogador()`, `_atualizar_animacao()`, `_tocar_acao("attack")`, `move_and_slide()`.
4. Para dar dano no jogador, chame `jogador.receber_dano(dano)` ou crie um projétil cuja colisão chame `receber_dano` em quem estiver no grupo `"jogador"`.
5. Ao morrer, o inimigo emite `morreu(inimigo)` e some sozinho. Não chame `queue_free()` antes.

---

## 4. Criar um boss (fases/boss_N)

A cena `fases/boss_N/boss_N.tscn` já funciona: arena, Riff, barra de vida e vitória. O boss fica em `fases/boss_N/chefe_N.tscn` e `chefe_N.gd`.

- O script do boss faz `extends Boss` (`scripts/bosses/boss_base.gd`) e sobrescreve `ciclo_ataques()`:
  ```gdscript
  func ciclo_ataques():
  	await esperar(2.0)
  	while pode_atacar():
  		meu_ataque()
  		await esperar(1.5)
  ```
- **Sempre** use `esperar()` e `esperar_fim_do_ataque()`, nunca `get_tree().create_timer` direto. Elas não quebram quando a fase reinicia no meio do ataque.
- Para mirar, use `alvo()` (jogador sorteado) ou `alvo_mais_proximo()`. Ambos podem devolver `null`.
- Para atirar, use `criar_projetil(direcao)`, que usa a cena `cena_projetil`. Também aceita outra cena como segundo argumento.
- O boss **só perde vida pelo Riff**. Não dê dano no boss por tiro.
- Para ajustar o Riff de um boss, selecione o nó `HUD/RiffHUD` da arena e mude `bpm`, `dano_perfect` e `dano_good` no Inspector.
- A vida fica em `vida_maxima`, no nó raiz do `chefe_N.tscn`.
- Exemplo completo: `scripts/bosses/boss.gd` (boss 1).

---

## 5. Sprites

Os sprites finais são feitos pelo responsável pela base. Até lá, use **arte provisória**: um sprite existente com outra cor, ou um retângulo. Para a troca depois ser só arrastar a folha nova, siga este padrão:

- Folha **horizontal**, quadros do mesmo tamanho, fundo transparente, personagem **virado para a direita**, pés sempre na mesma linha.
- Animações com estes nomes exatos no `SpriteFrames`:
  - **Inimigo:** `idle`, `walk`, `attack`, `hurt`, `death`. `attack`, `hurt` e `death` sem loop.
  - **Boss:** `idle`, `cast`, `hurt`, `death`.
- Guarde em `fases/<sua_fase>/sprites/`.

---

## 6. Antes de abrir um PR

1. Abra o projeto no Godot e jogue a sua fase até o fim, sozinho **e** com 2 jogadores. Sem controle, use o teclado reserva do P2.
2. Rode os testes: `tests/rodar_testes.sh`, ou `GODOT=/caminho/do/godot tests/rodar_testes.sh`. Precisa terminar com `TUDO CERTO`.
3. Confira que o PR só mexe na pasta da sua fase.
4. PRs **pequenos e frequentes**, a cada 2–3 dias. Não junte uma semana de trabalho num PR só.

## 7. Armadilhas conhecidas do Godot

- Prefira editar cenas (`.tscn`) **pelo editor**. Se editar como texto, não invente `uid="uid://..."`: deixe só o `path`, e o Godot gera o resto.
- Em cena herdada, a linha `script = ...` vem **antes** das propriedades exportadas, senão os valores se perdem.
- Não deixe o editor do Godot aberto enquanto troca de branch no git, porque ele pode sobrescrever cenas com a versão antiga. Feche, troque e reabra.
- Testes rodam sem janela (`--headless`). Nesse modo a tela tem outro tamanho, então limites verticais podem diferir da janela normal.
