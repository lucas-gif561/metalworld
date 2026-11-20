extends Node
## Estado geral da partida (autoload "Jogo").
##
## - Sequência das 6 fases e troca entre elas
## - Quem está jogando (P2 entra a qualquer momento: J no teclado ou START num controle livre)
## - Personagem de cada jogador (escolhido na tela de seleção do menu)
## - Consultas para inimigos e bosses: jogador_mais_proximo(), jogador_aleatorio()
## - Game over quando todos os jogadores caem

signal jogador_entrou(jogador)
signal jogador_saiu(id_jogador)
signal game_over

const FASES = [
	{"nome": "Rua 1", "cena": "res://fases/rua_1/rua_1.tscn"},
	{"nome": "Boss 1", "cena": "res://fases/boss_1/boss_1.tscn"},
	{"nome": "Rua 2", "cena": "res://fases/rua_2/rua_2.tscn"},
	{"nome": "Boss 2", "cena": "res://fases/boss_2/boss_2.tscn"},
	{"nome": "Rua 3", "cena": "res://fases/rua_3/rua_3.tscn"},
	{"nome": "Boss 3", "cena": "res://fases/boss_3/boss_3.tscn"},
]
const CENA_INICIO = "res://ui/tela_inicial.tscn"
## Personagens jogáveis, na ordem dos cartões da tela de seleção
## (ui/tela_selecao.tscn). As fases trazem o Dylan gravado como P1; ao carregar
## a fase, ele é trocado pelo personagem escolhido (_colocar_p1).
## A Miku é secreta: o cartão dela só aparece com F10 na seleção.
const PERSONAGENS = [
	"res://personagens/dylan/jogador.tscn",
	"res://personagens/baterista/baterista.tscn",
	"res://personagens/miku/miku.tscn",
]

## P1 azul e P2 rosa (anel, reviver, Riff e a vida da dupla no cabo de força)
const CORES = {
	1: Color(0.2, 0.68, 1.0),
	2: Color(1.0, 0.3, 0.72),
}

var p2_ativo := false
## Índice em PERSONAGENS de cada jogador. Os dois nunca usam o mesmo.
var personagens := {1: 0, 2: 1}
var jogadores: Array = []
var _game_over_emitido := false


func _process(_delta: float) -> void:
	# Depois do game over ninguém entra: só na partida reiniciada
	# (Com um controle só e o P1 no teclado, START nesse controle também chama o
	# P2: ver Controles._ao_receber_entrada.)
	if not p2_ativo and esta_em_fase() and not jogadores.is_empty() and not _game_over_emitido:
		if Input.is_action_just_pressed(Controles.acao(2, "entrar")):
			entrar_p2()


## Atalho de depuração (só no editor e em builds de debug, nunca no jogo
## exportado): F9 mata os inimigos que estão na fase e, no boss, esvazia a
## vida dele e dá a vitória. É tecla fixa de propósito: não é um comando de
## jogador, por isso fica fora do Mapa de Entrada.
func _input(evento: InputEvent) -> void:
	if not OS.is_debug_build() or not esta_em_fase():
		return
	if evento is InputEventKey and evento.pressed and not evento.echo and evento.keycode == KEY_F9:
		_limpar_fase_debug()


func _limpar_fase_debug() -> void:
	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if not inimigo.morto:
			inimigo.morrer()
	for boss in get_tree().get_nodes_in_group("boss"):
		boss.derrotar_agora()


# ---------------------------------------------------------------- Fases

func indice_fase_atual() -> int:
	var cena = get_tree().current_scene
	if cena == null:
		return -1
	for i in FASES.size():
		if FASES[i].cena == cena.scene_file_path:
			return i
	return -1


func esta_em_fase() -> bool:
	return indice_fase_atual() >= 0


func nome_fase_atual() -> String:
	var i = indice_fase_atual()
	return FASES[i].nome if i >= 0 else ""


func eh_ultima_fase() -> bool:
	return indice_fase_atual() == FASES.size() - 1


func iniciar_jogo() -> void:
	_trocar_cena(FASES[0].cena)


func proxima_fase() -> void:
	var i = indice_fase_atual()
	if i < 0 or i + 1 >= FASES.size():
		voltar_ao_inicio()
	else:
		_trocar_cena(FASES[i + 1].cena)


func reiniciar_fase() -> void:
	_trocar_cena(get_tree().current_scene.scene_file_path)


func voltar_ao_inicio() -> void:
	p2_ativo = false
	_trocar_cena(CENA_INICIO)


func _trocar_cena(caminho: String) -> void:
	# A cena atual só sai no fim do quadro: congela ela já, para inimigos e
	# bosses não rodarem mais um quadro procurando jogadores que não existem
	var atual = get_tree().current_scene
	if atual:
		atual.process_mode = Node.PROCESS_MODE_DISABLED
	jogadores.clear()
	var cena = load(caminho).instantiate()
	_colocar_p1(cena)
	get_tree().call_deferred("change_scene_to_node", cena)


# ---------------------------------------------------------------- Personagens

## Escolha da tela de seleção. Sozinho, só o do P1 importa; o P2 fica com o
## outro personagem, caso entre no meio da partida.
func escolher_personagens(p1: int, p2 := -1) -> void:
	personagens[1] = p1
	personagens[2] = p2 if p2 >= 0 and p2 != p1 else _outro_personagem(p1)


## O primeiro personagem aberto que não é este (nunca o secreto)
func _outro_personagem(indice: int) -> int:
	return 1 if indice == 0 else 0


