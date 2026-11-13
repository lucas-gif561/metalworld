extends Inimigo

@export var cena_projetil_inimigo: PackedScene
@export var distancia_ideal = 230.0


func _comportamento(_delta):
	var diferenca = jogador.global_position - global_position
	var movimento = Vector2.ZERO

	# ALINHAR COM O JOGADOR
	if abs(diferenca.y) > 15:
		movimento.y = sign(diferenca.y)

	# MANTER DISTANCIA
	if abs(diferenca.x) < distancia_ideal - 30:
		movimento.x = -sign(diferenca.x)

	elif abs(diferenca.x) > distancia_ideal + 30:
		movimento.x = sign(diferenca.x)

	velocity = movimento.normalized() * velocidade
	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()

	# ATIRAR
	if abs(diferenca.y) <= 20 and abs(diferenca.x) <= 550:
		if timer_ataque.is_stopped() and cena_projetil_inimigo != null:
			carregar_ataque(atirar) # pisca antes de atirar


func atirar():
	var projetil = cena_projetil_inimigo.instantiate()

	var direcao = 1

	if jogador.global_position.x < global_position.x:
		direcao = -1

	projetil.direcao = direcao

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = global_position + Vector2(45 * direcao, 0)
	Audio.tocar("tiro_inimigo")
	_tocar_acao("attack")
