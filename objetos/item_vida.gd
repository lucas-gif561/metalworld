extends Area2D

@export var cura: float = 1.0

@onready var sprite = $Sprite2D


func _ready() -> void:
	# Flutua em volta da altura gravada na cena (a origem fica no chão)
	var base = sprite.position.y
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", base - 6.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", base, 0.5).set_trans(Tween.TRANS_SINE)


# Checa todo quadro: com a vida cheia o item fica no chão até o Dylan precisar
func _physics_process(_delta: float) -> void:
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador") and corpo.vida > 0 and corpo.vida < corpo.vida_maxima:
			corpo.curar(cura)
			Audio.tocar("nota_perfect", 0.0)
			queue_free()
			return
