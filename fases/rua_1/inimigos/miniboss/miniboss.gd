extends "res://inimigos/base/miniboss_base.gd"

const CAMADA_INVESTIDA = 32 # Camada 6: o arco de Dylan acerta, mas os pés não travam a corrida.
const QUADRO_IMPACTO_PISAO = 2

@export var alcance_investida = 420.0
@export var velocidade_investida = 780.0
@export var alcance_grito = 250.0
@export var abertura_grito = 70.0
@export var raios_pisoes := Vector3(85.0, 135.0, 185.0)

@onready var aviso_investida: Line2D = $AvisoInvestida
@onready var aviso_area: Polygon2D = $AvisoArea
@onready var contorno_area: Line2D = $AvisoArea/Contorno
@onready var _camada_normal = collision_layer
@onready var _mascara_normal = collision_mask

var _destino_x = 0.0
var _pisao_atual = 0
var _investindo = false
var _atingidos: Array[int] = []


func _processar_miniboss(delta) -> void:
	if _investindo and not morto:
		_avancar_investida(delta)
	else:
		super._processar_miniboss(delta)


func _comportamento(_delta):
	if em_acao and sprite.animation == &"pisao":
		return

	var alvo = jogador.global_position
	var diferenca = alvo - global_position
	var distancia = diferenca.length()
	var entrada = _dentro_da_arena(global_position)
	var entrando = not is_equal_approx(entrada.x, global_position.x)
	_olhar_para_jogador()

	if not entrando and timer_ataque.is_stopped():
		if distancia <= raios_pisoes[0]:
			_pisao_atual = 0
			_preparar_pisao()
			return
		if distancia <= alcance_grito:
			_preparar_grito(diferenca.normalized())
			return
		if absf(diferenca.x) <= alcance_investida:
			# Alinha a corrida na faixa do alvo antes de fixar o aviso no chão.
			if absf(diferenca.y) <= aviso_investida.width * 0.5:
				_preparar_investida(diferenca.x)
				return
			alvo.x = global_position.x

	var destino = entrada if entrando else _dentro_da_arena(alvo)
	velocity = global_position.direction_to(destino) * velocidade
	_atualizar_animacao()
	move_and_slide()


func _preparar_grito(frente: Vector2) -> void:
	var meia_abertura = deg_to_rad(abertura_grito * 0.5)
	var pontos := PackedVector2Array([Vector2.ZERO])
	for i in range(25):
		var angulo = lerpf(-meia_abertura, meia_abertura, i / 24.0)
		pontos.append(frente.rotated(angulo) * alcance_grito)
	_mostrar_aviso_area(pontos)
	carregar_ataque(_soltar_grito)
	sprite.animation = &"grito"


func _soltar_grito() -> void:
	Audio.tocar("tiro_inimigo")
	_atingir_area()


func _preparar_pisao() -> void:
	var raio = raios_pisoes[_pisao_atual]
	var pontos := PackedVector2Array()
	for i in range(48):
		pontos.append(Vector2.from_angle(TAU * i / 48.0) * raio)
	_mostrar_aviso_area(pontos)
	carregar_ataque(_soltar_pisao)
	sprite.animation = &"pisao"


func _soltar_pisao() -> void:
	while sprite.animation == &"pisao" and sprite.frame < QUADRO_IMPACTO_PISAO:
		await sprite.frame_changed
	if morto or sprite.animation != &"pisao":
		return

	_atingir_area()
	Combate.tremer(3.0 + _pisao_atual * 2.0)
	_pisao_atual += 1
	if _pisao_atual >= 3:
		return

	await sprite.animation_finished
	if not morto and sprite.animation == &"pisao" and not Jogo.todos_caidos():
		_preparar_pisao()


func _mostrar_aviso_area(pontos: PackedVector2Array) -> void:
	# O mesmo contorno indica a área visível e define onde o golpe acerta.
	aviso_area.polygon = pontos
	contorno_area.points = pontos
	aviso_area.show()


func _atingir_area() -> void:
	aviso_area.hide()
	for alvo in Jogo.jogadores_vivos():
		if Geometry2D.is_point_in_polygon(aviso_area.to_local(alvo.global_position), aviso_area.polygon):
			alvo.receber_dano(dano)


func _preparar_investida(distancia_x: float) -> void:
	var lado = -1 if distancia_x < 0.0 else 1
	_destino_x = _dentro_da_arena(global_position + Vector2(lado * alcance_investida, 0)).x
	aviso_investida.points = PackedVector2Array([Vector2.ZERO, Vector2(_destino_x - global_position.x, 0)])
	aviso_investida.show()
	carregar_ataque(_iniciar_investida)
	sprite.play()


func _iniciar_investida() -> void:
	aviso_investida.hide()
	_atingidos.clear()
	_investindo = true
	_tocar_acao("investida")
	# O dano usa a faixa anunciada; a colisão dos pés não desloca os jogadores.
	collision_layer = CAMADA_INVESTIDA
	collision_mask = 0


func _avancar_investida(delta: float) -> void:
	# O corredor de dano acompanha a distância percorrida neste quadro.
	var x_anterior = global_position.x
	global_position.x = move_toward(x_anterior, _destino_x, velocidade_investida * delta)
	var esquerda = minf(x_anterior, global_position.x)
	var direita = maxf(x_anterior, global_position.x)
	for alvo in Jogo.jogadores_vivos():
		var id = alvo.get_instance_id()
		if id in _atingidos or alvo.esquivando:
			continue
		var pos = alvo.global_position
		if pos.x >= esquerda and pos.x <= direita and absf(pos.y - global_position.y) <= aviso_investida.width * 0.5:
			_atingidos.append(id)
			alvo.receber_dano(dano)
	if is_equal_approx(global_position.x, _destino_x):
		_encerrar_investida()


func _encerrar_investida() -> void:
	_investindo = false
	em_acao = false
	collision_layer = _camada_normal
	collision_mask = _mascara_normal


func _cancelar_carga() -> void:
	super._cancelar_carga()
	if _investindo:
		_encerrar_investida()
	aviso_investida.hide()
	aviso_area.hide()
