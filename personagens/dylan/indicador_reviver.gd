@tool
extends Node2D
## Círculo "segure para levantar" que aparece sobre o jogador caído
## e enche enquanto o parceiro segura interagir perto dele.

@export var cor := Color(1.0, 0.3, 0.72):
	set(valor):
		cor = valor
		queue_redraw()
@export_range(0.0, 1.0) var progresso := 0.0:
	set(valor):
		progresso = valor
		queue_redraw()
@export var raio := 16.0:
	set(valor):
		raio = valor
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 5.0)
	if progresso > 0.0:
		draw_arc(Vector2.ZERO, raio, -PI / 2, -PI / 2 + TAU * progresso, 32, cor, 5.0)
