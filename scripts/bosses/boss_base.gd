class_name Boss
extends Node2D
## Modelo comum dos bosses.
##
## Para criar um boss novo:
##   1. Cena com um AnimatedSprite2D (animações: idle, cast, hurt, death)
##   2. Script com "extends Boss"
##   3. Escreva ciclo_ataques(): um laço com os ataques, usando
##      "while pode_atacar():" e "await esperar(segundos)".
##
## O boss só perde vida pelo Riff (a arena, BossFight.gd, cuida disso).
## Para mirar: alvo() devolve um jogador vivo sorteado e
## alvo_mais_proximo() o mais perto do boss. Nunca guarde o jogador numa
## variável fixa: no co-op ele pode cair e o outro continuar.

signal vida_atualizada(vida)
signal derrotado

@export var vida_maxima: int = 100
@export var cena_projetil: PackedScene

@onready var sprite = $AnimatedSprite2D

var atacando: bool = false
var vida_atual: int


func _ready() -> void:
	add_to_group("boss")
	vida_atual = vida_maxima
	sprite.animation_finished.connect(_ao_terminar_animacao)


## Sobrescreva com o padrão de ataques do boss
func ciclo_ataques() -> void:
	pass


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
	return vida_atual > 0 and is_inside_tree() and not Jogo.todos_caidos()


## Um jogador vivo sorteado (null se todos caíram)
func alvo():
	return Jogo.jogador_aleatorio()


## O jogador vivo mais perto do boss (null se todos caíram)
func alvo_mais_proximo():
	return Jogo.jogador_mais_proximo(global_position)


## Espera alguns segundos (seguro mesmo se a fase for reiniciada no meio)
func esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(segundos).timeout


## Espera um ataque que usa "atacando = true" terminar
func esperar_fim_do_ataque() -> void:
	while atacando and is_inside_tree():
		await get_tree().process_frame


## Cria um projétil saindo do boss na direção dada
func criar_projetil(direcao: Vector2, cena: PackedScene = cena_projetil):
	if cena == null:
		return null
	var projetil = cena.instantiate()
	get_parent().add_child(projetil)
	projetil.global_position = global_position
	projetil.direcao = direcao
	return projetil
