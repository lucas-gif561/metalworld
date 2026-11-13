# MetalWorld — regras para agentes (Codex, Claude etc.)

Jogo em **Godot 4.7 / GDScript**. Beat 'em up com co-op local de 2 jogadores, em que cada rua leva a um boss que só toma dano pelo **Riff**, um minigame de ritmo. O Riff é o diferencial do jogo e precisa existir nos três bosses.

**MVP (entrega 23/11):** Rua 1 → Boss 1 → Rua 2 → Boss 2 → Rua 3 → Boss 3. A sequência fica em `sistemas/jogo.gd` (`FASES`).

Código, comentários, nomes de nós e textos do jogo são em **português**. Siga o estilo dos arquivos existentes: tabs, `snake_case` e funções privadas com `_`.

**Visual e tamanho vão na cena, não no código.** Escala, posição, hitbox, cores e textos fixos são gravados no `.tscn` pelo Inspector, para o editor mostrar exatamente o que roda no jogo e qualquer pessoa achar e mudar sem ler código. Só use código para o que muda durante a partida, como a cor do P2 ou o tamanho 1,5x nas ruas, e deixe um comentário explicando por quê.

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
- `sistemas/*`: autoloads `Jogo`, `Controles`, `Audio` e `Combate`;
- `personagens/*`: o Dylan;
- `inimigos/base/*`, `bosses/base/*`, `fases/comum/*`: os modelos que todo mundo usa;
- `riff/*`, `ui/*`, `objetos/*`;
- `fases/rua_1/*`, `fases/boss_1/*` (rua 1 e boss 1 são o exemplo; copie, não altere);
- `tests/*`, exceto para criar um teste novo da sua fase, como `tests/teste_rua_2.gd`.

Não mova nem renomeie arquivos existentes.

### Estrutura de pastas

Organização **por funcionalidade**, como recomenda o guia oficial do Godot: cena, script e sprites de cada coisa ficam juntos na mesma pasta. Nomes de pastas e arquivos em `snake_case`; nós das cenas em `PascalCase`.

| Pasta | O que tem |
|---|---|
| `sistemas/` | Autoloads: `jogo.gd`, `controles.gd`, `audio.gd`, `combate.gd` |
| `personagens/dylan/` | `jogador.tscn` e `jogador.gd`, marcadores (anel, reviver), shader do P2, `sprites/` |
| `inimigos/base/` | `inimigo.tscn` e `inimigo.gd`: o modelo que todo inimigo herda |
| `inimigos/rapido/`, `atirador/`, `tanque/` | Cena, script, sprites e projétil de cada inimigo |
| `bosses/base/` | `boss_base.gd` (classe `Boss`), `arena_boss.gd`, runa, círculo no chão, projétil e partículas |
| `riff/` | HUD do Riff, nota e sprites das teclas |
| `objetos/` | Barril, caixote, comida, portal e `sprites/` |
| `ui/` | HUD, tela inicial, cabo de força |
| `fases/comum/` | `fase_rua.gd` (script de toda rua), `gerenciador_ondas.gd`, `ponto_spawn.gd` |
| `fases/rua_N/`, `fases/boss_N/` | Uma pasta por fase. A do boss traz a arena (`boss_N.tscn`) e o chefe (`chefe_N.tscn`/`.gd`) |
| `assets/` | Só o que é compartilhado: `audio/`, `fundos/`, `efeitos/`, `projeteis/` |
| `tests/`, `docs/` | Testes automáticos e guias |

Inimigos, objetos e sprites novos de uma fase ficam **dentro da pasta da fase**, como `fases/rua_2/inimigos/motoqueiro/`.

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
- **Barris e caixotes:** instancie `objetos/barril.tscn` ou `caixote.tscn` na cena. Eles quebram na porrada e soltam comida que cura. Para trocar a comida, mude `cena_item` no Inspector: use `item_maca.tscn`, `item_carne.tscn` ou uma cena nova com `objetos/item_vida.gd`.
- **Fundo:** troque a textura do nó `Background`.
- **Não precisa de script novo para a fase:** ela usa `fases/comum/fase_rua.gd`.

