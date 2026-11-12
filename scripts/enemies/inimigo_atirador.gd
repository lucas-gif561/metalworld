extends "res://scripts/enemies/inimigo.gd"

@export var cena_projetil_inimigo: PackedScene
@export var distancia_ideal = 360.0
@export var distancia_fuga = 220.0


func _physics_process(delta):
	if jogador == null or morto:
		return

	if _processar_empurrao(delta) or _processar_atordoamento():
		return

	if jogador.vida <= 0:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	var diferenca = jogador.global_position - global_position
	var movimento = Vector2.ZERO
	var fugindo = abs(diferenca.x) < distancia_fuga and abs(diferenca.y) < 160

	if fugindo:
		# Dylan chegou perto: recua rápido em vez de atirar
		movimento.x = -sign(diferenca.x) if diferenca.x != 0 else 1.0
	else:
		# ALINHAR COM O JOGADOR
		if abs(diferenca.y) > 30:
			movimento.y = sign(diferenca.y)

		# MANTER DISTANCIA
		if abs(diferenca.x) < distancia_ideal - 60:
			movimento.x = -sign(diferenca.x)

		elif abs(diferenca.x) > distancia_ideal + 60:
			movimento.x = sign(diferenca.x)

	velocity = movimento.normalized() * velocidade * (1.4 if fugindo else 1.0)
	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()

	# ATIRAR
	if not fugindo and abs(diferenca.y) <= 40 and abs(diferenca.x) <= 550:
		if timer_ataque.is_stopped() and cena_projetil_inimigo != null:
			atirar()
			timer_ataque.start()


func atirar():
	var projetil = cena_projetil_inimigo.instantiate()

	var direcao = 1

	if jogador.global_position.x < global_position.x:
		direcao = -1

	projetil.direcao = direcao

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = global_position + Vector2(90 * direcao, 0)
	Audio.tocar("tiro_inimigo")
	_tocar_acao("attack")
