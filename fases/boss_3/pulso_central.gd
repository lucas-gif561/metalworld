extends "res://fases/boss_3/feixe_primal.gd"

const MARGEM_PARA_OS_PES := 24.0

@export_range(0.0, 1.0) var margem_de_reacao := 0.25

@onready var area_de_ataque: ReferenceRect = $AreaDeAtaque
@onready var refugio: Panel = $Refugio
@onready var pontos_refugio: Node2D = $PontosRefugio
@onready var zonas_aviso: Array[Node] = $Aviso/Zonas.get_children()
@onready var zonas_pulso: Array[Node] = $Faixa/Zonas.get_children()
@onready var colisores: Array[CollisionShape2D] = [
	colisor, $ColisorInferior, $ColisorEsquerda, $ColisorDireita,
]


func preparar_refugio(tempo_padrao: float) -> float:
	var jogadores = Jogo.jogadores_vivos().filter(func(jogador): return not jogador.entrando)
	var pontos = pontos_refugio.get_children()
	if pontos.is_empty():
		return tempo_padrao

	var tempos: Array[float] = []
	for ponto: Marker2D in pontos:
		tempos.append(_tempo_de_chegada(ponto.global_position, jogadores))

	# Sorteia entre os pontos alcançáveis no aviso. Se a dupla estiver
	# muito separada, abre um pouco mais de tempo para o refúgio comum.
	var limite = maxf(tempo_padrao, float(tempos.min()) + margem_de_reacao)
	var candidatos: Array[int] = []
	for indice in tempos.size():
		if tempos[indice] <= limite:
			candidatos.append(indice)
	var sorteado: int = candidatos.pick_random()
	refugio.position = to_local(pontos[sorteado].global_position) - refugio.size * 0.5
	_configurar_zonas()
	return maxf(tempo_padrao, tempos[sorteado])


func _tempo_de_chegada(centro: Vector2, jogadores: Array) -> float:
	var destino = Rect2(centro - refugio.size * 0.5, refugio.size).grow(-MARGEM_PARA_OS_PES)
	var tempo := 0.0
	for jogador in jogadores:
		var chegada: Vector2 = jogador.global_position.clamp(destino.position, destino.end)
		var distancia: float = jogador.global_position.distance_to(chegada)
		tempo = maxf(tempo, distancia / jogador.velocidade + margem_de_reacao)
	return tempo


func _configurar_zonas() -> void:
	# Refúgio e colisores mudam juntos porque a posição é sorteada a cada
	# Pulso. O perímetro e o tamanho do refúgio ficam na cena.
	var piso = area_de_ataque.get_rect()
	var seguro = refugio.get_rect()
	var zonas = [
		Rect2(piso.position, Vector2(piso.size.x, seguro.position.y - piso.position.y)),
		Rect2(Vector2(piso.position.x, seguro.end.y), Vector2(piso.size.x, piso.end.y - seguro.end.y)),
		Rect2(Vector2(piso.position.x, seguro.position.y), Vector2(seguro.position.x - piso.position.x, seguro.size.y)),
		Rect2(Vector2(seguro.end.x, seguro.position.y), Vector2(piso.end.x - seguro.end.x, seguro.size.y)),
	]
	for indice in zonas.size():
		var zona: Rect2 = zonas[indice]
		var forma := colisores[indice].shape as RectangleShape2D
		forma.size = zona.size
		colisores[indice].position = zona.get_center()
		for visual: ColorRect in [zonas_aviso[indice], zonas_pulso[indice]]:
			visual.position = zona.position
			visual.size = zona.size


func _atualizar_disparo(_progresso: float) -> void:
	# O Pulso acerta o piso. A colisão dos pés indica se o jogador
	# está dentro do refúgio que aparece desenhado no chão.
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			_atingir_jogador(corpo)
