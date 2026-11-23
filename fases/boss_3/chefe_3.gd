extends Boss

const FeixePrimal = preload("res://fases/boss_3/feixe_primal.gd")
const PadraoBlaster = preload("res://fases/boss_3/padrao_blaster.gd")
const DisparoBlaster = preload("res://fases/boss_3/disparo_blaster.gd")
const OrbePrimal = preload("res://fases/boss_3/orbe_primal.gd")
const PulsoCentral = preload("res://fases/boss_3/pulso_central.gd")
const TOTAL_FAIXAS_PAREDE := 3

@export var circuito: Node2D
@export var moldura: ReferenceRect
@export var moldura_reflexao: ReferenceRect
@export var limite_do_piso: Line2D
@export var area_da_parede: ReferenceRect
@export var centro_climax: Marker2D
@export var aviso_destino: Node2D
@export var cena_feixe: PackedScene
@export_range(1, 8) var ataques_entre_teleportes := 2
## Quantos vizinhos incluir no sorteio em torno do ponto oposto.
@export_range(0, 2) var variacao_do_salto_longo := 1
@export_range(0.1, 2.0) var tempo_aviso_teleporte := 0.4
@export_range(0.1, 2.0) var tempo_assentar := 0.3
@export_range(0.0, 3.0) var tempo_entrada := 0.8

@export_group("Fases da Luz Primal")
@export var abertura_tom_puro: Array[PadraoBlaster]
@export var ciclo_tom_puro: Array[PadraoBlaster]
@export var abertura_harmonia: Array[PadraoBlaster]
@export var ciclo_harmonia: Array[PadraoBlaster]
@export var abertura_cacofonia: Array[PadraoBlaster]
@export var ciclo_cacofonia: Array[PadraoBlaster]
@export var aviso_harmonia: String
@export var aviso_cacofonia: String

@export_group("Recuperação dos ataques")
@export_range(0.05, 1.0) var tempo_retomada := 0.2
@export_range(0.3, 2.0) var tempo_recarga_encadeamento := 0.75

@onready var concentracao: Node2D = $Concentracao
@onready var origem_feixe: Marker2D = $OrigemFeixe
@onready var orbes: Node2D = $Orbes
@onready var aviso_retomada: Sprite2D = $AvisoRetomada
@onready var animacao_retomada: AnimationPlayer = $AnimacaoRetomada

var pontos: Array[Node]
var _indice_ponto := 0
var _ponto_anterior := -1
var _feixes: Array[FeixePrimal] = []
var _fase_da_sequencia := 1
var _fase_apresentada := 0
var _ultimo_refugio := Vector2.INF


func ciclo_ataques() -> void:
	pontos = circuito.get_children()
	await esperar(tempo_entrada)
	while super.pode_atacar():
		_fase_da_sequencia = fase
		var abrindo_fase = _fase_apresentada != fase
		var padroes: Array[PadraoBlaster]
		match fase:
			1:
				padroes = abertura_tom_puro if abrindo_fase else ciclo_tom_puro
			2:
				padroes = abertura_harmonia if abrindo_fase else ciclo_harmonia
				if abrindo_fase:
					anuncio.emit(aviso_harmonia)
			3:
				padroes = abertura_cacofonia if abrindo_fase else ciclo_cacofonia
				if abrindo_fase:
					anuncio.emit(aviso_cacofonia)
		await _executar_sequencia(padroes, not abrindo_fase and escudo_ativo)
		_limpar_orbes()
		if not pode_atacar():
			continue
		_fase_apresentada = fase
		await descansar()


func _avisar_retomada(recarga_longa: bool) -> void:
	if not pode_atacar():
		return
	var duracao = tempo_recarga_encadeamento if recarga_longa else tempo_retomada
	aviso_retomada.show()
	var animacao = animacao_retomada.get_animation("retomar")
	animacao_retomada.play("retomar", -1.0, animacao.length / duracao)
	await esperar(duracao)
	animacao_retomada.stop()
	aviso_retomada.hide()


func _executar_sequencia(padroes: Array[PadraoBlaster], descansar_ao_liberar := false) -> void:
	var ataques_desde_o_salto := ataques_entre_teleportes
	for padrao in padroes:
		if not pode_atacar():
			return
		if padrao.disparos.is_empty():
			continue
		var primeiro = padrao.disparos[0]
		# Encadeamento e Pulso já começam com uma troca de posição.
		if primeiro.teleportar_antes or primeiro.cena_pulso:
			ataques_desde_o_salto = 0
		elif ataques_desde_o_salto >= ataques_entre_teleportes:
			await _saltar_na_borda()
			ataques_desde_o_salto = 0
		await _executar_padrao(padrao)
		await _avisar_retomada(padrao.recarga_longa)
		if descansar_ao_liberar and not escudo_ativo:
			return
		ataques_desde_o_salto += 1


func pode_atacar() -> bool:
	# A troca de fase encerra o descanso e os efeitos da sequência anterior.
	return _fase_da_sequencia == fase and super.pode_atacar()


