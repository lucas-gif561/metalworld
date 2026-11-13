@tool
class_name PontoSpawn
extends Marker2D
## Ponto onde nasce um inimigo numa onda.
##
## Organização na cena da rua:
##   Spawns/Arena1/Onda1/<PontoSpawn>, Spawns/Arena1/Onda2/...
## Cada ArenaN é uma tela; cada OndaN só começa quando a anterior morre.
## Deixe cena_inimigo vazio para usar o inimigo padrão do GerenciadorOndas.

@export var cena_inimigo: PackedScene:
	set(valor):
		cena_inimigo = valor
		queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 10.0, Color(1, 0.3, 0.3, 0.6) if cena_inimigo else Color(1, 1, 1, 0.4))
