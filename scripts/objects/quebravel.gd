extends StaticBody2D
## Barril/caixote: quebra na porrada e solta cena_item (comida).

@export var vida: float = 2.0
@export var cena_item: PackedScene

@onready var sprite = $AnimatedSprite2D

var morto = false


func _ready() -> void:
	add_to_group("alvos_golpe")
	sprite.animation_finished.connect(_ao_terminar_animacao)


func receber_dano(valor) -> void:
	if morto:
		return

	vida -= valor

	if vida > 0:
		Audio.tocar("dano_inimigo")
		sprite.stop()
		sprite.play("dano")
		return

	morto = true
	$CollisionShape2D.set_deferred("disabled", true)
	Audio.tocar("runa_quebrada")
	sprite.stop()
	sprite.play("quebrar")

	if cena_item:
		var item = cena_item.instantiate()
		item.position = position
		get_parent().add_child.call_deferred(item)

	await sprite.animation_finished
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _ao_terminar_animacao() -> void:
	if not morto:
		sprite.play("idle")
