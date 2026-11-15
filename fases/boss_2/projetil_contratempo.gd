extends "res://fases/boss_2/projetil_duelo.gd"
## A nota percorre uma parábola até a lateral do rival.

var destino_y: float
var controle_y: float
var _origem: Vector2

@onready var rastro: Line2D = $Rastro


func _ready() -> void:
	super._ready()
	_origem = global_position


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_queued_for_deletion():
		rastro.add_point(rastro.to_local(global_position))
		if rastro.get_point_count() > 12:
			rastro.remove_point(0)


func _calcular_movimento(distancia: float) -> Vector2:
	var x = global_position.x + direcao.x * distancia
	var fracao = clampf(inverse_lerp(_origem.x, limite_lateral, x), 0.0, 1.0)
	var primeira_altura = lerpf(_origem.y, controle_y, fracao)
	var segunda_altura = lerpf(controle_y, destino_y, fracao)
	var y = lerpf(primeira_altura, segunda_altura, fracao)
	return Vector2(x, y) - global_position
