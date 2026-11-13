@tool
extends Node2D
## Anel colorido no pé do jogador. A cor é trocada pelo jogador ao entrar
## (P1 rosa, P2 azul); o achatamento vem da escala do nó.

@export var cor := Color(1.0, 0.3, 0.72, 0.85):
	set(valor):
		cor = valor
		queue_redraw()
@export var raio := 26.0:
	set(valor):
		raio = valor
		queue_redraw()
@export var espessura := 3.0:
	set(valor):
		espessura = valor
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, cor, espessura)
