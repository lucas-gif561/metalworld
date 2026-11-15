extends Area2D

enum Estado { AVISO, CARGA, DISPARO, DISSIPACAO }
enum RegraDano { QUALQUER_JOGADOR, EM_MOVIMENTO, PARADO }

@export var regra_dano := RegraDano.QUALQUER_JOGADOR
@export var simular_disparo := false
@export_range(0.0, 1.0) var limite_proporcional_de_largura := 0.0
@export_range(0.0, 30.0) var velocidade_minima := 8.0
@export_range(1, 10) var dano := 1
@export_range(0.05, 2.0) var tempo_ativo := 0.16
@export_range(0.05, 2.0) var tempo_dissipacao := 0.18

@onready var aviso: Line2D = $Aviso
@onready var mira: Line2D = $Aviso/Mira
@onready var carga: Line2D = $Carga
@onready var faixa: Line2D = $Faixa
@onready var nucleo: Line2D = $Nucleo
@onready var colisor: CollisionShape2D = $Colisor
@onready var instrucao: Label = $Instrucao

var _estado := Estado.AVISO
var _restante := 0.0
var _tempo_carga := 0.0
var _continua: Callable
var _atingidos: Array[int] = []
var _posicoes_anteriores: Dictionary[int, Vector2] = {}
var _em_movimento: Dictionary[int, bool] = {}


func iniciar(
	trajeto: PackedVector2Array, tempo_aviso: float, tempo_carga: float,
	continua: Callable, piso: Line2D, _moldura: Rect2
) -> void:
	global_position = trajeto[0]
	var pontos := PackedVector2Array()
	for ponto in trajeto:
		pontos.append(to_local(ponto))

	var largura = (colisor.shape as RectangleShape2D).size.y
	if limite_proporcional_de_largura > 0.0:
		# A largura máxima depende do ângulo da mira. Na horizontal, por
		# exemplo, a faixa precisa caber na dimensão mais curta do piso.
		var normal = pontos[0].direction_to(pontos[1]).orthogonal()
		var menor_lateral = INF
		var maior_lateral = -INF
		for vertice in piso.points:
			var ponto = to_local(piso.to_global(vertice))
			menor_lateral = minf(menor_lateral, ponto.dot(normal))
			maior_lateral = maxf(maior_lateral, ponto.dot(normal))
		largura = minf(largura, (maior_lateral - menor_lateral) * limite_proporcional_de_largura)
		ajustar_largura(largura)

	aviso.points = pontos
	mira.points = pontos
	faixa.points = pontos
	carga.points = pontos
	nucleo.points = pontos
	_configurar_colisores(pontos, largura)
	iniciar_na_area(tempo_aviso, tempo_carga, continua)


## Inicia o aviso e o disparo usando a geometria já definida na cena.
func iniciar_na_area(tempo_aviso: float, tempo_carga: float, continua: Callable) -> void:
	_tempo_carga = tempo_carga
	_restante = tempo_aviso
	_continua = continua


func ajustar_largura(largura: float) -> void:
	# A Parede usa a mesma cena nas bordas curtas e compridas.
	var forma := colisor.shape as RectangleShape2D
	forma.size.y = largura
	aviso.width = largura
	faixa.width = largura


static func distancias_ate_borda(origem: Vector2, direcao: Vector2, area: Rect2) -> Vector2:
	var limite_x = area.end.x if direcao.x > 0.0 else area.position.x
	var limite_y = area.end.y if direcao.y > 0.0 else area.position.y
	var x = INF if is_zero_approx(direcao.x) else (limite_x - origem.x) / direcao.x
	var y = INF if is_zero_approx(direcao.y) else (limite_y - origem.y) / direcao.y
	return Vector2(x, y)


func _configurar_colisores(pontos: PackedVector2Array, largura: float) -> void:
	# A mira e as reflexões definem os trechos durante a partida. Todos
	# pertencem à mesma Area2D e compartilham a lista de jogadores atingidos.
	var forma_base := colisor.shape as RectangleShape2D
	for indice in pontos.size() - 1:
		var inicio = pontos[indice]
		var fim = pontos[indice + 1]
		var segmento = fim - inicio
		var colisao = colisor
		if indice > 0:
			colisao = CollisionShape2D.new()
			colisao.name = "Colisor%d" % (indice + 1)
			add_child(colisao)
		var forma := forma_base.duplicate() as RectangleShape2D
		forma.size = Vector2(segmento.length(), largura)
		colisao.shape = forma
		colisao.position = inicio.lerp(fim, 0.5)
		colisao.rotation = segmento.angle()


func _physics_process(delta: float) -> void:
	if not _continua.is_valid() or not _continua.call():
		queue_free()
		return

	if regra_dano != RegraDano.QUALQUER_JOGADOR:
		_registrar_movimento(delta)
	_restante -= delta
	match _estado:
		Estado.AVISO:
			if _restante <= 0.0:
				_estado = Estado.CARGA
				_restante = _tempo_carga
				carga.show()
		Estado.CARGA:
			if _restante <= 0.0:
				_concluir_carga()
		Estado.DISPARO:
			if _restante > 0.0:
				_atualizar_disparo(1.0 - _restante / tempo_ativo)
			else:
				_estado = Estado.DISSIPACAO
				_restante = tempo_dissipacao
				nucleo.hide()
		Estado.DISSIPACAO:
			var linha = aviso if simular_disparo else faixa
			linha.modulate.a = clampf(_restante / tempo_dissipacao, 0.0, 1.0)
			if _restante <= 0.0:
				queue_free()


func _concluir_carga() -> void:
	carga.hide()
	if simular_disparo:
		_estado = Estado.DISSIPACAO
		_restante = tempo_dissipacao
		instrucao.show()
		return

	_estado = Estado.DISPARO
	_restante = tempo_ativo
	aviso.hide()
	faixa.show()
	nucleo.show()
	_atualizar_disparo(0.0)


func _atualizar_disparo(_progresso: float) -> void:
	_aplicar_dano(get_overlapping_areas())


func _aplicar_dano(areas: Array[Area2D]) -> void:
	for area in areas:
		if area.monitorable and area.is_in_group("hurtbox_jogador"):
			_atingir_jogador(area.get_parent())


func _atingir_jogador(jogador: Node2D) -> void:
	if not _continua.call() or not Jogo.esta_vivo(jogador) or jogador.entrando:
		return
	var id = jogador.get_instance_id()
	if not _atingidos.has(id) and _regra_permite_dano(id):
		_atingidos.append(id)
		jogador.receber_dano(dano)


func _registrar_movimento(delta: float) -> void:
	var limite = velocidade_minima * delta
	for jogador in Jogo.jogadores_vivos():
		var id = jogador.get_instance_id()
		var posicao: Vector2 = jogador.global_position
		var anterior: Vector2 = _posicoes_anteriores.get(id, posicao)
		# Mede o deslocamento real. Pressionar contra a parede conta como
		# parado, assim como tocar o Riff ou ficar imóvel durante um soco.
		_em_movimento[id] = posicao.distance_squared_to(anterior) > limite * limite
		_posicoes_anteriores[id] = posicao


func _regra_permite_dano(id: int) -> bool:
	match regra_dano:
		RegraDano.EM_MOVIMENTO:
			return _em_movimento.get(id, false)
		RegraDano.PARADO:
			return not _em_movimento.get(id, false)
	return true
