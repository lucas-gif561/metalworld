extends "res://bosses/base/projetil_boss.gd"

@export_range(0, 8) var limite_ricochetes := 1

@export_range(0.0, 45.0) var amplitude_da_deriva := 18.0
@export_range(0.1, 2.0) var frequencia_da_deriva := 0.65

@onready var aviso: Sprite2D = $Aviso
@onready var instrucao: Label = $Instrucao

var _direcao_inicial: Vector2
var _lado_da_curva: float
var _idade := 0.0
var _ricochetes := 0
var _lancado := false
var _contorno: PackedVector2Array
var _raio := 0.0
var _moldura: Rect2
var _continua: Callable


func preparar(mira: Vector2, desvio: float, moldura: Rect2, continua: Callable, contorno := PackedVector2Array()) -> void:
	_direcao_inicial = mira.rotated(deg_to_rad(desvio))
	# Os orbes laterais primeiro abrem o leque e depois voltam a oscilar.
	_lado_da_curva = -1.0 if desvio < 0.0 else 1.0
	_raio = $Colisor.shape.radius
	_contorno = contorno
	_moldura = moldura.grow(-_raio)
	_continua = continua


func lancar() -> void:
	# A carga fica no boss, na borda externa. O projétil entra no piso ao sair.
	global_position = global_position.clamp(_moldura.position, _moldura.end)
	_conter_no_piso(false)
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
	_conter_no_piso(true)


func _conter_no_piso(refletir: bool) -> void:
	# As normais seguem as bordas inclinadas. O raio mantém o orbe inteiro
	# dentro do contorno, inclusive nos cantos do trapézio.
	var tocou_parede := false
	for _passagem in 3:
		for indice in _contorno.size():
			var inicio = _contorno[indice]
			var lado = _contorno[(indice + 1) % _contorno.size()] - inicio
			var normal = Vector2(-lado.y, lado.x).normalized()
			var distancia = (global_position - inicio).dot(normal)
			if distancia >= _raio:
				continue
			global_position += normal * (_raio - distancia)
			if refletir and direcao.dot(normal) < 0.0:
				# Duas bordas no mesmo canto contam como um único impacto.
				if not tocou_parede:
					if _ricochetes >= limite_ricochetes:
						queue_free()
						return
					_ricochetes += 1
					tocou_parede = true
				_direcao_inicial = _direcao_inicial.bounce(normal)
				direcao = direcao.bounce(normal)
				_lado_da_curva = -_lado_da_curva


func _ao_colidir(area) -> void:
	if not _lancado or is_queued_for_deletion() or not _continua.call():
		return
	if area.is_in_group("hurtbox_jogador") and not area.get_parent().entrando:
		super._ao_colidir(area)