func _criar_personagem(id_jogador: int) -> Node:
	var jogador = load(PERSONAGENS[personagens[id_jogador]]).instantiate()
	jogador.id_jogador = id_jogador
	return jogador


## Troca o P1 gravado na fase (o Dylan) pelo personagem escolhido, antes de a
## fase entrar na árvore: ninguém chega a ver o personagem errado.
func _colocar_p1(cena: Node) -> void:
	var gravado: Node = null
	for no in cena.get_children():
		if no.scene_file_path in PERSONAGENS:
			gravado = no
			break
	if gravado == null or (gravado.scene_file_path == PERSONAGENS[personagens[1]] and gravado.id_jogador == 1):
		return
	var p1 = _criar_personagem(1)
	var indice = gravado.get_index()
	p1.position = gravado.position
	# Sai antes de o novo entrar, para o novo herdar o mesmo nome ("Player")
	cena.remove_child(gravado)
	p1.name = gravado.name
	gravado.free()
	cena.add_child(p1)
	cena.move_child(p1, indice)
	p1.owner = cena


# ---------------------------------------------------------------- Jogadores

## Chamado pelo próprio jogador no _ready
func registrar_jogador(jogador) -> void:
	if jogadores.is_empty():
		_game_over_emitido = false

	for outro in jogadores:
		if is_instance_valid(outro):
			# Jogadores atravessam um ao outro
			jogador.add_collision_exception_with(outro)
			outro.add_collision_exception_with(jogador)

	jogadores.append(jogador)
	jogador.morreu.connect(_ao_jogador_cair)
	jogador.tree_exiting.connect(func(): jogadores.erase(jogador))
	jogador_entrou.emit(jogador)


## Chamado pela fase no _ready: cria o P2 se ele já estava jogando
func preparar_jogadores(fase: Node) -> void:
	if p2_ativo and jogador_por_id(2) == null:
		_criar_p2(fase)


func entrar_p2() -> void:
	if p2_ativo:
		return
	p2_ativo = true
	_criar_p2(get_tree().current_scene, true)


## Tira o P2 da partida (menu de pause). Ele pode entrar de novo com START.
func remover_p2() -> void:
	var p2 = jogador_por_id(2)
	p2_ativo = false
	if p2:
		jogadores.erase(p2)
		p2.queue_free()
	jogador_saiu.emit(2)
	# Se o P1 estava caído esperando o parceiro, agora é game over
	_ao_jogador_cair()


## correndo: entrou no meio da fase, então chega correndo pela esquerda da tela
func _criar_p2(fase: Node, correndo := false) -> void:
	var p1 = jogador_por_id(1)
	var p2 = _criar_personagem(2)
	var destino = (p1.position if p1 else Vector2(200, 500)) + Vector2(-70, 0)
	p2.position = destino
	if correndo:
		p2.position = Vector2(_borda_esquerda_da_tela() - 60.0, destino.y)
		p2.entrando = true # avisa o HUD (jogador_entrou) antes do _ready
	fase.add_child(p2)
	if correndo:
		p2.entrar_correndo(destino)


func _borda_esquerda_da_tela() -> float:
	var tela = get_viewport().get_visible_rect().size
	var camera = get_viewport().get_camera_2d()
	if camera == null:
		return 0.0
	return camera.get_screen_center_position().x - tela.x / 2.0 / camera.zoom.x


func jogador_por_id(id_jogador: int):
	for jogador in jogadores:
		if is_instance_valid(jogador) and jogador.id_jogador == id_jogador:
			return jogador
	return null


func esta_vivo(jogador) -> bool:
	return is_instance_valid(jogador) and jogador.is_inside_tree() and not jogador.caido


func jogadores_vivos() -> Array:
	return jogadores.filter(esta_vivo)


func todos_caidos() -> bool:
	return jogadores_vivos().is_empty()


func jogador_mais_proximo(posicao: Vector2):
	var melhor = null
	var menor = INF
	for jogador in jogadores_vivos():
		var distancia = posicao.distance_squared_to(jogador.global_position)
		if distancia < menor:
			menor = distancia
			melhor = jogador
	return melhor


func jogador_aleatorio():
	var vivos = jogadores_vivos()
	return vivos.pick_random() if not vivos.is_empty() else null


## Tamanho dos personagens na fase atual (propriedade "escala_personagens"
## da cena; as ruas usam 1,5 e as arenas de boss 1)
func escala_da_fase() -> float:
	var cena = get_tree().current_scene
	var escala = cena.get("escala_personagens") if cena else null
	return escala if escala != null else 1.0


## Aumenta uma forma de colisão sem mexer nas outras instâncias que a compartilham
func escalar_colisao(no_colisao: CollisionShape2D, fator: float) -> void:
	var forma = no_colisao.shape.duplicate()
	for propriedade in ["size", "radius", "height"]:
		if propriedade in forma:
			forma.set(propriedade, forma.get(propriedade) * fator)
	no_colisao.shape = forma
	no_colisao.position *= fator


func cor(id_jogador: int) -> Color:
	return CORES.get(id_jogador, Color.WHITE)


func _ao_jogador_cair() -> void:
	if todos_caidos() and not _game_over_emitido:
		_game_over_emitido = true
		# Ninguém sobrou para levantar: some o "segure para levantar" de todos
		for jogador in jogadores:
			if is_instance_valid(jogador):
				jogador.esconder_indicador_reviver()
		game_over.emit()
