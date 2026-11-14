extends "res://inimigos/atirador/projetil_inimigo.gd"

@export var velocidade_angular = 11.0
@export var raio_orbita := Vector2(32.0, 34.0)

var eixo := Vector2.RIGHT
var _fase = 0.0


func _physics_process(delta):
	var passo = velocidade * delta
	var antes = _orbita()
	_fase += velocidade_angular * delta
	# A bola percorre círculos ao redor do eixo que avança até a mira.
	global_position += eixo * passo + _orbita() - antes
	distancia += passo
	if distancia >= alcance:
		queue_free()


func _orbita() -> Vector2:
	return eixo * (cos(_fase) * raio_orbita.x) + eixo.orthogonal() * (sin(_fase) * raio_orbita.y)


func atingir(area):
	if not is_queued_for_deletion():
		super.atingir(area)
