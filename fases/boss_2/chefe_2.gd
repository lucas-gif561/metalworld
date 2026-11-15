extends Boss
## O duelo usa a vida, as fases e a derrota de um único Boss.

const Duelista = preload("res://fases/boss_2/duelista.gd")
const ProjetilDuelo = preload("res://fases/boss_2/projetil_duelo.gd")
const ProjetilContratempo = preload("res://fases/boss_2/projetil_contratempo.gd")
const CordaDuelo = preload("res://fases/boss_2/corda_duelo.gd")
const Dissonancia = preload("res://fases/boss_2/dissonancia.gd")
const FormaPinball = preload("res://fases/boss_2/forma_pinball.tres")

@export var tempo_preparo: float = 0.5
@export var intervalo_resposta: float = 1.0
@export var intervalo_entre_duelos: float = 1.6
@export var intervalo_entre_ataques: float = 0.65
@export var intervalo_staccato: float = 0.28
@export var angulos_leque_diabo := PackedFloat32Array([-29.0, 7.0, 38.0])
@export var tempo_extra_riff: float = 1.0
@export var cena_dissonancia: PackedScene

@export_group("Glissando")
@export var atraso_paganini: float = 0.54
@export var atraso_paganini_onda_alta: float = 0.23
@export var intervalos_diabo := PackedFloat32Array([0.13, 0.24, 0.27, 0.34])
@export var intervalos_paganini := PackedFloat32Array([0.24, 0.24, 0.24, 0.24])
@export var intervalos_diabo_onda_alta := PackedFloat32Array([0.29, 0.18])
@export var intervalos_paganini_onda_alta := PackedFloat32Array([0.24, 0.24])
@export_range(50.0, 600.0) var velocidade_posicionamento: float = 320.0
@export var teto_ricochete: CollisionShape2D
@export var piso_ricochete: CollisionShape2D

@export_group("Quatro Cordas")
@export var tempo_aviso_cordas: float = 1.0
@export var duracao_pulso_cordas: float = 0.24

@export_group("Pinball")
@export var cena_pinball: PackedScene
@export var velocidade_pinball: float = 650.0

@export_group("Contratempo")
@export var cena_contratempo: PackedScene
@export var distancia_contratempo: float = 110.0
@export var tempo_deslocamento_contratempo: float = 0.48
@export var aviso_segunda_salva: float = 0.32

@onready var paganini: Duelista = $AnimatedSprite2D
@onready var aviso_pinball_piso: Line2D = $AnimatedSprite2D/AvisoPinballPiso
@onready var aviso_pinball_curto: Line2D = $AnimatedSprite2D/AvisoPinballCurto
@onready var diabo: Duelista = $Diabo
@onready var _cor_diabo: Color = diabo.self_modulate
@onready var projeteis: Node2D = $Projeteis
@onready var cordas: Array[Node] = $Cordas.get_children()
@onready var dissonancias: Node2D = $Dissonancias

var _staccato_alcancou_o_diabo := false
var _pinball_alcancou_o_diabo := false
var _movimentos_coreografados: Array[Tween] = []
var _primeira_corda := 0


func _ready() -> void:
	# A vida é compartilhada, mas é o Diabo que reage aos acertos do Riff.
	sprite = diabo
	super._ready()
	paganini.rival = diabo
	diabo.rival = paganini
	diabo.animation_changed.connect(_sincronizar_derrota)
	derrotado.connect(hide)


func ciclo_ataques() -> void:
	await esperar(2.0)
	while pode_atacar():
		await _sequencia_de_ataques(fase)
		await descansar()
		await esperar_no_ritmo(intervalo_entre_duelos)


func _sequencia_de_ataques(fase_da_sequencia: int) -> void:
	var ataques: Array[Callable] = [_duelo_de_leques.bind(fase_da_sequencia >= 2)]
	if fase_da_sequencia >= 3:
		ataques.append(_quatro_cordas)
	if fase_da_sequencia >= 2:
		ataques.append(_staccato_com_resposta)
	if fase_da_sequencia >= 3:
		ataques.append(_quatro_cordas)
	if fase_da_sequencia == 1:
		ataques.append(_pinball_com_resposta)

	for indice in ataques.size():
		if not pode_atacar():
			return
		if indice > 0:
			await esperar_no_ritmo(intervalo_entre_ataques)
			if not pode_atacar():
				return
		await ataques[indice].call()
		await _esperar_projeteis(true)


