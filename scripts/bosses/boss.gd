extends Node2D

signal vida_atualizada(vida)
signal derrotado

@export var cena_ataque_area: PackedScene
@export var cena_projetil: PackedScene
@export var jogador: Node2D
@export var vida_maxima: int = 100

@onready var sprite = $AnimatedSprite2D

var atacando: bool = false
var vida_atual: int


func _ready() -> void:
	vida_atual = vida_maxima
	sprite.animation_finished.connect(_ao_terminar_animacao)


func receber_dano(valor: int):
	if vida_atual <= 0:
		return
	vida_atual = max(vida_atual - valor, 0)
	vida_atualizada.emit(vida_atual)

	if vida_atual <= 0:
		morrer()
	else:
		sprite.stop()
		sprite.play("hurt")
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func morrer():
	atacando = false
	sprite.modulate = Color.WHITE
	sprite.stop()
	sprite.play("death")
	await sprite.animation_finished
	derrotado.emit()


func _ao_terminar_animacao():
	if vida_atual > 0:
		sprite.play("idle")


func _conjurar():
	sprite.stop()
	sprite.play("cast")


func pode_atacar() -> bool:
	return vida_atual > 0 and jogador_vivo()


func jogador_vivo() -> bool:
	return is_instance_valid(jogador) and jogador.vida > 0


func iniciar_rajada():
	if atacando or cena_projetil == null or not pode_atacar():
		return

	atacando = true

	for i in range(6):
		if not pode_atacar():
			break

		_conjurar()
		_criar_projetil((jogador.global_position - global_position).normalized())

		await get_tree().create_timer(0.4).timeout

	atacando = false


func ataque_leque():
	if atacando or cena_projetil == null or not pode_atacar():
		return

	_conjurar()

	var direcao_central = (jogador.global_position - global_position).normalized()

	for angulo in [-40, -20, 0, 20, 40]:
		_criar_projetil(direcao_central.rotated(deg_to_rad(angulo)))


func _criar_projetil(direcao: Vector2):
	var projetil = cena_projetil.instantiate()
	get_parent().add_child(projetil)
	projetil.global_position = global_position
	projetil.direcao = direcao


func ataque_area():
	if atacando or cena_ataque_area == null or not pode_atacar():
		return

	atacando = true
	_conjurar()

	var area = cena_ataque_area.instantiate()
	get_parent().add_child(area)

	area.global_position = jogador.global_position

	await get_tree().create_timer(1.5).timeout

	atacando = false


func ciclo_ataques():
	await get_tree().create_timer(2.0).timeout

	while pode_atacar():
		iniciar_rajada()

		while atacando:
			await get_tree().process_frame

		await get_tree().create_timer(2.0).timeout

		for i in range(3):
			if not pode_atacar():
				return

			ataque_leque()

			if i < 2:
				await get_tree().create_timer(0.7).timeout

		await get_tree().create_timer(2.0).timeout

		for i in range(4):
			if not pode_atacar():
				return

			ataque_area()

			while atacando:
				await get_tree().process_frame

			if i < 3:
				await get_tree().create_timer(0.5).timeout

		await get_tree().create_timer(5.0).timeout
