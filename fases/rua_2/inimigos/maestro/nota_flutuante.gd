extends "res://inimigos/atirador/projetil_inimigo.gd"

@export var amplitude = 27.0
@export var frequencia = 2.0

var eixo := Vector2.RIGHT
var _tempo = 0.0


func _physics_process(delta):
	var altura_anterior = sin(_tempo * TAU * frequencia) * amplitude
	_tempo += delta
	var altura = sin(_tempo * TAU * frequencia) * amplitude
	var passo = velocidade * delta
	global_position += eixo * passo + Vector2(0.0, altura - altura_anterior)
	distancia += passo
	if distancia >= alcance:
		queue_free()


func atingir(area):
	if not is_queued_for_deletion():
		super.atingir(area)
