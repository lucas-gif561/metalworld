extends Area2D

@export var velocidade: float = 250.0
@export var dano: int = 1

@export var tempo_vida: float = 6.0

var direcao: Vector2 = Vector2.RIGHT


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_ao_colidir)
	pass # Replace with function body.
	
func _physics_process(delta):
	global_position += direcao * velocidade * delta
	tempo_vida -= delta
	Combate.ameaca_perto(global_position, 90.0)
	if tempo_vida <= 0.0:
		queue_free()

func _ao_colidir(corpo):
	if corpo.is_in_group("jogador"):
		corpo.receber_dano(dano)
		queue_free()