func _saltar_na_borda(fator_tempo := 1.0) -> void:
	if pontos.size() < 2:
		return
	var indice_destino = _sortear_destino_distante()
	var destino: Marker2D = pontos[indice_destino]
	if await _teleportar_para(destino.global_position, fator_tempo):
		_ponto_anterior = _indice_ponto
		_indice_ponto = indice_destino
		await esperar(tempo_assentar * fator_tempo)


func _teleportar_para(destino: Vector2, fator_tempo := 1.0) -> bool:
	aviso_destino.global_position = destino
	aviso_destino.show()
	concentracao.show()
	await esperar(tempo_aviso_teleporte * fator_tempo)
	_ocultar_avisos_do_salto()
	if not pode_atacar():
		return false
	global_position = destino
	Audio.tocar("teleporte")
	return true


func _sortear_destino_distante() -> int:
	var oposto = wrapi(_indice_ponto + floori(pontos.size() * 0.5), 0, pontos.size())
	var candidatos: Array[int] = []
	for distancia in range(-variacao_do_salto_longo, variacao_do_salto_longo + 1):
		var indice = wrapi(oposto + distancia, 0, pontos.size())
		if indice != _indice_ponto and indice != _ponto_anterior:
			candidatos.append(indice)
	return oposto if candidatos.is_empty() else candidatos.pick_random()


func _executar_padrao(padrao: PadraoBlaster) -> void:
	for disparo in padrao.disparos:
		await esperar(disparo.intervalo_anterior)
		if not pode_atacar():
			return
		if disparo.cena_pulso:
			await _executar_pulso_central(disparo)
			continue
		if disparo.teleportar_antes:
			await _saltar_na_borda(disparo.fator_tempo_teleporte)
			if not pode_atacar():
				return
		if disparo.cena_orbe:
			await _lancar_rajada_de_orbes(disparo)
			if disparo.aguardar_rajada:
				while pode_atacar() and orbes.get_child_count() > 0:
					await esperar(0.05)
			continue
		if disparo.faixas_da_parede.is_empty():
			var direcao = _direcao_do_disparo()
			if direcao.is_zero_approx():
				continue
			var trajeto = _trajeto_do_feixe(origem_feixe.global_position, direcao, disparo.reflexoes)
			_lancar_feixe(trajeto, disparo)
		else:
			_lancar_parede(disparo)
		_conjurar()
		await esperar_fim_do_ataque()


func _executar_pulso_central(disparo: DisparoBlaster) -> void:
	if not await _teleportar_para(centro_climax.global_position):
		return
	await esperar(tempo_assentar)
	if not pode_atacar():
		return
	var pulso = _adicionar_feixe(disparo.cena_pulso) as PulsoCentral
	var tempo_total = pulso.preparar_refugio(disparo.tempo_aviso + disparo.tempo_carga, _ultimo_refugio)
	_ultimo_refugio = pulso.to_global(pulso.refugio.get_rect().get_center())
	pulso.iniciar_na_area(tempo_total - disparo.tempo_carga, disparo.tempo_carga, pode_atacar)
	_conjurar()
	await esperar_fim_do_ataque()


func _direcao_do_disparo() -> Vector2:
	var candidatos = Jogo.jogadores_vivos().filter(func(jogador): return not jogador.entrando)
	if candidatos.is_empty():
		return Vector2.ZERO
	var mira = candidatos.pick_random()
	return origem_feixe.global_position.direction_to(mira.posicao_do_corpo())


func _lancar_rajada_de_orbes(disparo: DisparoBlaster) -> void:
	var direcao = _direcao_do_disparo()
	if direcao.is_zero_approx() or disparo.angulos_dos_orbes.is_empty():
		return

	var rajada: Array[OrbePrimal] = []
	var origem = orbes.to_local(origem_feixe.global_position)
	var limites = area_da_parede.get_global_rect()
	for angulo in disparo.angulos_dos_orbes:
		var orbe: OrbePrimal = disparo.cena_orbe.instantiate()
		orbe.position = origem
		orbe.preparar(direcao, angulo, limites, pode_atacar, _contorno_dos_tiros())
		# A rajada carrega no mesmo ponto, com um só halo e um só aviso.
		orbe.visible = rajada.is_empty()
		orbes.add_child(orbe)
		rajada.append(orbe)

	_conjurar()
	await esperar(disparo.tempo_aviso + disparo.tempo_carga)
	if not pode_atacar():
		return
	for orbe in rajada:
		if is_instance_valid(orbe):
			orbe.lancar()


func _limpar_orbes() -> void:
	for orbe in orbes.get_children():
		orbe.queue_free()


