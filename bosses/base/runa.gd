extends StaticBody2D
## Totem do escudo do boss: quebra na porrada.
## Se o SpriteFrames tiver as animações "golpe" (ao apanhar) e "quebrar"
## (ao cair), elas tocam; sem elas, o totem só pisca e some na hora.

signal quebrada

@export var vida: float = 3.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("alvos_golpe") # quebra na porrada
	if _tem_animacao("ligado"):
		sprite.play("ligado")
	sprite.animation_finished.connect(_ao_terminar_animacao)


func receber_dano(valor) -> void:
	if vida <= 0:
		return
	vida -= valor
	if vida <= 0:
		_quebrar()
	elif _tem_animacao("golpe"):
		sprite.play("golpe")
	else:
		sprite.modulate = Color(1, 1, 1, 0.3)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)


func _quebrar() -> void:
	Audio.tocar("runa_quebrada")
	quebrada.emit()
	if not _tem_animacao("quebrar"):
		queue_free()
		return
	# Sai do jogo na hora (não apanha nem conta como totem de pé)
	# e só some depois de tocar a animação
	remove_from_group("alvos_golpe")
	remove_from_group("runas")
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("quebrar")


func _ao_terminar_animacao() -> void:
	if sprite.animation == "quebrar":
		# Os cacos e a fumaça somem aos poucos
		var sumir = create_tween()
		sumir.tween_property(sprite, "modulate:a", 0.0, 0.4)
		sumir.tween_callback(queue_free)
	elif sprite.animation == "golpe":
		sprite.play("ligado" if _tem_animacao("ligado") else "default")


func _tem_animacao(nome: String) -> bool:
	return sprite.sprite_frames != null and sprite.sprite_frames.has_animation(nome)