func _duelo_de_leques(simultaneo: bool) -> void:
	await _leque(paganini, diabo, simultaneo)
	if not simultaneo and pode_atacar():
		await esperar(maxf(0.0, intervalo_resposta - tempo_preparo))
		await _leque(diabo, paganini)


func _staccato_com_resposta() -> void:
	_staccato_alcancou_o_diabo = false
	var direcao_diabo = diabo.preparar_tiro(paganini.origem_tiro.global_position)
	Audio.tocar("boss_conjura")
	for i in 3:
		var direcao = paganini.preparar_tiro(diabo.origem_tiro.global_position)
		await esperar(tempo_preparo if i == 0 else intervalo_staccato)
		if not pode_atacar():
			break
		var projetil = _disparar(paganini, diabo, direcao, 0)
		projetil.alcancou_lateral.connect(_ao_staccato_alcancar_o_diabo)
		if i == 0:
			diabo.encerrar_preparo()
			for angulo in angulos_leque_diabo:
				_disparar(diabo, paganini, direcao_diabo.rotated(deg_to_rad(angulo)), 1)
	paganini.encerrar_preparo()
	diabo.encerrar_preparo()

	await _esperar_projeteis()
	if _staccato_alcancou_o_diabo and pode_atacar():
		await _glissando()


func _ao_staccato_alcancar_o_diabo() -> void:
	_staccato_alcancou_o_diabo = true


func _glissando() -> void:
	await _onda_glissando(false)
	if pode_atacar():
		await _onda_glissando(true)


func _onda_glissando(onda_alta: bool) -> void:
	paganini.movimento_coreografado = true
	diabo.movimento_coreografado = true
	var percurso_paganini = paganini.percurso_glissando_alto if onda_alta else paganini.percurso_glissando
	var percurso_diabo = diabo.percurso_glissando_alto if onda_alta else diabo.percurso_glissando
	var aproximacao = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	var tempo_paganini = absf(percurso_paganini.x - paganini.position.y) / velocidade_posicionamento
	var tempo_diabo = absf(percurso_diabo.x - diabo.position.y) / velocidade_posicionamento
	aproximacao.tween_property(paganini, "position:y", percurso_paganini.x, tempo_paganini)
	aproximacao.tween_property(diabo, "position:y", percurso_diabo.x, tempo_diabo)
	_movimentos_coreografados = [aproximacao]
	await _esperar_coreografia()
	if not pode_atacar():
		_encerrar_coreografia()
		return

	diabo.preparar_tiro(paganini.origem_tiro.global_position)
	paganini.preparar_tiro(diabo.origem_tiro.global_position)
	Audio.tocar("boss_conjura")
	await esperar(tempo_preparo)
	paganini.encerrar_preparo()
	diabo.encerrar_preparo()
	if pode_atacar():
		var tempos_diabo = intervalos_diabo_onda_alta if onda_alta else intervalos_diabo
		var tempos_paganini = intervalos_paganini_onda_alta if onda_alta else intervalos_paganini
		var atraso = atraso_paganini_onda_alta if onda_alta else atraso_paganini
		var parede = teto_ricochete if onda_alta else piso_ricochete
		var quiques_diabo = [0, 1] if onda_alta else [3]
		var quiques_paganini = [1] if onda_alta else [0]
		_movimentos_coreografados = [
			_tocar_glissando(diabo, paganini, percurso_diabo, tempos_diabo, 0.0, parede, quiques_diabo),
			_tocar_glissando(paganini, diabo, percurso_paganini, tempos_paganini, atraso, parede, quiques_paganini),
		]
		await _esperar_coreografia()
	_encerrar_coreografia()


