extends "res://inimigos/base/miniboss_base.gd"

const CAMADA_INVESTIDA = 32 # Camada 6: o arco de Dylan acerta, mas os pés não travam a corrida.
const QUADRO_IMPACTO_PISAO = 7 # o pé bate no chão
const QUADRO_CARGA_SOCO = 6 # punhos armados
const QUADRO_IMPACTO_SOCO = 8 # braço esticado

@export var alcance_investida = 620.0
@export var velocidade_investida = 780.0
@export var alcance_grito = 250.0
@export var abertura_grito = 70.0

@export_group("Pisão")
## Raio do círculo de dano
@export var raio_pisao = 185.0
## Só pisa com o jogador a meia distância: mais longe que isso (e dentro do raio)
@export var distancia_minima_pisao = 95.0
## Carga do pisão (mais curta que o tempo_preparo dos outros ataques)
@export var tempo_preparo_pisao = 0.45

@export_group("Socão")
## Distância (horizontal) em que ele soca quem está colado nele
@export var alcance_soco = 95.0
@export var tempo_preparo_soco = 0.35
@export var dano_soco = 2
## Chance de revidar com o socão quando apanha fora do descanso
@export_range(0.0, 1.0) var chance_contra_ataque = 0.6
## Tempo mínimo entre dois revides (segundos)
@export var intervalo_contra_ataque = 1.2

@export_group("")
## Largura do corredor da investida (o mesmo que aparece no aviso)
@export var largura_investida = 54.0
## Quanto ele avança tropeçando antes de cair de cara ao morrer
@export var distancia_queda = 70.0

# Aviso dos ataques: o contorno aparece primeiro e o "Preenchimento" cresce
# até encher no instante exato do dano.
@onready var aviso_area: Polygon2D = $AvisoArea
@onready var contorno_area: Line2D = $AvisoArea/Contorno
@onready var preenchimento_area: Polygon2D = $AvisoArea/Preenchimento
@onready var _camada_normal = collision_layer
@onready var _mascara_normal = collision_mask

var _destino_x = 0.0
var _proximo_contra_ms := 0
var _investindo = false
var _atingidos: Array[int] = []
var _tween_aviso: Tween


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
		if _alcance_do_soco(jogador):
			_preparar_soco()
			return
		if distancia >= distancia_minima_pisao and distancia <= raio_pisao * 0.85:
			_preparar_pisao()
			return
		if distancia <= alcance_grito:
			_preparar_grito(diferenca.normalized())
			return
		if absf(diferenca.x) <= alcance_investida:
			# Alinha a corrida na faixa do alvo antes de fixar o aviso no chão.
			if absf(diferenca.y) <= largura_investida * 0.5:
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
	_mostrar_aviso_area(pontos, tempo_preparo)
	carregar_ataque(_soltar_grito)
	sprite.animation = &"grito"


func _soltar_grito() -> void:
	Audio.tocar("tiro_inimigo")
	_atingir_area()


func _preparar_pisao() -> void:
	var pontos := PackedVector2Array()
	for i in range(48):
		pontos.append(Vector2.from_angle(TAU * i / 48.0) * raio_pisao)
	# Enche durante a carga e a subida da perna: completa quando o pé bate
	var subida = QUADRO_IMPACTO_PISAO / sprite.sprite_frames.get_animation_speed(&"pisao")
	_mostrar_aviso_area(pontos, tempo_preparo_pisao + subida)
	carregar_ataque(_soltar_pisao, tempo_preparo_pisao)
	# Na carga ele balança no lugar (pre_pisao, em loop) em vez de congelar
	sprite.play(&"pre_pisao")


func _soltar_pisao() -> void:
	sprite.play(&"pisao")
	while sprite.animation == &"pisao" and sprite.frame < QUADRO_IMPACTO_PISAO:
		await sprite.frame_changed
	if morto or sprite.animation != &"pisao":
		return

	_atingir_area()
	Combate.tremer(7.0)


## Socão em quem está colado nele: arma os punhos (pisca parado no quadro de
## carga) e acerta quando o braço estica
func _preparar_soco() -> void:
	carregar_ataque(_soltar_soco, tempo_preparo_soco)
	sprite.frame = QUADRO_CARGA_SOCO


