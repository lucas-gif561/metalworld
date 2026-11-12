extends "res://scripts/enemies/inimigo.gd"

# Drone de chão: corre até o Dylan, pisca e explode. Destruído antes, não explode.

@export var raio_explosao = 190.0
@export var tempo_armado = 0.6
@export var cena_particulas: PackedScene

var armado := false


func _physics_process(delta):
	if jogador == null or morto:
		return

	if _processar_empurrao(delta) or _processar_atordoamento():
		return

	if armado:
		velocity = Vector2.ZERO
		return

	if jogador.vida <= 0:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	var diferenca = jogador.global_position - global_position

	if diferenca.length() <= 140.0:
		_armar()
		return

	velocity = diferenca.normalized() * velocidade
	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()


func _armar():
	armado = true
	_tocar_acao("attack")

	var tween = create_tween().set_loops(4)
	tween.tween_property(sprite, "modulate", Color(1, 0.3, 0.3), 0.075)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.075)

	await get_tree().create_timer(tempo_armado).timeout

	if morto or not is_inside_tree():
		return

	_explodir()


func _explodir():
	if cena_particulas:
		var particulas = cena_particulas.instantiate()
		particulas.position = global_position
		particulas.finished.connect(particulas.queue_free)
		get_tree().current_scene.add_child(particulas)

	Audio.tocar("granada")
	Combate.tremer(8.0)

	var ate_jogador = jogador.global_position - global_position

	if ate_jogador.length() <= raio_explosao * 1.8:
		jogador.tentar_esquiva_perfeita()

	if ate_jogador.length() <= raio_explosao and abs(ate_jogador.y) <= 90:
		jogador.receber_dano(dano)

	# A explosão também atinge os outros inimigos por perto
	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if alvo == self or not is_instance_valid(alvo) or alvo.get("morto"):
			continue

		var distancia = alvo.global_position - global_position

		if distancia.length() <= raio_explosao:
			if alvo.has_method("empurrar"):
				alvo.empurrar(distancia.normalized() * 800.0)
			alvo.receber_dano(1)

	vida = 0
	morrer()
