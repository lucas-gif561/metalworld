extends "res://bosses/base/projetil_boss.gd"
## Estilhaço da granada: voa reto como as balas do boss (e machuca igual),
## com uma arte de caco de metal sorteada entre "artes", apontando a ponta
## para onde voa (a brasa fica para trás).

## Uma é sorteada para cada estilhaço. Todas com a ponta no mesmo ângulo.
@export var artes: Array[Texture2D] = []
## Para onde a ponta aponta na arte (graus; -45 = diagonal para cima e à direita)
@export var angulo_arte: float = -45.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super._ready()
	if not artes.is_empty():
		sprite.texture = artes.pick_random()
	sprite.rotation = direcao.angle() - deg_to_rad(angulo_arte)
