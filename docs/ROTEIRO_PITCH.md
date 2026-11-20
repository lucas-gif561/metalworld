# Roteiro do vídeo pitch: MetalWorld, The Last Riff

ExpoTech 2026.2 · UniFECAF · até 5 min. Os avaliadores usam **só o vídeo**.

- **Duração-alvo:** 4:50 (deixa folga de 10 s).
- **Narração:** cerca de 560 palavras no total, num ritmo calmo (~130 palavras por minuto). Cada bloco diz quem fala; dá para trocar.
- **Rua 3 e Boss 3 ficam de fora** e aparecem só como teaser no fim ("spoiler").
- **Clipes prontos** em `C:\Users\lg\Videos\MetalWorld clipes` (os painéis `painel_*.png` mostram os momentos de cada um). Os tempos abaixo, como `boss_2 0:27`, são a posição dentro do clipe.
- **Gravar com o OBS** (cerca de 2 min, jogando de verdade): P2 entrando no meio da rua, reviver o parceiro, os dois abrindo o Riff juntos, um minirriff, a tela inicial.

---

## 1. Trailer (0:00 – 0:40) · sem narração

Música do boss alta, cortes a cada 2 ou 4 batidas (a música é 150 BPM: 1 batida = 0,4 s).

| Tempo | Imagem | Fonte |
|---|---|---|
| 0:00 – 0:03 | Tela preta, logo do MetalWorld entra no tempo da música | `docs/identidade/logo_metalworld.png` |
| 0:03 – 0:10 | Dupla na Rua 1 batendo nos inimigos, barril quebrando | `rua_1 0:05 – 0:20` |
| 0:10 – 0:14 | Orquestra na Rua 2 | `rua_2 0:05 – 0:12` |
| 0:14 – 0:20 | Guitarrista do Boss 1 atirando, círculos no chão | `boss_1 0:12 – 0:40` |
| 0:20 – 0:24 | **Pistas do Riff abertas**, notas caindo, PERFECT | OBS (ou o descanso no `boss_1`) |
| 0:24 – 0:32 | Paganini e o Diabo: leque, dissonância, cordas | `boss_2 0:13`, `0:27`, `1:20` |
| 0:32 – 0:36 | "VITÓRIA!" | `boss_2` final |
| 0:36 – 0:40 | Logo + texto: **"O chefe só cai no ritmo."** | edição |

---

## 2. Quem somos (0:40 – 1:00) · Lucas

> Oi! Nós somos a equipe do **MetalWorld: The Last Riff**, do 5º semestre de Análise e Desenvolvimento de Sistemas da UniFECAF. Eu sou o Lucas, líder do projeto e responsável pela base do jogo. Comigo estão o Leonardo, que criou a história do jogo e as ruas, e o Arthur, que criou os chefes.

**Imagem:** os três falando para a câmera ou fotos com nome na tela. Depois, o menu principal (gravar no OBS).

---

## 3. A ideia (1:00 – 1:55) · Leonardo

A história é do Leonardo, criada quando a equipe conceituou o jogo no fim do semestre passado (GDD original, `METALWORLD.docx`, seção 2).

> O MetalWorld é um *beat 'em up*, aquele jogo de pancadaria lateral, misturado com jogo de ritmo, para jogar em dupla no mesmo computador. A história nasceu no fim do semestre passado, quando a gente conceituou o jogo.
>
> Ela é a do **Dylan Walker**, um jovem de Pine Creek que nasceu surdo e descobriu o heavy metal no dia em que recebeu um aparelho auditivo. Um dia ele encontra uma guitarra amaldiçoada, que guarda a alma de **Vincent Graves**, um músico que morreu sem virar lenda. Ao despertar Vincent, Dylan é levado para o **MetalWorld**, onde uma força chamada **A Dissonância** está apagando o que dá sentido à música: emoção, criatividade e identidade.
>
> O jogo não é sobre qual gênero musical é melhor. É sobre arte feita com alma contra arte vazia.
>
> E isso vira mecânica: nas ruas o Dylan abre caminho no soco, mas **o chefe só perde vida no ritmo**, quando ele saca a guitarra. Como o protagonista é surdo, toda a música do jogo também é **visual**: notas coloridas, ícones e avisos na tela.

**Imagem:** Dylan andando na Rua 1 → abrindo o Riff (o clarão da guitarra) → pistas com as notas. Se der tempo, uma arte ou o logo com o nome "A Dissonância" em destaque.

