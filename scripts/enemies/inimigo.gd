extends CharacterBody2D

@export var velocidade = 100.0
@export var vida = 3
@export var distancia_ataque = 72.0
@export var dano = 1
@onready var jogador = get_tree().get_first_node_in_group("jogador")
@onready var timer_ataque = $TimerAtaque
@onready var sprite = $AnimatedSprite2D

var morto = false
var em_acao = false


func _ready():
	sprite.animation_finished.connect(_ao_terminar_animacao)


func _physics_process(_delta):
	if jogador == null or morto:
		return

	if jogador.vida <= 0:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	var distancia = global_position.distance_to(jogador.global_position)

	if distancia > distancia_ataque:
		var direcao = (jogador.global_position - global_position).normalized()
		velocity = direcao * velocidade
	else:
		velocity = Vector2.ZERO

		if timer_ataque.is_stopped():
			jogador.receber_dano(dano)
			timer_ataque.start()
			_tocar_acao("attack")

	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()


func _olhar_para_jogador():
	var lado = -1.0 if jogador.global_position.x < global_position.x else 1.0
	sprite.scale.x = abs(sprite.scale.x) * lado


func _atualizar_animacao():
	if em_acao:
		return
	sprite.play("walk" if velocity != Vector2.ZERO else "idle")


func _tocar_acao(nome):
	em_acao = true
	sprite.stop()
	sprite.play(nome)


func _ao_terminar_animacao():
	if not morto:
		em_acao = false


func receber_dano(valor):
	if morto:
		return

	vida -= valor

	if vida <= 0:
		morrer()
	else:
		Audio.tocar("dano_inimigo")
		_tocar_acao("hurt")
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func morrer():
	morto = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	Audio.tocar("morte_inimigo")
	_tocar_acao("death")
	await sprite.animation_finished
	queue_free()
