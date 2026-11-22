extends "res://bosses/base/projetil_boss.gd"

@export_range(0.0, 45.0) var amplitude_da_deriva := 18.0
@export_range(0.1, 2.0) var frequencia_da_deriva := 0.65

@onready var aviso: Sprite2D = $Aviso
@onready var instrucao: Label = $Instrucao

var _direcao_inicial: Vector2
var _lado_da_curva: float
var _idade := 0.0
var _lancado := false
var _moldura: Rect2
var _continua: Callable


func preparar(mira: Vector2, desvio: float, moldura: Rect2, continua: Callable) -> void:
	_direcao_inicial = mira.rotated(deg_to_rad(desvio))
	# Os orbes laterais primeiro abrem o leque e depois voltam a oscilar.
	_lado_da_curva = -1.0 if desvio < 0.0 else 1.0
	var raio: float = $Colisor.shape.radius
	_moldura = moldura.grow(-raio)
	_continua = continua


func lancar() -> void:
	# A carga fica no boss, na borda externa. O projétil entra no piso ao sair.
	global_position = global_position.clamp(_moldura.position, _moldura.end)
	_lancado = true
	monitoring = true
	aviso.hide()
	instrucao.hide()
	show()


func _physics_process(delta) -> void:
	if not _continua.is_valid() or not _continua.call():
		queue_free()
		return
	if not _lancado:
		return

	_idade += delta
	var oscilacao = sin(TAU * frequencia_da_deriva * _idade)
	direcao = _direcao_inicial.rotated(deg_to_rad(amplitude_da_deriva) * oscilacao * _lado_da_curva)
	super._physics_process(delta)
	# Reflete cada eixo separadamente, inclusive quando alcança um canto.
	# A inversão da curva mantém a deriva espelhada depois do ricochete.
	if global_position.x < _moldura.position.x or global_position.x > _moldura.end.x:
		global_position.x = clampf(global_position.x, _moldura.position.x, _moldura.end.x)
		_direcao_inicial.x = -_direcao_inicial.x
		_lado_da_curva = -_lado_da_curva
	if global_position.y < _moldura.position.y or global_position.y > _moldura.end.y:
		global_position.y = clampf(global_position.y, _moldura.position.y, _moldura.end.y)
		_direcao_inicial.y = -_direcao_inicial.y
		_lado_da_curva = -_lado_da_curva


func _ao_colidir(area) -> void:
	if not _lancado or is_queued_for_deletion() or not _continua.call():
		return
	if area.is_in_group("hurtbox_jogador") and not area.get_parent().entrando:
		super._ao_colidir(area)
