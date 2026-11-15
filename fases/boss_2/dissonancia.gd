extends Area2D
## O círculo monitora os pés dos jogadores e só causa dano no pulso da animação.

@export var dano: int = 2

@onready var animacao: AnimationPlayer = $Animacao


func _ready() -> void:
	show()
	animacao.play("dissonancia")


func _aplicar_dano() -> void:
	if is_queued_for_deletion():
		return
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			corpo.receber_dano(dano)


func _ao_terminar_animacao(_nome: StringName) -> void:
	queue_free()
