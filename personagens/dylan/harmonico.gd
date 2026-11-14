extends Node2D

const LIMITE_ACERTOS = 3
const TEMPO_IMPACTO = 0.08

@export var velocidade = 850.0
@export var alcance_inicial = 280.0
@export var alcance_rebote = 200.0
@export var amplitude_raio = 8.0

@onready var brilho: Line2D = $Traco/Brilho
@onready var nucleo: Line2D = $Traco/Nucleo

var _lado: int
var _dano: int
var _escala: float
var _origem: Vector2
var _alvo: Inimigo
var _ultimo_atingido = 0
var _total_acertos = 0
var _atingidos: Array[int] = []
var _tempo_impacto = 0.0


func disparar(lado: int, dano: int, escala_personagem: float) -> void:
	_lado = lado
	_dano = dano
	_escala = escala_personagem
	# O traço acompanha a escala do Dylan na fase.
	scale *= _escala
	_buscar_alvo()


func _physics_process(delta: float) -> void:
	if _tempo_impacto > 0.0:
		_tempo_impacto -= delta
		if _tempo_impacto <= 0.0:
			if _total_acertos == LIMITE_ACERTOS:
				queue_free()
			else:
				_buscar_alvo()
		return

	if not is_instance_valid(_alvo) or _alvo.morto or _alvo.is_queued_for_deletion():
		_buscar_alvo()
		return

	var destino = _alvo.global_position
	global_position = global_position.move_toward(destino, velocidade * delta)
	_atualizar_traco()
	if not global_position.is_equal_approx(destino):
		return

	_ultimo_atingido = _alvo.get_instance_id()
	if _ultimo_atingido not in _atingidos:
		_atingidos.append(_ultimo_atingido)
	_total_acertos += 1
	_alvo.receber_dano(_dano)
	_tempo_impacto = TEMPO_IMPACTO


func _buscar_alvo() -> void:
	_alvo = null
	_origem = global_position
	_atualizar_traco()
	var primeiro = _total_acertos == 0
	var alcance = alcance_inicial if primeiro else alcance_rebote
	var limite = (alcance * _escala) ** 2
	var menor_distancia_novo = limite
	var menor_distancia_repetido = limite
	var repetido: Inimigo

	for inimigo in get_tree().get_nodes_in_group("inimigos"):
		if not inimigo is Inimigo or inimigo.morto or inimigo.is_queued_for_deletion():
			continue
		var id = inimigo.get_instance_id()
		if id == _ultimo_atingido:
			continue
		var diferenca = inimigo.global_position - global_position
		if primeiro and diferenca.x * _lado < 0.0:
			continue
		var distancia = diferenca.length_squared()
		if id in _atingidos:
			if distancia <= menor_distancia_repetido:
				menor_distancia_repetido = distancia
				repetido = inimigo
		elif distancia <= menor_distancia_novo:
			menor_distancia_novo = distancia
			_alvo = inimigo

	if _alvo == null:
		_alvo = repetido
	if _alvo == null:
		queue_free()


func _atualizar_traco() -> void:
	var inicio = to_local(_origem)
	var perpendicular = inicio.normalized().orthogonal()
	var amplitude = minf(amplitude_raio, inicio.length() * 0.12)
	var pontos := PackedVector2Array([inicio])
	for i in range(1, 8):
		var lado = -1.0 if i % 2 == 0 else 1.0
		pontos.append(inicio.lerp(Vector2.ZERO, i / 8.0) + perpendicular * amplitude * lado)
	pontos.append(Vector2.ZERO)
	brilho.points = pontos
	nucleo.points = pontos
