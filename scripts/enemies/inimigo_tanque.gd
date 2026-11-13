extends Inimigo

@export var cena_granada: PackedScene
@export var distancia_ideal = 320.0
@export var margem_limite = 30.0


func _comportamento(_delta):
	# Na vertical usa a mesma faixa do jogador, para sempre conseguir se alinhar
	var area = get_tree().current_scene.limites_arena().grow_individual(-margem_limite, 0.0, -margem_limite, 0.0)
	var dentro = area.grow(1.0).has_point(global_position)
	var diferenca = jogador.global_position - global_position
	var movimento = Vector2.ZERO

	if not dentro:
		# Nasce fora da tela: primeiro entra na arena
		movimento = global_position.clamp(area.position, area.end) - global_position
	else:
		# ALINHAR COM O JOGADOR
		if abs(diferenca.y) > 15:
			movimento.y = sign(diferenca.y)

		# MANTER DISTANCIA
		if abs(diferenca.x) < distancia_ideal - 40:
			movimento.x = -sign(diferenca.x)
		elif abs(diferenca.x) > distancia_ideal + 40:
			movimento.x = sign(diferenca.x)

	velocity = movimento.normalized() * velocidade
	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()

	if dentro:
		global_position = global_position.clamp(area.position, area.end)

		# ATIRAR
		if abs(diferenca.y) <= 20 and abs(diferenca.x) <= 550:
			if timer_ataque.is_stopped() and cena_granada != null:
				carregar_ataque(atirar) # pisca antes de atirar


func atirar():
	var lado = -1.0 if jogador.global_position.x < global_position.x else 1.0

	var granada = cena_granada.instantiate()
	granada.direcao = Vector2(lado, 0.0)
	granada.dano = dano

	get_tree().current_scene.add_child(granada)

	granada.global_position = global_position + Vector2(60.0 * lado, -12.0) * escala_personagem
	Audio.tocar("tiro_inimigo", 0.0)
	_tocar_acao("attack")
