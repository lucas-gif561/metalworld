extends Area2D
## A faixa avisa primeiro e causa dano só no instante do pulso.

@export var dano: int = 1

@onready var aviso: Panel = $Aviso
@onready var pulso: Panel = $Pulso


func avisar() -> void:
	aviso.show()
	pulso.hide()
	show()


func pulsar() -> void:
	aviso.hide()
	pulso.show()
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			corpo.receber_dano(dano)
