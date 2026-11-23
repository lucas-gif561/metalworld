extends "res://fases/boss_3/feixe_primal.gd"

@export_range(32, 128) var segmentos_da_onda := 96
@export_range(1, 5) var quantidade_ondas := 1
@export_range(0.1, 1.0) var intervalo_ondas := 0.22

@onready var frente_onda: Line2D = $FrenteOnda
@onready var halo_origem: Sprite2D = $HaloOrigem

var _origem := Vector2.ZERO
var _raio_final := 0.0
var _alcancados: Array[int] = []
var _ondas_disparadas := 0


func iniciar(
	trajeto: PackedVector2Array, tempo_aviso: float, tempo_carga: float,
	continua: Callable, _piso: Line2D, moldura: Rect2
) -> void:
	# O emissor muda com o teleporte. A cobertura integral está gravada na cena.
	global_position = Vector2.ZERO
	_origem = trajeto[0]
	halo_origem.position = _origem
	for canto in [moldura.position, Vector2(moldura.end.x, moldura.position.y), moldura.end, Vector2(moldura.position.x, moldura.end.y)]:
		_raio_final = maxf(_raio_final, _origem.distance_to(canto))
	iniciar_na_area(tempo_aviso, tempo_carga, continua)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_queued_for_deletion():
		return
	if _estado == Estado.DISSIPACAO and _ondas_disparadas < quantidade_ondas:
		# Repete a mesma cor a partir da mesma origem. Cada frente reavalia
		# o movimento e o dano, respeitando a invulnerabilidade do jogador.
		_estado = Estado.AVISO
		_restante = intervalo_ondas
		_tempo_carga = 0.0
		_alcancados.clear()
		_atingidos.clear()
		aviso.show()
		faixa.hide()
		frente_onda.hide()
	halo_origem.visible = _estado == Estado.AVISO or _estado == Estado.CARGA
	frente_onda.visible = _estado == Estado.DISPARO


func _atualizar_disparo(progresso: float) -> void:
	var raio = _raio_final * progresso
	var pontos := PackedVector2Array()
	for indice in segmentos_da_onda:
		pontos.append(_origem + Vector2.from_angle(TAU * indice / segmentos_da_onda) * raio)
	frente_onda.points = pontos
	# Cada jogador responde uma vez, quando a frente passa por ele.
	# A esquiva é tratada pelo receber_dano do jogador, como nos outros ataques.
	for jogador in Jogo.jogadores_vivos():
		if jogador.entrando:
			continue
		var id = jogador.get_instance_id()
		if _alcancados.has(id) or _origem.distance_to(jogador.posicao_do_corpo()) > raio:
			continue
		_alcancados.append(id)
		_atingir_jogador(jogador)


func _concluir_carga() -> void:
	_ondas_disparadas += 1
	super._concluir_carga()
	frente_onda.show()