func _tocar_glissando(
	atirador: Duelista, rival: Duelista, percurso: Vector2, intervalos: PackedFloat32Array,
	atraso: float, parede: CollisionShape2D, indices_ricochete: Array
) -> Tween:
	var movimento = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	if atraso > 0.0:
		movimento.tween_interval(atraso)
	var disparo = _disparar_glissando.bind(atirador, rival)
	var disparo_ricochete = _disparar_glissando.bind(atirador, rival, parede)
	movimento.tween_callback(disparo)
	if 0 in indices_ricochete:
		movimento.tween_callback(disparo_ricochete)
	for i in intervalos.size():
		var fracao = float(i + 1) / intervalos.size()
		var altura = lerpf(percurso.x, percurso.y, fracao)
		movimento.tween_property(atirador, "position:y", altura, maxf(0.01, intervalos[i]))
		movimento.tween_callback(disparo)
		if i + 1 in indices_ricochete:
			movimento.tween_callback(disparo_ricochete)
	return movimento


func _disparar_glissando(atirador: Duelista, rival: Duelista, parede: CollisionShape2D = null) -> void:
	if pode_atacar():
		var direcao = atirador.origem_tiro.global_position.direction_to(rival.origem_tiro.global_position)
		_disparar(atirador, rival, direcao, int(parede != null), parede)


func _ao_colidir_notas(primeira: ProjetilDuelo, segunda: ProjetilDuelo) -> void:
	if not pode_atacar():
		return
	var encontro = primeira.global_position.lerp(segunda.global_position, 0.5)
	_iniciar_dissonancia.call_deferred(encontro)


func _iniciar_dissonancia(encontro: Vector2) -> void:
	if pode_atacar():
		var dissonancia: Dissonancia = cena_dissonancia.instantiate()
		dissonancia.position = dissonancias.to_local(encontro)
		dissonancias.add_child(dissonancia)


func _esperar_coreografia() -> void:
	while pode_atacar() and _movimentos_coreografados.any(func(tween): return tween.is_running()):
		await esperar(0.03)


func _encerrar_coreografia() -> void:
	for tween in _movimentos_coreografados:
		tween.kill()
	_movimentos_coreografados.clear()
	paganini.movimento_coreografado = false
	diabo.movimento_coreografado = false
	paganini.encerrar_preparo()
	diabo.encerrar_preparo()
	aviso_pinball_piso.hide()
	aviso_pinball_curto.hide()


func _quatro_cordas() -> void:
	# Alterna Sol/Lá e Ré/Mi para que todas as faixas sejam tocadas.
	var selecionadas: Array[CordaDuelo] = [cordas[_primeira_corda], cordas[_primeira_corda + 2]]
	_primeira_corda = 1 - _primeira_corda
	for corda in selecionadas:
		corda.avisar()
	Audio.tocar("boss_conjura")
	await esperar(tempo_aviso_cordas)

	if pode_atacar():
		# As cordas são tocadas pelos dois ao mesmo tempo
		paganini.tocar_ataque()
		diabo.tocar_ataque()
		for corda in selecionadas:
			corda.pulsar()
		await esperar(duracao_pulso_cordas)
	for corda in selecionadas:
		corda.hide()


