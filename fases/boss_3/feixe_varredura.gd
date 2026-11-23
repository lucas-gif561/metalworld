extends "res://fases/boss_3/feixe_primal.gd"

@export_range(5.0, 90.0) var abertura_em_graus := 48.0

@onready var setor: Polygon2D = $Aviso/Setor
@onready var fim_do_aviso: Line2D = $Aviso/Fim

var _moldura: Rect2
var _angulo_inicial: float
var _abertura: float
var _forma: RectangleShape2D
var _consulta := PhysicsShapeQueryParameters2D.new()


func iniciar(
	trajeto: PackedVector2Array, tempo_aviso: float, tempo_carga: float,
	continua: Callable, piso: Line2D, moldura: Rect2
) -> void:
	super.iniciar(trajeto, tempo_aviso, tempo_carga, continua, piso, moldura)
	_moldura = moldura
	_abertura = deg_to_rad(abertura_em_graus)
	_angulo_inicial = (trajeto[1] - trajeto[0]).angle() - _abertura * 0.5
	_forma = colisor.shape
	_consulta.shape = _forma
	_consulta.collision_mask = collision_mask
	_consulta.collide_with_areas = true
	_consulta.collide_with_bodies = false
	_configurar_aviso()
	var pontos = PackedVector2Array([Vector2.ZERO, _extremidade(_angulo_inicial)])
	aviso.points = pontos
	carga.points = pontos
	fim_do_aviso.set_point_position(1, _extremidade(_angulo_inicial + _abertura))


func _configurar_aviso() -> void:
	# O setor cresce até a moldura de acordo com a posição e a mira do
	# boss. Seu raio cobre a arena antes do recorte para evitar um arco curto.
	var raio = _moldura.size.length() / cos(_abertura * 0.5)
	var triangulo = PackedVector2Array([
		Vector2.ZERO,
		Vector2.from_angle(_angulo_inicial) * raio,
		Vector2.from_angle(_angulo_inicial + _abertura) * raio,
	])
	var inicio = to_local(_moldura.position)
	var fim = to_local(_moldura.end)
	var contorno = PackedVector2Array([inicio, Vector2(fim.x, inicio.y), fim, Vector2(inicio.x, fim.y)])
	setor.polygon = Geometry2D.intersect_polygons(triangulo, contorno)[0]


func _extremidade(angulo: float) -> Vector2:
	var direcao = Vector2.from_angle(angulo)
	var distancias = distancias_ate_borda(global_position, direcao, _moldura)
	return direcao * minf(distancias.x, distancias.y)


func _atualizar_disparo(progresso: float) -> void:
	var angulo = _angulo_inicial + _abertura * progresso
	var extremidade = _extremidade(angulo)
	faixa.set_point_position(1, extremidade)
	nucleo.set_point_position(1, extremidade)
	_forma.size.x = extremidade.length()
	colisor.position = extremidade * 0.5
	colisor.rotation = angulo

	# Consulta a pose que acabou de ser desenhada. As sobreposições da
	# Area2D refletiriam a posição do feixe no quadro de física anterior.
	_consulta.transform = colisor.global_transform
	var areas: Array[Area2D] = []
	for encontro in get_world_2d().direct_space_state.intersect_shape(_consulta):
		if encontro.collider is Area2D:
			areas.append(encontro.collider)
	_aplicar_dano(areas)
