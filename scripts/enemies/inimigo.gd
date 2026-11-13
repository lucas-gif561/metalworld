class_name Inimigo
extends CharacterBody2D
## Modelo comum de inimigo do beat 'em up.
##
## Para criar um inimigo novo:
##   1. Crie uma cena herdada de res://scenes/enemies/inimigo.tscn
##      (ou use o mesmo formato: AnimatedSprite2D, CollisionShape2D, TimerAtaque)
##   2. Crie um script com "extends Inimigo"
##   3. Escreva só o _comportamento(delta). O alvo já está em "jogador"
##      (o jogador vivo mais próximo, atualizado sozinho).
##
## Animações esperadas no SpriteFrames: idle, walk, attack, hurt, death.

signal morreu(inimigo)

@export var velocidade = 100.0
@export var vida = 3
@export var distancia_ataque = 72.0
@export var dano = 1
@export var intervalo_troca_alvo = 0.5

@onready var timer_ataque = $TimerAtaque
@onready var sprite = $AnimatedSprite2D

## Alvo atual: o jogador vivo mais próximo (null se todos caíram)
var jogador: Node2D = null
var morto = false
var em_acao = false
var _tempo_troca_alvo = 0.0


func _ready():
	add_to_group("inimigos")
	sprite.animation_finished.connect(_ao_terminar_animacao)


func _physics_process(delta):
	if morto:
		return

	_atualizar_alvo(delta)

	if jogador == null:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	_comportamento(delta)


## Comportamento padrão: corre até o jogador e bate de perto.
## Inimigos novos sobrescrevem esta função.
func _comportamento(_delta):
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


func _atualizar_alvo(delta):
	_tempo_troca_alvo -= delta
	if _tempo_troca_alvo <= 0.0 or not Jogo.esta_vivo(jogador):
		jogador = Jogo.jogador_mais_proximo(global_position)
		_tempo_troca_alvo = intervalo_troca_alvo


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
		_tocar_acao("hurt")
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func morrer():
	morto = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	morreu.emit(self)
	_tocar_acao("death")
	await sprite.animation_finished
	queue_free()