func _soltar_soco() -> void:
	while sprite.animation == &"attack" and sprite.frame < QUADRO_IMPACTO_SOCO:
		await sprite.frame_changed
	if morto or sprite.animation != &"attack":
		return
	for alvo in Jogo.jogadores_vivos():
		var diferenca = alvo.global_position - global_position
		var na_frente = signf(diferenca.x) == lado_carga or absf(diferenca.x) < 10.0
		if na_frente and absf(diferenca.x) <= alcance_soco * 1.3 and absf(diferenca.y) <= faixa_ataque * 1.5:
			alvo.receber_dano(dano_soco)
	Combate.tremer(3.0)


func _alcance_do_soco(alvo) -> bool:
	if not Jogo.esta_vivo(alvo):
		return false
	var diferenca = alvo.global_position - global_position
	return absf(diferenca.x) <= alcance_soco and absf(diferenca.y) <= faixa_ataque * 1.5


## Fora do descanso, quem fica batendo nele colado leva um revide com o socão:
## ensina a fechar o combo e sair, em vez de socar sem parar
func _reagir_ao_dano() -> void:
	super._reagir_ao_dano()
	if tempo_postura_quebrada > 0.0 or _levantando or preparando or em_acao or _investindo:
		return
	if Time.get_ticks_msec() < _proximo_contra_ms or randf() >= chance_contra_ataque:
		return
	var alvo = Jogo.jogador_mais_proximo(global_position)
	if not _alcance_do_soco(alvo):
		return
	_proximo_contra_ms = Time.get_ticks_msec() + int(intervalo_contra_ataque * 1000.0)
	jogador = alvo
	_olhar_para_jogador()
	_preparar_soco()


## Mostra o contorno da área e enche por dentro em "duracao" segundos.
## "inicio" é a escala de onde o preenchimento cresce: do centro (ZERO) para
## círculo e cone, ou só no comprimento (0, 1) para o corredor da investida.
func _mostrar_aviso_area(pontos: PackedVector2Array, duracao: float, inicio := Vector2.ZERO) -> void:
	# O mesmo contorno indica a área visível e define onde o golpe acerta.
	aviso_area.polygon = pontos
	contorno_area.points = pontos
	preenchimento_area.polygon = pontos
	preenchimento_area.scale = inicio
	aviso_area.show()
	if _tween_aviso:
		_tween_aviso.kill()
	_tween_aviso = create_tween()
	_tween_aviso.tween_property(preenchimento_area, "scale", Vector2.ONE, duracao)


func _atingir_area() -> void:
	aviso_area.hide()
	for alvo in Jogo.jogadores_vivos():
		if Geometry2D.is_point_in_polygon(aviso_area.to_local(alvo.global_position), aviso_area.polygon):
			alvo.receber_dano(dano)


func _preparar_investida(distancia_x: float) -> void:
	var lado = -1 if distancia_x < 0.0 else 1
	_destino_x = _dentro_da_arena(global_position + Vector2(lado * alcance_investida, 0)).x
	var fim = _destino_x - global_position.x
	var meia = largura_investida * 0.5
	var corredor = PackedVector2Array([Vector2(0, -meia), Vector2(fim, -meia), Vector2(fim, meia), Vector2(0, meia)])
	_mostrar_aviso_area(corredor, tempo_preparo, Vector2(0, 1))
	carregar_ataque(_iniciar_investida)
	# Na carga ele fica na pose de largada da corrida
	sprite.animation = &"investida"
	sprite.frame = 0


func _iniciar_investida() -> void:
	aviso_area.hide()
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
		if pos.x >= esquerda and pos.x <= direita and absf(pos.y - global_position.y) <= largura_investida * 0.5:
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
	if _tween_aviso:
		_tween_aviso.kill()
	aviso_area.hide()


## Morre tropeçando para a frente (para onde olha) e cai de cara: a arte
## tropeça no lugar, então o corpo avança junto enquanto ela tropeça.
func morrer():
	_cancelar_carga()
	var lado = -1.0 if sprite.scale.x < 0 else 1.0
	var destino = _dentro_da_arena(global_position + Vector2(lado * distancia_queda * escala_personagem, 0))
	var tropeco = create_tween()
	tropeco.tween_interval(0.1)
	tropeco.tween_property(self, "global_position", destino, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	super.morrer()
