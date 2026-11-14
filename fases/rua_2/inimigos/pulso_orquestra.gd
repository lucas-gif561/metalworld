extends "res://inimigos/base/miniboss_base.gd"

const NOTA_FLUTUANTE = preload("res://fases/rua_2/inimigos/maestro/nota_flutuante.tscn")
const NOTA_VIOLINO = preload("res://fases/rua_2/inimigos/maestro/nota_regida.tscn")
const BOLA_TUBA = preload("res://fases/rua_2/inimigos/tubista/bola_demoniaca.tscn")
const TROMBONISTA = preload("res://fases/rua_2/inimigos/trombonista/trombonista.tscn")

@export var distancia_ideal = 245.0
@export var alcance_ataque = 420.0
@export var pausa_regencia = 0.55
@export var intervalo_notas = 0.24

@onready var saida_batuta: Marker2D = $SaidaBatuta
@onready var aviso_trombone: Polygon2D = $AvisoTrombone

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
	if distancia <= alcance_ataque and timer_ataque.is_stopped():
		match _proximo_ataque:
			0:
				carregar_ataque(_lancar_notas)
			1:
				_regencia = [_golpe_trombone, _nota_violinista, _bola_tubista]
				_regencia.shuffle()
				_preparar_regencia()
			2:
				_invocados = _invocados.filter(func(inimigo): return is_instance_valid(inimigo))
				if _invocados.is_empty():
					carregar_ataque(_invocar_trombonistas)
				else:
					carregar_ataque(_lancar_notas)
		_proximo_ataque = (_proximo_ataque + 1) % 3
		return

	velocity = Vector2.ZERO
	if absf(distancia - distancia_ideal) > 45.0:
		var lado = global_position.direction_to(jogador.global_position)
		var destino = _dentro_da_arena(jogador.global_position - lado * distancia_ideal)
		if destino.distance_to(global_position) <= 12.0 and distancia < distancia_ideal:
			# Se encurralado, recua pela faixa vertical que tiver espaço.
			destino = _dentro_da_arena(global_position + Vector2(0, 100.0))
			if destino.distance_to(global_position) <= 12.0:
				destino = _dentro_da_arena(global_position - Vector2(0, 100.0))
		velocity = global_position.direction_to(destino) * velocidade
	_atualizar_animacao()
	move_and_slide()


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
	_notas_restantes -= 1
	_tempo_proxima_nota = intervalo_notas


func _preparar_regencia() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		_regencia.clear()
		return
	var lado = -1.0 if mira.global_position.x < global_position.x else 1.0
	sprite.scale.x = absf(sprite.scale.x) * lado
	if _regencia.front() == _golpe_trombone:
		aviso_trombone.rotation = (mira.global_position - global_position).angle()
		aviso_trombone.show()
	carregar_ataque(_bater_batuta)


func _bater_batuta() -> void:
	var ataque: Callable = _regencia.pop_front()
	ataque.call()
	if not _regencia.is_empty():
		_pausa_regencia_restante = pausa_regencia


func _golpe_trombone() -> void:
	aviso_trombone.hide()
	Audio.tocar("boss_conjura")
	for alvo in Jogo.jogadores_vivos():
		if Geometry2D.is_point_in_polygon(aviso_trombone.to_local(alvo.global_position), aviso_trombone.polygon):
			alvo.receber_dano(dano)


func _nota_violinista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var nota = NOTA_VIOLINO.instantiate()
	nota.eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	nota.direcao = lado_carga
	_lancar_projetil(nota, origem)


func _bola_tubista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var bola = BOLA_TUBA.instantiate()
	bola.eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	_lancar_projetil(bola, origem)


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
	Audio.tocar("tiro_inimigo")


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
	aviso_trombone.hide()
	_regencia.clear()
	_pausa_regencia_restante = 0.0
	_notas_restantes = 0
