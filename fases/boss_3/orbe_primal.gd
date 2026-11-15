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
	_moldura = moldura
	_continua = continua


func lancar() -> void:
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
	if not _moldura.has_point(global_position):
		queue_free()


func _ao_colidir(area) -> void:
	if not _lancado or is_queued_for_deletion() or not _continua.call():
		return
	if area.is_in_group("hurtbox_jogador") and not area.get_parent().entrando:
		super._ao_colidir(area)