func _pinball_com_resposta() -> void:
	_pinball_alcancou_o_diabo = false
	var origem = paganini.origem_tiro.global_position
	var destino = Vector2(diabo.global_position.x, diabo.origem_tiro.global_position.y)
	var paredes: Array[CollisionShape2D] = [teto_ricochete, piso_ricochete, teto_ricochete, piso_ricochete]
	var direcao_teto = ProjetilDuelo.calcular_direcao_com_ricochetes(origem, destino, paredes, FormaPinball.radius)
	paredes.reverse()
	var direcao_piso = ProjetilDuelo.calcular_direcao_com_ricochetes(origem, destino, paredes, FormaPinball.radius)
	var paredes_curtas: Array[CollisionShape2D] = [teto_ricochete, piso_ricochete, teto_ricochete]
	var direcao_curta = ProjetilDuelo.calcular_direcao_com_ricochetes(origem, destino, paredes_curtas, FormaPinball.radius)
	paganini.preparar_tiro(_ponto_primeiro_quique(origem, direcao_teto, teto_ricochete))
	_mostrar_aviso_pinball(aviso_pinball_piso, origem, _ponto_primeiro_quique(origem, direcao_piso, piso_ricochete))
	_mostrar_aviso_pinball(aviso_pinball_curto, origem, _ponto_primeiro_quique(origem, direcao_curta, teto_ricochete))
	Audio.tocar("boss_conjura")
	await esperar(tempo_preparo)
	paganini.encerrar_preparo()
	aviso_pinball_piso.hide()
	aviso_pinball_curto.hide()
	if not pode_atacar():
		return

	_lancar_pinball(direcao_teto, paredes.size())
	_lancar_pinball(direcao_piso, paredes.size())
	_lancar_pinball(direcao_curta, paredes_curtas.size())

	await _esperar_projeteis()
	if _pinball_alcancou_o_diabo and pode_atacar():
		await _contratempo()


func _ponto_primeiro_quique(origem: Vector2, direcao: Vector2, parede: CollisionShape2D) -> Vector2:
	var altura = ProjetilDuelo.altura_ricochete(origem.y, parede, FormaPinball.radius)
	return origem + direcao * ((altura - origem.y) / direcao.y)


func _mostrar_aviso_pinball(aviso: Line2D, origem: Vector2, destino: Vector2) -> void:
	aviso.points = PackedVector2Array([aviso.to_local(origem), aviso.to_local(destino)])
	aviso.show()


func _lancar_pinball(direcao: Vector2, maximo_quiques: int) -> void:
	var bola = _preparar_projetil(paganini, diabo, cena_pinball)
	bola.velocidade = velocidade_pinball
	bola.direcao = direcao
	bola.maximo_quiques = maximo_quiques
	bola.alcancou_lateral.connect(func(): _pinball_alcancou_o_diabo = true)
	projeteis.add_child(bola)


func _contratempo() -> void:
	diabo.preparar_tiro(paganini.origem_tiro.global_position)
	Audio.tocar("boss_conjura")
	await esperar(tempo_preparo)
	diabo.encerrar_preparo()
	if not pode_atacar():
		return

	_disparar_leque_contratempo()

	diabo.movimento_coreografado = true
	var limites = diabo.limites_y
	var sentido = 1.0 if diabo.position.y < (limites.x + limites.y) * 0.5 else -1.0
	var destino_y = clampf(diabo.position.y + sentido * distancia_contratempo, limites.x, limites.y)
	var deslocamento = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	deslocamento.tween_property(diabo, "position:y", destino_y, tempo_deslocamento_contratempo)
	_movimentos_coreografados = [deslocamento]
	await _esperar_coreografia()

	if pode_atacar():
		diabo.preparar_tiro(paganini.origem_tiro.global_position)
		await esperar(aviso_segunda_salva)
		if pode_atacar():
			_disparar_leque_contratempo()
	_encerrar_coreografia()


func _disparar_leque_contratempo() -> void:
	const QUANTIDADE_NOTAS = 5
	var origem = diabo.origem_tiro.global_position
	var destino_y = paganini.origem_tiro.global_position.y
	for i in QUANTIDADE_NOTAS:
		var nota = _preparar_projetil(diabo, paganini, cena_contratempo) as ProjetilContratempo
		var raio = nota.raio_ricochete()
		var topo = ProjetilDuelo.altura_ricochete(origem.y, teto_ricochete, raio)
		var fundo = ProjetilDuelo.altura_ricochete(origem.y, piso_ricochete, raio)
		var fracao = float(i) / (QUANTIDADE_NOTAS - 1)
		nota.direcao = Vector2(signf(nota.limite_lateral - origem.x), 0.0)
		nota.destino_y = destino_y
		nota.controle_y = lerpf(topo, fundo, fracao)
		projeteis.add_child(nota)


