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
@export var padroes: Array[PadraoBlaster]
@export_range(1, 8) var ataques_entre_teleportes := 2
## Quantos vizinhos incluir no sorteio em torno do ponto oposto.
@export_range(0, 2) var variacao_do_salto_longo := 1
@export_range(0.1, 2.0) var tempo_aviso_teleporte := 0.4
@export_range(0.1, 2.0) var tempo_assentar := 0.3

@onready var concentracao: Node2D = $Concentracao
@onready var origem_feixe: Marker2D = $OrigemFeixe
@onready var orbes: Node2D = $Orbes
@onready var temporizador: Timer = $Temporizador

var pontos: Array[Node]
var _indice_ponto := 0
var _ponto_anterior := -1
var _feixes: Array[FeixePrimal] = []


func ciclo_ataques() -> void:
	pontos = circuito.get_children()
	await esperar(2.8)
	while pode_atacar():
		await _saltar_na_borda()
		var ataques_desde_o_salto := 0
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
			ataques_desde_o_salto += 1
		_limpar_orbes()
		await descansar()


func esperar(segundos: float) -> void:
	# O tempo de aviso do teleporte para junto com o menu de pausa.
	if segundos > 0.0 and is_inside_tree():
		temporizador.start(segundos)
		await temporizador.timeout


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
	var tempo_total = pulso.preparar_refugio(disparo.tempo_aviso + disparo.tempo_carga)
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
	var limites = moldura.get_global_rect()
	for angulo in disparo.angulos_dos_orbes:
		var orbe: OrbePrimal = disparo.cena_orbe.instantiate()
		orbe.position = origem
		orbe.preparar(direcao, angulo, limites, pode_atacar)
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
	var area = area_da_parede.get_global_rect()
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
	var area = (moldura_reflexao if reflexoes > 0 else moldura).get_global_rect()
	var trajeto = PackedVector2Array([ponta])
	for _trecho in reflexoes + 1:
		var limite_x = area.end.x if direcao.x > 0.0 else area.position.x
		var limite_y = area.end.y if direcao.y > 0.0 else area.position.y
		var distancias = FeixePrimal.distancias_ate_borda(ponta, direcao, area)
		var distancia = minf(distancias.x, distancias.y)
		ponta = (ponta + direcao * distancia).clamp(area.position, area.end)
		# Num canto, o feixe reflete nos dois eixos no mesmo ponto.
		if is_equal_approx(distancia, distancias.x):
			ponta.x = limite_x
			direcao.x = -direcao.x
		if is_equal_approx(distancia, distancias.y):
			ponta.y = limite_y
			direcao.y = -direcao.y
		trajeto.append(ponta)
	return trajeto


func _ao_feixe_sair(feixe: FeixePrimal) -> void:
	_feixes.erase(feixe)
	atacando = not _feixes.is_empty()


func _ocultar_avisos_do_salto() -> void:
	aviso_destino.hide()
	concentracao.hide()


func morrer() -> void:
	_ocultar_avisos_do_salto()
	_limpar_orbes()
	for feixe in _feixes:
		feixe.queue_free()
	# O brilho se apaga junto da animação de derrota.
	create_tween().tween_property(sprite, "modulate:a", 0.0, 0.5)
	await super.morrer()
