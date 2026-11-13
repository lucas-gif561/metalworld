extends Area2D

@export var dano: int = 2
@export var tempo_aviso: float = 1.5
@export var raio: float = 45.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_aplicar_raio()
	queue_redraw()
	$AnimatedSprite2D.speed_scale = 1.5 / tempo_aviso
	await get_tree().create_timer(tempo_aviso).timeout
	
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			corpo.receber_dano(dano)
			
	queue_free()
	
	pass # Replace with function body.
	
# A cena foi desenhada com raio 45. Fica em código porque cada ataque pede um
# raio diferente (45 na trilha e no corredor, 90 no círculo grande)
func _aplicar_raio() -> void:
	var forma = $CollisionShape2D.shape.duplicate()
	forma.radius = raio
	$CollisionShape2D.shape = forma
	$AnimatedSprite2D.scale *= raio / 45.0


func _draw():
	draw_circle(Vector2.ZERO, raio, Color(1.0, 0.0, 0.0, 0.165))
	draw_arc(Vector2.ZERO, raio, 0, TAU, 64, Color(1.0, 0.0, 0.0, 0.231), 2.0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