func _lancar_parede(disparo: DisparoBlaster) -> void:
	var origem = origem_feixe.global_position
	var borda = moldura_reflexao.get_global_rect()
	var distancias = [
		origem.x - borda.position.x, origem.y - borda.position.y,
		borda.end.x - origem.x, borda.end.y - origem.y,
	]
	var direcoes = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var direcao: Vector2 = direcoes[distancias.find(distancias.min())]
	var normal = direcao.orthogonal()
	var area = Rect2(limite_do_piso.to_global(limite_do_piso.points[0]), Vector2.ZERO)
	for ponto in limite_do_piso.points:
		area = area.expand(limite_do_piso.to_global(ponto))
	var centro = area.get_center().dot(normal)
	var largura = area.size.dot(normal.abs()) / TOTAL_FAIXAS_PAREDE
	for indice in disparo.faixas_da_parede.size():
		var faixa = disparo.faixas_da_parede[indice]
		var lateral = centro + (faixa + 0.5 - TOTAL_FAIXAS_PAREDE * 0.5) * largura
		var emissor = origem + normal * (lateral - origem.dot(normal))
		var trajeto = _trajeto_do_feixe(emissor, direcao, 0)
		_lancar_feixe(trajeto, disparo, largura, indice == 0)


func _lancar_feixe(
	trajeto: PackedVector2Array, disparo: DisparoBlaster, largura := 0.0, mostrar_instrucao := true
) -> void:
	var cena = disparo.cena_feixe if disparo.cena_feixe != null else cena_feixe
	var feixe = _adicionar_feixe(cena)
	if largura > 0.0:
		feixe.ajustar_largura(largura)
	if not mostrar_instrucao:
		feixe.instrucao.hide()
	feixe.iniciar(
		trajeto, disparo.tempo_aviso, disparo.tempo_carga,
		pode_atacar, limite_do_piso, moldura.get_global_rect()
	)


func _adicionar_feixe(cena: PackedScene) -> FeixePrimal:
	var feixe: FeixePrimal = cena.instantiate()
	feixe.tree_exiting.connect(_ao_feixe_sair.bind(feixe))
	_feixes.append(feixe)
	atacando = true
	get_parent().add_child(feixe)
	return feixe


func _trajeto_do_feixe(ponta: Vector2, direcao: Vector2, reflexoes: int) -> PackedVector2Array:
	if reflexoes <= 0:
		var area = moldura.get_global_rect()
		var distancias = FeixePrimal.distancias_ate_borda(ponta, direcao, area)
		return PackedVector2Array([ponta, ponta + direcao * minf(distancias.x, distancias.y)])
	var contorno = _contorno_dos_tiros()
	var trajeto = PackedVector2Array([ponta])
	# O emissor fica fora do piso. A entrada não conta como ricochete.
	if not Geometry2D.is_point_in_polygon(ponta, contorno):
		var entrada = _encontro_com_borda(ponta, direcao, contorno)
		if entrada.is_empty():
			return _trajeto_do_feixe(ponta, direcao, 0)
		ponta = entrada.posicao + direcao * 0.1
	for _trecho in reflexoes + 1:
		var encontro = _encontro_com_borda(ponta, direcao, contorno)
		if encontro.is_empty():
			break
		trajeto.append(encontro.posicao)
		direcao = -direcao if encontro.canto else direcao.bounce(encontro.normal).normalized()
		ponta = encontro.posicao + direcao * 0.1
	return trajeto


func _contorno_dos_tiros() -> PackedVector2Array:
	var contorno := PackedVector2Array()
	# O piso marca os pés; os projéteis percorrem a faixa dos peitos.
	var altura = area_da_parede.global_position.y - limite_do_piso.to_global(limite_do_piso.points[0]).y
	for ponto in limite_do_piso.points:
		contorno.append(limite_do_piso.to_global(ponto) + Vector2(0, altura))
	return contorno


func _encontro_com_borda(origem: Vector2, direcao: Vector2, contorno: PackedVector2Array) -> Dictionary:
	var resultado := {}
	var menor := INF
	for indice in contorno.size():
		var inicio = contorno[indice]
		var fim = contorno[(indice + 1) % contorno.size()]
		var encontro = Geometry2D.segment_intersects_segment(origem, origem + direcao * 10000.0, inicio, fim)
		if encontro == null:
			continue
		var distancia = origem.distance_squared_to(encontro)
		if distancia <= 0.001:
			continue
		if is_equal_approx(distancia, menor):
			# No vértice, devolve o raio para dentro das duas bordas.
			resultado.canto = true
		elif distancia < menor:
			menor = distancia
			resultado = {"posicao": encontro, "normal": (fim - inicio).orthogonal().normalized(), "canto": false}
	return resultado


func _ao_feixe_sair(feixe: FeixePrimal) -> void:
	_feixes.erase(feixe)
	atacando = not _feixes.is_empty()


func _ocultar_avisos_do_salto() -> void:
	aviso_destino.hide()
	concentracao.hide()


func morrer() -> void:
	aviso_retomada.hide()
	animacao_retomada.stop()
	_ocultar_avisos_do_salto()
	_limpar_orbes()
	for feixe in _feixes:
		feixe.queue_free()
	# O brilho se apaga junto da animação de derrota.
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.5)
	await super.morrer()
