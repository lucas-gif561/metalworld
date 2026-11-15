extends "res://bosses/base/circulo_no_chao.gd"
## Microfonia do guitarrista: o mesmo círculo de dano do boss, pintado de ciano
## para não sumir no chão vermelho e roxo do galpão.

@export var cor := Color(0.24, 0.92, 1.0)


func _draw():
	draw_circle(Vector2.ZERO, raio, Color(cor, 0.165))
	draw_arc(Vector2.ZERO, raio, 0, TAU, 64, Color(cor, 0.35), 2.0)
