extends Node
## Estado geral da partida (autoload "Jogo").
##
## - Sequência das 6 fases e troca entre elas
## - Quem está jogando (P2 entra a qualquer momento apertando START/A no controle)
## - Consultas para inimigos e bosses: jogador_mais_proximo(), jogador_aleatorio()
## - Game over quando todos os jogadores caem

signal jogador_entrou(jogador)
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
const CENA_JOGADOR = "res://personagens/dylan/jogador.tscn"

const CORES = {
	1: Color(1.0, 0.3, 0.72),
	2: Color(0.35, 0.9, 1.0),
}

var p2_ativo := false
var jogadores: Array = []
var _game_over_emitido := false


func _process(_delta: float) -> void:
	# Depois do game over ninguém entra: só na partida reiniciada
	if not p2_ativo and esta_em_fase() and not jogadores.is_empty() and not _game_over_emitido:
		if Input.is_action_just_pressed(Controles.acao(2, "entrar")):
			entrar_p2()


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
	jogadores.clear()
	get_tree().call_deferred("reload_current_scene")


func voltar_ao_inicio() -> void:
	p2_ativo = false
	_trocar_cena(CENA_INICIO)


func _trocar_cena(caminho: String) -> void:
	jogadores.clear()
	get_tree().call_deferred("change_scene_to_file", caminho)


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
	_criar_p2(get_tree().current_scene)


func _criar_p2(fase: Node) -> void:
	var p1 = jogador_por_id(1)
	var p2 = load(CENA_JOGADOR).instantiate()
	p2.id_jogador = 2
	p2.position = (p1.position if p1 else Vector2(200, 500)) + Vector2(-70, 0)
	fase.add_child(p2)


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
		game_over.emit()
