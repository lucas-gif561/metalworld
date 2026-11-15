extends AnimatedSprite2D
## Cada duelista mantém o próprio ritmo e permanece na coluna da cena.

enum Estado { VAGAR, SEGUIR, ESPELHAR, PARAR, FINTAR }

@export var limites_y := Vector2(205.0, 550.0)
@export var distancia_minima: float = 70.0
@export var velocidades := Vector2(95.0, 150.0)
@export var duracao_movimento := Vector2(1.0, 2.6)
@export var duracao_pausa := Vector2(0.35, 1.0)
@export var atraso_seguir: float = 0.35
@export var velocidade_finta: float = 230.0
@export var duracao_arrancada: float = 0.22
## Ordem: vagar, seguir, espelhar, parar e fintar. Peso zero desativa o estado.
@export var pesos: Array[float] = [5.0, 2.0, 1.0, 1.0, 2.0]
## Alturas de início e fim dos disparos coreografados.
@export var percurso_glissando := Vector2(385.0, 205.0)
@export var percurso_glissando_alto := Vector2(365.0, 205.0)

@export_group("Projéteis")
@export_range(1, 12) var tiros_por_leque: int = 5
@export_range(0.0, 80.0) var abertura_leque: float = 52.0
@export var velocidade_projetil: float = 600.0
@export var cor_projetil: Color = Color.WHITE

@onready var origem_tiro: Marker2D = $OrigemTiro
@onready var aviso_mira: Line2D = $AvisoMira

var rival: Node2D
var movimento_ativo := false
var movimento_coreografado := false

var _estado := Estado.PARAR
var _destino_y: float
var _velocidade: float
var _tempo_restante: float
var _atraso_restante: float
var _retorno_finta := false
var _origem_finta: float
var _ultima_regiao := -1


func _ready() -> void:
	_destino_y = position.y
	_tempo_restante = randf_range(duracao_pausa.x, duracao_pausa.y)


func preparar_tiro(destino: Vector2) -> Vector2:
	aviso_mira.points = PackedVector2Array([
		aviso_mira.to_local(origem_tiro.global_position),
		aviso_mira.to_local(destino),
	])
	aviso_mira.show()
	return origem_tiro.global_position.direction_to(destino)


func encerrar_preparo() -> void:
	aviso_mira.hide()


func _physics_process(delta: float) -> void:
	if not movimento_ativo or movimento_coreografado or aviso_mira.visible:
		return
	if _atraso_restante > 0.0:
		_atraso_restante -= delta
		return

	_tempo_restante -= delta
	position.y = move_toward(position.y, _destino_y, _velocidade * delta)
	if _tempo_restante > 0.0 and (_estado == Estado.PARAR or not is_equal_approx(position.y, _destino_y)):
		return

	if _estado == Estado.FINTAR and not _retorno_finta:
		_retorno_finta = true
		_destino_y = _origem_finta
		_tempo_restante = duracao_arrancada
	else:
		_escolher_movimento()


func _escolher_movimento() -> void:
	_estado = _sortear_estado()
	_destino_y = position.y
	_velocidade = randf_range(velocidades.x, velocidades.y)
	_tempo_restante = randf_range(duracao_movimento.x, duracao_movimento.y)

	match _estado:
		Estado.VAGAR:
			_destino_y = _sortear_destino()
		Estado.SEGUIR:
			var jogador = Jogo.jogador_mais_proximo(global_position)
			if jogador == null:
				_destino_y = _sortear_destino()
			else:
				var altura_jogador = get_parent().to_local(jogador.global_position).y
				_destino_y = clampf(altura_jogador, limites_y.x, limites_y.y)
				_atraso_restante = atraso_seguir
		Estado.ESPELHAR:
			_destino_y = limites_y.x + limites_y.y - rival.position.y if is_instance_valid(rival) else _sortear_destino()
			_destino_y = clampf(_destino_y, limites_y.x, limites_y.y)
		Estado.PARAR:
			_tempo_restante = randf_range(duracao_pausa.x, duracao_pausa.y)
		Estado.FINTAR:
			_origem_finta = position.y
			_retorno_finta = false
			_destino_y = limites_y.y if position.y < (limites_y.x + limites_y.y) * 0.5 else limites_y.x
			_velocidade = velocidade_finta
			_tempo_restante = duracao_arrancada


func _sortear_estado() -> Estado:
	var quantidade = mini(pesos.size(), Estado.size())
	var peso_total := 0.0
	for estado in quantidade:
		peso_total += maxf(pesos[estado], 0.0)

	var sorteio = randf() * peso_total
	for estado in quantidade:
		sorteio -= maxf(pesos[estado], 0.0)
		if sorteio < 0.0:
			return estado as Estado
	return Estado.VAGAR


func _sortear_destino() -> float:
	var altura_regiao = (limites_y.y - limites_y.x) / 3.0
	var regioes: Array[int] = []
	var faixas: Array[Vector2] = []
	for regiao in 3:
		if regiao == _ultima_regiao:
			continue
		var inicio = limites_y.x + altura_regiao * regiao
		var fim = inicio + altura_regiao
		if fim < position.y:
			fim = minf(fim, position.y - distancia_minima)
		elif inicio > position.y:
			inicio = maxf(inicio, position.y + distancia_minima)
		else:
			continue
		if inicio < fim:
			regioes.append(regiao)
			faixas.append(Vector2(inicio, fim))

	if faixas.is_empty():
		return limites_y.y if position.y < (limites_y.x + limites_y.y) * 0.5 else limites_y.x
	var indice = randi_range(0, faixas.size() - 1)
	_ultima_regiao = regioes[indice]
	return randf_range(faixas[indice].x, faixas[indice].y)
