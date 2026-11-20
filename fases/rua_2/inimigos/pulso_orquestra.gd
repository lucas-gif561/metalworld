extends "res://inimigos/base/miniboss_base.gd"

const NOTA_FLUTUANTE = preload("res://fases/rua_2/inimigos/maestro/nota_flutuante.tscn")
const NOTA_VIOLINO = preload("res://fases/rua_2/inimigos/maestro/nota_regida.tscn")
const BOLA_TUBA = preload("res://fases/rua_2/inimigos/tubista/bola_demoniaca.tscn")
const TROMBONISTA = preload("res://fases/rua_2/inimigos/trombonista/trombonista.tscn")
const MARGEM_DISTANCIA = 45.0
const ABERTURA_TUBA = PI / 18.0
const ABERTURA_VIOLINO = PI / 22.5

@export var distancia_ideal = 245.0
@export var alcance_ataque = 420.0
@export var pausa_regencia = 0.55
@export var intervalo_notas = 0.24

@onready var saida_batuta: Marker2D = $SaidaBatuta

var _proximo_ataque = 0
var _regencia: Array[Callable] = []
var _invocados: Array[Node2D] = []
var _pausa_regencia_restante = 0.0
var _notas_restantes = 0
var _tempo_proxima_nota = 0.0
var _eixo_notas := Vector2.ZERO


func _processar_miniboss(delta) -> void:
	if not morto:
		if _pausa_regencia_restante > 0.0:
			_pausa_regencia_restante -= delta
			if _pausa_regencia_restante <= 0.0:
				_preparar_regencia()
			return
		if _notas_restantes > 0:
			_tempo_proxima_nota -= delta
			if _tempo_proxima_nota <= 0.0:
				_lancar_proxima_nota()
			return
	super._processar_miniboss(delta)


func _comportamento(_delta):
	_olhar_para_jogador()
	var distancia = global_position.distance_to(jogador.global_position)
	var destino = _dentro_da_arena(global_position)
	var entrando = not is_equal_approx(destino.x, global_position.x)
	if not entrando and distancia < distancia_ideal - MARGEM_DISTANCIA:
		destino = _destino_recuo(jogador.global_position)
	var recuando = not entrando and destino != global_position

	if not entrando and not recuando and distancia <= alcance_ataque and timer_ataque.is_stopped():
		match _proximo_ataque:
			0:
				carregar_ataque(_lancar_notas)
			1:
				_regencia = [_nota_violinista, _bola_tubista]
				_regencia.shuffle()
				_preparar_regencia()
			2:
				_invocados = _invocados.filter(func(inimigo): return is_instance_valid(inimigo))
				if _invocados.is_empty():
					carregar_ataque(_invocar_trombonistas)
					sprite.animation = &"invocar"
				else:
					carregar_ataque(_lancar_notas)
		_proximo_ataque = (_proximo_ataque + 1) % 3
		return

	if not entrando and distancia > distancia_ideal + MARGEM_DISTANCIA:
		var lado = global_position.direction_to(jogador.global_position)
		destino = _dentro_da_arena(jogador.global_position - lado * distancia_ideal)
	velocity = global_position.direction_to(destino) * velocidade
	_atualizar_animacao()
	move_and_slide()


func _destino_recuo(posicao_alvo: Vector2) -> Vector2:
	var ideal = posicao_alvo + posicao_alvo.direction_to(global_position) * distancia_ideal
	var destino = global_position
	# Na borda, procura uma saída lateral que também aumente a distância.
	for candidato in [ideal, global_position + Vector2.UP * 100.0,
			global_position + Vector2.DOWN * 100.0, global_position + Vector2.LEFT * 100.0,
			global_position + Vector2.RIGHT * 100.0]:
		var ponto = _dentro_da_arena(candidato)
		if global_position.distance_to(ponto) <= 12.0:
			continue
		if ponto.distance_squared_to(posicao_alvo) <= destino.distance_squared_to(posicao_alvo):
			continue
		if not test_move(global_transform, global_position.direction_to(ponto) * 6.0):
			destino = ponto
	return destino


func _lancar_notas() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	_eixo_notas = _mira_do_tiro(origem, mira.posicao_do_corpo())
	_notas_restantes = 3
	_lancar_proxima_nota()


func _lancar_proxima_nota() -> void:
	if Jogo.todos_caidos():
		_notas_restantes = 0
		return
	var nota = NOTA_FLUTUANTE.instantiate()
	nota.eixo = _eixo_notas
	_lancar_projetil(nota, _origem_tiro())
	Audio.tocar("tiro_inimigo")
	_notas_restantes -= 1
	_tempo_proxima_nota = intervalo_notas


func _preparar_regencia() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		_regencia.clear()
		return
	var lado = -1.0 if mira.global_position.x < global_position.x else 1.0
	sprite.scale.x = absf(sprite.scale.x) * lado
	carregar_ataque(_bater_batuta)
	sprite.animation = &"regencia"


func _bater_batuta() -> void:
	var ataque: Callable = _regencia.pop_front()
	ataque.call()
	if not _regencia.is_empty():
		_pausa_regencia_restante = pausa_regencia


func _nota_violinista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	for lado in [-1.0, 1.0]:
		var nota = NOTA_VIOLINO.instantiate()
		nota.eixo = eixo.rotated(ABERTURA_VIOLINO * lado)
		nota.direcao = lado_carga
		_lancar_projetil(nota, origem)
	Audio.tocar("tiro_inimigo")


func _bola_tubista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	for lado in [-1.0, 1.0]:
		var bola = BOLA_TUBA.instantiate()
		bola.eixo = eixo.rotated(ABERTURA_TUBA * lado)
		bola.velocidade_angular *= lado
		_lancar_projetil(bola, origem)
	Audio.tocar("tiro_inimigo")


func _origem_tiro() -> Vector2:
	var deslocamento = Vector2(saida_batuta.position.x * lado_carga, saida_batuta.position.y)
	return global_position + deslocamento * escala_personagem


func _mira_do_tiro(origem: Vector2, destino: Vector2) -> Vector2:
	var eixo = origem.direction_to(destino)
	return Vector2(lado_carga, 0.0) if eixo == Vector2.ZERO else eixo


func _lancar_projetil(projetil, origem: Vector2) -> void:
	projetil.dano = dano
	get_tree().current_scene.add_child(projetil)
	projetil.global_position = origem


func _invocar_trombonistas() -> void:
	if Jogo.todos_caidos():
		return
	var ondas = get_tree().current_scene.gerenciador_ondas
	for deslocamento in [Vector2(-120, -55), Vector2(120, 55)]:
		var posicao = _dentro_da_arena(global_position + deslocamento)
		var trombonista = ondas.invocar_inimigo(TROMBONISTA, posicao)
		if trombonista != null:
			_invocados.append(trombonista)
	Audio.tocar("boss_conjura")


func _cancelar_carga() -> void:
	super._cancelar_carga()
	_regencia.clear()
	_pausa_regencia_restante = 0.0
	_notas_restantes = 0
