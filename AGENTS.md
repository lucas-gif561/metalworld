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
   - `jogador.acao("atacar")`, que devolve `"p1_atacar"` ou `"p2_atacar"`;
   - `Controles.acao(id_jogador, "atacar")`.
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
   | `atacar` (socos alternados: esquerdo, direito...) | J | X |
   | `dodge` | K | A / RB |
   | `interagir` (portal, levantar parceiro) | E | B |
   | `riff_mode` | Espaço | LB |
   | `riff_esquerda` / `riff_cima` / `riff_baixo` / `riff_direita` (pistas ← ↑ ↓ →) | Setas | X / Y / A / B ou direcional |
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
- **Barris e caixotes:** instancie `scenes/objects/barril.tscn` ou `caixote.tscn` na cena. Eles quebram na porrada e soltam comida que cura. Para trocar a comida, mude `cena_item` no Inspector: use `item_maca.tscn`, `item_carne.tscn` ou uma cena nova com `scripts/objects/item_vida.gd`.
- **Fundo:** troque a textura do nó `Background`.
- **Não precisa de script novo para a fase:** ela usa `scripts/main.gd`.

### Criar um inimigo novo

1. Crie uma **cena herdada** de `res://scenes/enemies/inimigo.tscn` (no editor: Cena → Nova Cena Herdada) e salve em `fases/rua_N/inimigos/`.
2. Crie um script com `extends Inimigo` e sobrescreva **só** `_comportamento(delta)`. O alvo já está em `jogador`, o vivo mais próximo, atualizado sozinho. Exemplos: `scripts/enemies/inimigo_atirador.gd` e `inimigo_tanque.gd`.
3. Use as funções prontas: `_olhar_para_jogador()`, `_atualizar_animacao()`, `_tocar_acao("attack")`, `move_and_slide()`.
4. **Ataque justo:** antes de bater ou atirar, chame `carregar_ataque(minha_funcao)`. O inimigo congela piscando branco por `tempo_preparo` e só depois chama a função. Assim o jogador vê o golpe vindo e pode sair da faixa ou socar para cancelar. Dentro da função, dê o dano com `jogador.receber_dano(dano)` ou crie um projétil cuja colisão chame `receber_dano` em quem estiver no grupo `"jogador"`.
   - O jogador ataca **corpo a corpo**: só acerta quem está à frente e na mesma faixa da rua. Inimigos que precisam apanhar ficam no grupo `"alvos_golpe"`, o que o `Inimigo` já faz sozinho. Com `empurrar(forca)` o soco empurra, e `resistencia_empurrao` deixa o inimigo mais pesado.
5. Ao morrer, o inimigo emite `morreu(inimigo)` e some sozinho. Não chame `queue_free()` antes.
6. Som e impacto já vêm prontos no `Inimigo`: tremor e pausa curta ao apanhar e ao morrer, ajustáveis no grupo "Impacto" do Inspector. Para efeitos extras, use `Audio.tocar("nome")` (lista em `scripts/systems/audio.gd`) e `Combate.tremer(forca)` / `Combate.pausar(segundos)`.

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
- Para o boss atirar, use `criar_projetil(direcao)`, que usa a cena `cena_projetil`. Também aceita outra cena como segundo argumento. Para um círculo de dano no chão, use `criar_circulo(posicao, dano, tempo_aviso)`.
- **Caixa de ferramentas:** a classe `Boss` já tem ataques e mecânicas prontos. Use só os que quiser, sempre com `await`:

  | Função | O que faz | Precisa de |
  |---|---|---|
  | `rajada()` | 6 tiros mirados | `cena_projetil` |
  | `leque()` | leque de 5 tiros | `cena_projetil` |
  | `espiral()` | dois fios de tiros girando | `cena_projetil` |
  | `area_no_chao()` | círculo grande embaixo de um jogador | `cena_ataque_area` |
  | `trilha_no_chao()` | rastro de círculos seguindo um jogador | `cena_ataque_area` |
  | `corredor()` | colunas de círculos varrendo a arena, com um buraco | `cena_ataque_area` |
  | `invocar_capangas()` | chama inimigos nos `pontos_capanga` | `cena_capanga` |
  | `teleporte()` | some e reaparece num dos `pontos_teleporte` | `cena_particulas` (opcional) |
  | `ativar_escudo()` | o Riff não fere até quebrarem as runas no soco | `cena_runa` |
  | `descansar()` | o boss se ajoelha e mostra "RIFF!": a hora de tocar | animações `ajoelhar`/`descanso` (opcional) |

  As cenas prontas são `scenes/projectiles/ProjetilBoss.tscn`, `ataqueAreaBoss.tscn`, `particulas_boss.tscn`, `scenes/bosses/runa.tscn` e qualquer inimigo de `scenes/enemies/`.
- **Fases** (`usar_fases` no Inspector): abaixo de 66% e de 33% da vida o boss enfurece, e `esperar_no_ritmo()` encurta as pausas. Ao mudar de fase, o Riff fecha e o escudo sobe (`escudo_ao_mudar_fase`). Com fases, o dano das notas é calibrado para um Riff bom valer uma fase. Para saber em que fase está, use `if fase >= 2:`.
- **Nota maldita** (`usar_nota_maldita`, a partir de `fase_nota_maldita`): nota vermelha que machuca quem toca.
- **Cabo de força** (`usar_cabo_de_forca` no nó raiz da arena, ligado por padrão): a dupla divide uma vida contra o boss. Dano em qualquer jogador enche o boss, e dano no boss enche a dupla.
- Exemplo com tudo isso junto: `scripts/bosses/boss.gd` (boss 1) e as propriedades do nó `Arena/Boss` em `scenes/main/Bossfight.tscn`.
- O boss **só perde vida pelo Riff**. Não dê dano no boss por soco.
- Para ajustar o Riff de um boss, selecione o nó `HUD/RiffHUD` da arena e mude no Inspector `bpm` (150 por padrão, no tempo da música), `chance_nota_maldita`, `dano_perfect` e `dano_good`. Os danos só valem para boss sem fases.
- Durante o Riff, qualquer botão que não seja de nota fecha o modo. Isso é de propósito: dá tempo de reagir.
- A vida fica em `vida_maxima`, no nó raiz do `chefe_N.tscn`.
- Exemplo completo: `scripts/bosses/boss.gd` (boss 1).

---

## 5. Sprites

Os sprites finais são feitos pelo responsável pela base. Até lá, use **arte provisória**: um sprite existente com outra cor, ou um retângulo. Para a troca depois ser só arrastar a folha nova, siga este padrão:

- Folha **horizontal**, quadros do mesmo tamanho, fundo transparente, personagem **virado para a direita**, pés sempre na mesma linha.
- Animações com estes nomes exatos no `SpriteFrames`:
  - **Inimigo:** `idle`, `walk`, `attack`, `hurt`, `death`. `attack`, `hurt` e `death` sem loop. O 1º quadro do `attack` é a pose de carga (fica congelado enquanto pisca).
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