---

## 4. Como se joga: as ruas (1:55 – 2:30) · Lucas

> Nas ruas, o combate é corpo a corpo e justo: todo inimigo pisca em branco antes de bater, então dá para desviar ou interromper o golpe. O jogador tem um combo de três golpes, esquiva, e o **minirriff**: uma sequência curta de teclas que solta um ataque especial.
>
> O segundo jogador entra a qualquer momento, até no meio da fase. Se alguém cai, o parceiro pode levantar ele. Cada rua tem cinco arenas, inimigos próprios e um miniboss no final. Na Rua 2, que o Leonardo criou, a gente enfrenta uma orquestra possuída comandada pelo Maestro.

**Imagem:** `rua_1 0:05 – 0:30` (combo, barril), OBS do P2 entrando correndo e de alguém sendo levantado, `rua_2 0:00 – 0:20`.

---

## 5. Como se joga: os chefes (2:30 – 3:20) · Arthur

> Nos chefes acontece a parte principal. O chefe ataca, e de tempos em tempos ele se ajoelha: é a hora do **Riff**. As notas descem em quatro pistas, no tempo da música, e cada nota acertada tira vida do chefe. Em dupla, cada jogador tem as suas próprias pistas, e tocar junto dá mais dano do que tocar sozinho.
>
> Mas tem risco: se você leva um golpe tocando, sua guitarra trava por alguns segundos. E quando o chefe muda de fase, aparecem totens que desligam os instrumentos até a dupla quebrar eles na porrada.
>
> O primeiro chefe é um guitarrista morto-vivo num galpão. O segundo é um duelo: **Paganini contra o Diabo**, cada um num camarote do salão de concertos. Eles atiram um contra o outro e os jogadores ficam no fogo cruzado, até a própria Dissonância explodir no meio do palco.

**Imagem:** `boss_1 0:12 – 0:40` → descanso e Riff → `boss_1 1:12` (pedais) → `boss_2 0:13`, `0:40`, `0:53`, `1:07` (troca de fase), `1:20` → "VITÓRIA!".

---

## 6. Como fizemos (3:20 – 4:10) · Lucas

> O jogo foi feito na **Godot 4**, em GDScript. A gente organizou o projeto por funcionalidade e criou modelos prontos: uma classe **Boss** com uma caixa de ferramentas de ataques e mecânicas, e um inimigo base com uma inteligência de grupo, em que só alguns inimigos atacam por vez enquanto os outros cercam o jogador.
>
> Assim cada integrante trabalhou na sua parte sem quebrar a do outro. Usamos o **GitHub** com pull requests, o **Trello** para as tarefas, e temos **testes automáticos** que jogam o jogo sozinhos e conferem combate, co-op, controles, menus e a troca de fases, antes de cada entrega.
>
> Os sprites e a interface foram gerados pela equipe no PixelLab, os efeitos sonoros foram criados no Bfxr, e as músicas são de licença livre.

**Imagem:** gravação de tela do editor da Godot com a cena do boss, o quadro do Trello, a lista de PRs no GitHub e o terminal com `TUDO CERTO` dos testes.

---

## 7. Próximos passos (4:10 – 4:40) · Leonardo e Arthur

> **Leonardo:** Ainda tem mais um caminho pela frente: a Rua 3 e o último chefe…
>
> **Arthur:** …mas esse a gente não vai mostrar aqui, porque é spoiler. 😉
>
> **Leonardo:** Também queremos sprites próprios para todos os inimigos e um Riff em dupla em que um jogador toca guitarra e o outro bateria.

**Imagem:** tela escura com um "?" e uma silhueta brilhando (pode ser o boss 3 em silhueta), depois o Kevin puxando a bateria do chão.

---

## 8. Encerramento (4:40 – 4:50) · todos

> Vem jogar com a gente no estande da ExpoTech. Chama alguém e vem tocar o último riff!

**Imagem:** logo, link do GitHub (`github.com/lucas-gif561/metalworld`), nomes da equipe.

---

## Checklist de edição

- [ ] Legendas em todas as falas (combina com o tema de inclusão).
- [ ] Música de fundo mais baixa durante a narração; sons do jogo audíveis nos cortes.
- [ ] Clipes ampliados para 1080p sem suavizar (escala "nearest neighbor", para o pixel art ficar nítido).
- [ ] Duração final abaixo de 5:00.
- [ ] Subir no YouTube (não listado) e colocar o link na plataforma da ExpoTech.
