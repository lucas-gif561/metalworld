@tool
extends Node2D

# Elipse escura no chão: ajuda a ler em que faixa da rua cada personagem está
@export var tamanho := Vector2(46, 12):
	set(valor):
		tamanho = valor
		queue_redraw()

@export var cor := Color(0, 0, 0, 0.35):
	set(valor):
		cor = valor
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, tamanho.y / tamanho.x))
	draw_circle(Vector2.ZERO, tamanho.x / 2.0, cor)