func descansar() -> void:
	# O Boss base multiplica o descanso pelo ritmo. O segundo extra é inteiro em toda fase.
	var duracao_original = duracao_descanso
	duracao_descanso += tempo_extra_riff / ritmo()
	# O Boss base ajoelha o Diabo; o Paganini cai junto e levanta no fim
	var vai_descansar = pode_atacar() and not escudo_ativo
	if vai_descansar:
		paganini.stop()
		paganini.play(&"ajoelhar")
	await super.descansar()
	duracao_descanso = duracao_original
	if vai_descansar and vida_atual > 0:
		paganini.play(&"idle")


func _esperar_projeteis(esperar_dissonancias := false) -> void:
	while pode_atacar() and (
		projeteis.get_child_count() > 0 or (esperar_dissonancias and dissonancias.get_child_count() > 0)
	):
		await esperar(0.1)


func _leque(atirador: Duelista, rival: Duelista, simultaneo := false) -> void:
	if not pode_atacar():
		return
	var direcao = atirador.preparar_tiro(rival.origem_tiro.global_position)
	var direcao_rival := Vector2.ZERO
	if simultaneo:
		direcao_rival = rival.preparar_tiro(atirador.origem_tiro.global_position)
	Audio.tocar("boss_conjura")

	await esperar(tempo_preparo)
	atirador.encerrar_preparo()
	if simultaneo:
		rival.encerrar_preparo()
	if not pode_atacar():
		return
	_disparar_leque(atirador, rival, direcao)
	if simultaneo:
		_disparar_leque(rival, atirador, direcao_rival)


func _disparar_leque(atirador: Duelista, rival: Duelista, direcao: Vector2) -> void:
	var metade_abertura = deg_to_rad(atirador.abertura_leque * 0.5)
	var quantidade = atirador.tiros_por_leque
	for i in quantidade:
		var fracao = float(i) / (quantidade - 1) if quantidade > 1 else 0.5
		var angulo = lerpf(-metade_abertura, metade_abertura, fracao)
		_disparar(atirador, rival, direcao.rotated(angulo))


func _disparar(
	atirador: Duelista, rival: Duelista, direcao: Vector2,
	maximo_quiques := -1, parede: CollisionShape2D = null
) -> ProjetilDuelo:
	var projetil = _preparar_projetil(atirador, rival, cena_projetil)
	projetil.direcao = direcao
	if parede != null:
		projetil.direcao = projetil.direcao_com_ricochetes(
			atirador.origem_tiro.global_position, rival.origem_tiro.global_position, [parede]
		)
	if maximo_quiques >= 0:
		projetil.maximo_quiques = maximo_quiques
	projeteis.add_child(projetil)
	return projetil


func _preparar_projetil(atirador: Duelista, rival: Duelista, cena: PackedScene) -> ProjetilDuelo:
	atirador.tocar_ataque()
	var projetil: ProjetilDuelo = cena.instantiate()
	projetil.position = projeteis.to_local(atirador.origem_tiro.global_position)
	projetil.velocidade = atirador.velocidade_projetil
	projetil.modulate = atirador.cor_projetil
	projetil.limite_lateral = rival.global_position.x
	projetil.habilitar_dissonancia(atirador == paganini)
	projetil.encontro_de_notas.connect(_ao_colidir_notas)
	return projetil


func morrer() -> void:
	_encerrar_coreografia()
	for dissonancia in dissonancias.get_children():
		dissonancia.queue_free()
	for corda in cordas:
		corda.hide()
	for projetil in projeteis.get_children():
		projetil.queue_free()
	await super.morrer()


func _physics_process(_delta: float) -> void:
	var movimento_ativo = pode_atacar() and not descansando
	paganini.movimento_ativo = movimento_ativo
	diabo.movimento_ativo = movimento_ativo


func _ao_quebrar_runa() -> void:
	super._ao_quebrar_runa()
	if not escudo_ativo:
		diabo.self_modulate = _cor_diabo


func _sincronizar_derrota() -> void:
	if diabo.animation == &"death":
		diabo.self_modulate = _cor_diabo
		paganini.stop()
		paganini.play(&"death")