### Criar um inimigo novo

1. Crie uma **cena herdada** de `res://inimigos/base/inimigo.tscn` (no editor: Cena → Nova Cena Herdada) e salve em `fases/rua_N/inimigos/`.
2. **Inimigo que só bate de perto:** não precisa de script. A cena herdada já vem com a **IA de grupo** (estilo Castle Crashers): cada jogador tem 2 vagas de ataque, uma de cada lado; quem pega a vaga chega na mesma faixa, bate `ataques_por_vez` vezes, recua e dá a vez, e os outros rodeiam a uns `raio_espera` px, divididos entre os dois lados. Troque os sprites e ajuste no Inspector a vida, a velocidade, o dano e o grupo "IA de grupo".
3. **Inimigo com comportamento diferente** (atira, pula, investe): crie um script com `extends Inimigo` e sobrescreva **só** `_comportamento(delta)`. Isso substitui a IA de grupo por completo. O alvo já está em `jogador`, o vivo mais próximo, atualizado sozinho. Use as funções prontas: `_olhar_para_jogador()`, `_atualizar_animacao()`, `_tocar_acao("attack")`, `move_and_slide()`. Exemplos: `inimigos/atirador/inimigo_atirador.gd` e `inimigo_tanque.gd`.
4. **Ataque justo** (no script próprio; a IA de grupo já faz isso): antes de bater ou atirar, chame `carregar_ataque(minha_funcao)`. O inimigo congela piscando branco por `tempo_preparo` e só depois chama a função. Assim o jogador vê o golpe vindo e pode sair da faixa ou socar para cancelar. Dentro da função, dê o dano com `jogador.receber_dano(dano)` ou crie um projétil. O projétil precisa acertar a **Hurtbox** do jogador: `collision_mask = 16`, `area_entered`, conferir `area.is_in_group("hurtbox_jogador")` e chamar `area.get_parent().receber_dano(dano)`. Ele também deve nascer na altura do peito de quem atira. Copie `inimigos/atirador/projetil_inimigo.tscn` e `.gd` como ponto de partida, e veja a seção 7.
   - O jogador ataca **corpo a corpo**: só acerta quem está à frente e na mesma faixa da rua. Inimigos que precisam apanhar ficam no grupo `"alvos_golpe"`, o que o `Inimigo` já faz sozinho. Com `empurrar(forca)` o soco empurra, e `resistencia_empurrao` deixa o inimigo mais pesado.
5. Ao morrer, o inimigo emite `morreu(inimigo)` e some sozinho. Não chame `queue_free()` antes.
6. Som e impacto já vêm prontos no `Inimigo`: tremor e pausa curta ao apanhar e ao morrer, ajustáveis no grupo "Impacto" do Inspector. Para efeitos extras, use `Audio.tocar("nome")` (lista em `sistemas/audio.gd`) e `Combate.tremer(forca)` / `Combate.pausar(segundos)`.

---

## 4. Criar um boss (fases/boss_N)

A cena `fases/boss_N/boss_N.tscn` já funciona: arena, Riff, barra de vida e vitória. O boss fica em `fases/boss_N/chefe_N.tscn` e `chefe_N.gd`.

- O script do boss faz `extends Boss` (`bosses/base/boss_base.gd`) e sobrescreve `ciclo_ataques()`:
  ```gdscript
  func ciclo_ataques():
  	await esperar(2.0)
  	while pode_atacar():
  		meu_ataque()
  		await esperar(1.5)
  ```
- **Sempre** use `esperar()` e `esperar_fim_do_ataque()`, nunca `get_tree().create_timer` direto. Elas não quebram quando a fase reinicia no meio do ataque.
- Para mirar, use `alvo()` (jogador sorteado) ou `alvo_mais_proximo()`. Ambos podem devolver `null`.
- Para o boss atirar, use `criar_projetil(direcao)`, que usa a cena `cena_projetil`. Também aceita outra cena como segundo argumento. Para um círculo de dano no chão, use `criar_circulo(posicao, dano, tempo_aviso, raio)`.
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

  As cenas prontas ficam em `bosses/base/`: `projetil_boss.tscn`, `circulo_no_chao.tscn`, `particulas_boss.tscn` e `runa.tscn`. Os capangas podem ser qualquer inimigo de `inimigos/`.
