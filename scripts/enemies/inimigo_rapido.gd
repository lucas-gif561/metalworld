extends "res://scripts/enemies/inimigo.gd"

# O skatista toma distância, se alinha na faixa e avança em linha reta

@export var velocidade_investida = 480.0
@export var duracao_investida = 0.7
@export var distancia_investida = 520.0

var investindo := false
var tempo_investida := 0.0
var direcao_investida := 1.0
var acertou := false


func _physics_process(delta):
	if jogador == null or morto:
		return

	if _processar_empurrao(delta) or _processar_atordoamento():
		investindo = false
		return

	if investindo:
		_continuar_investida(delta)
		return

	if jogador.vida <= 0:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	if preparando:
		velocity = Vector2.ZERO
		return

	var diferenca = jogador.global_position - global_position

	if _tem_vez():
		var movimento = Vector2.ZERO

		if abs(diferenca.y) > 24:
			movimento.y = sign(diferenca.y)

		if abs(diferenca.x) < 220:
			movimento.x = -sign(diferenca.x)
		elif abs(diferenca.x) > 420:
			movimento.x = sign(diferenca.x)

		velocity = movimento.normalized() * velocidade

		if abs(diferenca.y) <= 36 and abs(diferenca.x) >= 200 and abs(diferenca.x) <= distancia_investida and timer_ataque.is_stopped():
			_preparar_investida(sign(diferenca.x))
			return
	else:
		_esperar_vez(delta)

	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()


func _preparar_investida(direcao: float):
	preparando = true
	preparo_id += 1
	var id = preparo_id
	velocity = Vector2.ZERO
	_olhar_para_jogador()
	sprite.modulate = Color(1.8, 1.8, 1.8)

	await get_tree().create_timer(tempo_preparo).timeout

	if id != preparo_id or morto or not is_inside_tree():
		return

	preparando = false
	sprite.modulate = Color.WHITE
	investindo = true
	tempo_investida = duracao_investida
	direcao_investida = direcao
	acertou = false
	_tocar_acao("attack")


func _continuar_investida(delta):
	velocity = Vector2(direcao_investida * velocidade_investida, 0)
	move_and_slide()
	tempo_investida -= delta

	var diferenca = jogador.global_position - global_position

	if abs(diferenca.x) < 240 and abs(diferenca.y) < 100:
		jogador.tentar_esquiva_perfeita()

	if not acertou and abs(diferenca.x) < 120 and abs(diferenca.y) < 60:
		acertou = true
		jogador.receber_dano(dano)

	if tempo_investida <= 0.0:
		investindo = false
		timer_ataque.start()
		_liberar_vez(1.2)
