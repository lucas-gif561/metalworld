extends StaticBody2D

signal quebrada

@export var vida: int = 3

@onready var sprite = $AnimatedSprite2D


func receber_dano(valor) -> void:
	if vida <= 0:
		return

	vida -= valor

	if vida <= 0:
		Audio.tocar("runa_quebrada")
		quebrada.emit()
		queue_free()
	else:
		sprite.modulate = Color(1, 1, 1, 0.3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