- **Fases** (`usar_fases` no Inspector): abaixo de 66% e de 33% da vida o boss enfurece, e `esperar_no_ritmo()` encurta as pausas. Ao mudar de fase, o Riff fecha e o escudo sobe (`escudo_ao_mudar_fase`). Com fases, o dano das notas é calibrado para um Riff bom valer uma fase. Para saber em que fase está, use `if fase >= 2:`.
- **Nota maldita** (`usar_nota_maldita`, a partir de `fase_nota_maldita`): nota vermelha que machuca quem toca.
- **Cabo de força** (`usar_cabo_de_forca` no nó raiz da arena, ligado por padrão): a dupla divide uma vida contra o boss. Dano em qualquer jogador enche o boss, e dano no boss enche a dupla.
- Exemplo com tudo isso junto: `fases/boss_1/chefe_1.gd` (boss 1) e as propriedades do nó `Arena/Boss` em `fases/boss_1/boss_1.tscn`.
- O boss **só perde vida pelo Riff**. Não dê dano no boss por soco.
- Para ajustar o Riff de um boss, selecione o nó `HUD/RiffHUD` da arena e mude no Inspector `bpm` (150 por padrão, no tempo da música), `chance_nota_maldita`, `dano_perfect` e `dano_good`. Os danos só valem para boss sem fases.
- Durante o Riff, qualquer botão que não seja de nota fecha o modo. Isso é de propósito: dá tempo de reagir.
- A vida fica em `vida_maxima`, no nó raiz do `chefe_N.tscn`.
- Exemplo completo: `fases/boss_1/chefe_1.gd` (boss 1).

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

- **Profundidade: origem e colisão nos pés.** Todo personagem e objeto da rua tem a **origem do nó nos pés**: o `AnimatedSprite2D` fica deslocado para cima, e a `CollisionShape2D` é **só uma faixa fina no chão**, com uns 16 px de altura. Assim dá para passar na frente ou atrás dos outros, e a ordem de desenho (y-sort) fica certa. Ao criar um inimigo ou objeto novo, mexa na `position` do sprite até os pés ficarem na origem e deixe a colisão como uma faixa na base. Veja `inimigos/base/inimigo.tscn` e `objetos/caixote.tscn`.
- **Tiros acertam o corpo, e não os pés.** O jogador tem uma `Hurtbox` (Area2D na camada 5, grupo `hurtbox_jogador`) na altura do peito. Projéteis devem ter `collision_mask = 16` e usar `area_entered`, verificando `area.is_in_group("hurtbox_jogador")`, e nascer na altura do peito de quem atira (veja `inimigo_atirador.gd`, `altura_tiro`). Para mirar no jogador use `jogador.posicao_do_corpo()`. `jogador.global_position` é a posição dos pés, boa para ataques no chão.

- O aviso "RIFF!" do descanso é o nó `SinalRiff` (um Label) no `fases/boss_1/chefe_1.tscn`. Copie esse nó para o seu boss se quiser mudar o texto ou o lugar; sem ele, o boss cria um igual sozinho.

- Prefira editar cenas (`.tscn`) **pelo editor**. Se editar como texto, não invente `uid="uid://..."`: deixe só o `path`, e o Godot gera o resto.
- Em cena herdada, a linha `script = ...` vem **antes** das propriedades exportadas, senão os valores se perdem.
- Não deixe o editor do Godot aberto enquanto troca de branch no git, porque ele pode sobrescrever cenas com a versão antiga. Feche, troque e reabra.
- Testes rodam sem janela (`--headless`). Nesse modo a tela tem outro tamanho, então limites verticais podem diferir da janela normal.
