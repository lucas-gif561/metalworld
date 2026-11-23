extends "res://fases/boss_3/feixe_primal.gd"

@export var largura_da_faixa := 64.0


func ajustar_largura(largura: float) -> void:
	largura_da_faixa = largura


func iniciar(
	trajeto: PackedVector2Array, tempo_aviso: float, tempo_carga: float,
	continua: Callable, piso: Line2D, _moldura: Rect2
) -> void:
	global_position = Vector2.ZERO
	var inicio = trajeto[0]
	var fim = trajeto[1]
	var normal = inicio.direction_to(fim).orthogonal() * largura_da_faixa * 0.5
	var faixa_completa = PackedVector2Array([inicio - normal, fim - normal, fim + normal, inicio + normal])
	var contorno := PackedVector2Array()
	for ponto in piso.points:
		contorno.append(piso.to_global(ponto))
	# A direção e a largura mudam conforme a borda do boss. O recorte usa
	# o mesmo polígono no aviso, na carga, no disparo e na colisão dos pés.
	var recortes = Geometry2D.intersect_polygons(faixa_completa, contorno)
	if recortes.is_empty():
		queue_free()
		return
	var pontos: PackedVector2Array = recortes[0]
	(colisor.shape as ConvexPolygonShape2D).points = pontos
	for visual: Polygon2D in [$Aviso/Area, $Carga/Area, $Faixa/Area]:
		visual.polygon = pontos
	iniciar_na_area(tempo_aviso, tempo_carga, continua)


func _atualizar_disparo(_progresso: float) -> void:
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			_atingir_jogador(corpo)
