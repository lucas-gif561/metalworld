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
## Na fase 1 o leque tem menos tiros na mesma abertura: sobram vãos largos
## para aprender a desviar. A partir da fase 2 vale o tiros_por_leque de cada um.
@export_range(1, 12) var tiros_leque_fase_1: int = 3
@export var tempo_extra_riff: float = 1.0
## Comprimento dos raios que avisam cada nota do leque
@export var alcance_aviso_leque: float = 320.0
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
## Tremor de tela quando as cordas são tangidas
@export var tremor_cordas: float = 4.0
## Quanto as cordas esperam depois que o ataque que elas acompanham começa
@export var atraso_cordas_junto: float = 0.3

@export_group("Troca de fase")
@export var tremor_fase: float = 9.0
@export_range(0.0, 1.0) var opacidade_flash_fase: float = 0.55
@export var duracao_flash_fase: float = 0.6

@export_group("Pinball")
@export var cena_pinball: PackedScene
@export var velocidade_pinball: float = 650.0
## Animação da orbe do pinball (sem ela, usa a nota do Paganini)
@export var frames_pinball: SpriteFrames
## Tamanho da orbe em relação à bola padrão (1 = mesmo tamanho na tela)
@export var escala_pinball: float = 1.9

@export_group("Contratempo")
@export var cena_contratempo: PackedScene
@export var distancia_contratempo: float = 110.0
@export var tempo_deslocamento_contratempo: float = 0.48
@export var aviso_segunda_salva: float = 0.32
## Notas em cada salva, espalhadas do teto ao piso. Poucas deixam vãos para
## passar entre elas.
@export_range(1, 9) var notas_contratempo: int = 3

@onready var paganini: Duelista = $AnimatedSprite2D
@onready var aviso_pinball_piso: Line2D = $AnimatedSprite2D/AvisoPinballPiso
@onready var aviso_pinball_curto: Line2D = $AnimatedSprite2D/AvisoPinballCurto
@onready var diabo: Duelista = $Diabo
@onready var _cor_diabo: Color = diabo.self_modulate
@onready var projeteis: Node2D = $Projeteis
@onready var cordas: Array[Node] = $Cordas.get_children()
@onready var dissonancias: Node2D = $Dissonancias
## Cada ataque tem um aviso com cara própria (os modelos ficam em Avisos/Modelos)
@onready var avisos: Node2D = $Avisos
@onready var _modelos_aviso: Node2D = $Avisos/Modelos
## Clarão na tela inteira quando o duelo muda de fase
@onready var flash_fase: ColorRect = $FlashFase

var _staccato_alcancou_o_diabo := false
var _pinball_alcancou_o_diabo := false
var _movimentos_coreografados: Array[Tween] = []
var _primeira_corda := 0
var _cordas_tocando := false
var _raio_contratempo := 0.0


func _ready() -> void:
	# A vida é compartilhada, mas é o Diabo que reage aos acertos do Riff.
	sprite = diabo
	super._ready()
	paganini.rival = diabo
	diabo.rival = paganini
	diabo.animation_changed.connect(_sincronizar_derrota)
	derrotado.connect(hide)
	fase_avancou.connect(_ao_avancar_fase)
	# O aviso do Contratempo desenha as curvas antes de as notas existirem
	var modelo_nota = cena_contratempo.instantiate()
	_raio_contratempo = modelo_nota.raio_ricochete()
	modelo_nota.free()


func ciclo_ataques() -> void:
	await esperar(2.0)
	while pode_atacar():
		await _sequencia_de_ataques(fase)
		await descansar()
		await esperar_no_ritmo(intervalo_entre_duelos)


## Ordem dos ataques entre um descanso e outro: [ataque, fase mínima, fase a
## partir da qual as Quatro Cordas tocam junto (0 = nunca)]. As cordas não têm
## vez própria: vibram enquanto o outro ataque acontece.
const ROTEIRO = [
	["leque", 1, 0],
	["pinball", 1, 3],
	["leque", 1, 0],
	["staccato", 1, 2],
	["leque", 2, 0],
	["pinball", 3, 0],
]


func _sequencia_de_ataques(fase_da_sequencia: int) -> void:
	var primeiro := true
	for passo in ROTEIRO:
		if fase_da_sequencia < passo[1]:
			continue
		if not pode_atacar():
			return
		if not primeiro:
			await esperar_no_ritmo(intervalo_entre_ataques)
			if not pode_atacar():
				return
		primeiro = false

		if passo[2] > 0 and fase_da_sequencia >= passo[2]:
			_cordas_junto() # sem await: as cordas correm em paralelo ao ataque
		await _executar(passo[0], fase_da_sequencia)
		await _esperar_projeteis(true)
		while _cordas_tocando and pode_atacar():
			await esperar(0.05)


func _executar(nome: String, fase_da_sequencia: int) -> void:
	match nome:
		"leque":
			await _duelo_de_leques(fase_da_sequencia >= 2)
		"staccato":
			await _staccato_com_resposta()
		"pinball":
			await _pinball_com_resposta()


## Toca as Quatro Cordas por cima do ataque em andamento. O atraso faz o pulso
## cair quando os tiros já estão no meio da arena.
func _cordas_junto() -> void:
	_cordas_tocando = true
	await esperar(atraso_cordas_junto)
	if pode_atacar():
		await _quatro_cordas()
	_cordas_tocando = false


func _duelo_de_leques(simultaneo: bool) -> void:
	await _leque(paganini, diabo, simultaneo)
	if not simultaneo and pode_atacar():
		await esperar(maxf(0.0, intervalo_resposta - tempo_preparo))
		await _leque(diabo, paganini)


func _staccato_com_resposta() -> void:
	_staccato_alcancou_o_diabo = false
	var direcao_diabo = diabo.preparar_tiro(paganini.origem_tiro.global_position, false)
	var direcoes_diabo: Array[Vector2] = []
	for angulo in angulos_leque_diabo:
		direcoes_diabo.append(direcao_diabo.rotated(deg_to_rad(angulo)))
	var aviso_diabo = _aviso_leque(diabo, direcoes_diabo)
	var aviso_paganini: Line2D = null
	Audio.tocar("boss_conjura")
	for i in 3:
		var direcao = paganini.preparar_tiro(diabo.origem_tiro.global_position, false)
		if aviso_paganini == null:
			aviso_paganini = _aviso_staccato(paganini, diabo)
		else:
			_apontar_aviso(aviso_paganini, paganini.origem_tiro.global_position, diabo.origem_tiro.global_position)
		await esperar(tempo_preparo if i == 0 else intervalo_staccato)
		if not pode_atacar():
			break
		var projetil = _disparar(paganini, diabo, direcao, 0)
		projetil.alcancou_lateral.connect(_ao_staccato_alcancar_o_diabo)
		if i == 0:
			diabo.encerrar_preparo()
			_apagar_avisos(aviso_diabo)
			for direcao_nota in direcoes_diabo:
				_disparar(diabo, paganini, direcao_nota, 1)
	paganini.encerrar_preparo()
	diabo.encerrar_preparo()
	_apagar_avisos(aviso_diabo + [aviso_paganini])

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
	var trilhos = [_aviso_glissando(paganini, percurso_paganini), _aviso_glissando(diabo, percurso_diabo)]
	await _esperar_coreografia()
	if not pode_atacar():
		_encerrar_coreografia()
		return

	diabo.preparar_tiro(paganini.origem_tiro.global_position, false)
	paganini.preparar_tiro(diabo.origem_tiro.global_position, false)
	Audio.tocar("boss_conjura")
	await esperar(tempo_preparo)
	paganini.encerrar_preparo()
	diabo.encerrar_preparo()
	_apagar_avisos(trilhos)
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
	_limpar_avisos()


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
		Combate.tremer(tremor_cordas)
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
	var bola = _preparar_projetil(paganini, diabo, cena_pinball, frames_pinball)
	bola.velocidade = velocidade_pinball
	bola.direcao = direcao
	bola.maximo_quiques = maximo_quiques
	bola.alcancou_lateral.connect(func(): _pinball_alcancou_o_diabo = true)
	projeteis.add_child(bola)


func _contratempo() -> void:
	diabo.preparar_tiro(paganini.origem_tiro.global_position, false)
	var salva = _mirar_contratempo()
	Audio.tocar("boss_conjura")
	await esperar(tempo_preparo)
	diabo.encerrar_preparo()
	_apagar_avisos(salva.avisos)
	if not pode_atacar():
		return

	_disparar_leque_contratempo(salva)

	diabo.movimento_coreografado = true
	var limites = diabo.limites_y
	var sentido = 1.0 if diabo.position.y < (limites.x + limites.y) * 0.5 else -1.0
	var destino_y = clampf(diabo.position.y + sentido * distancia_contratempo, limites.x, limites.y)
	var deslocamento = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	deslocamento.tween_property(diabo, "position:y", destino_y, tempo_deslocamento_contratempo)
	_movimentos_coreografados = [deslocamento]
	await _esperar_coreografia()

	if pode_atacar():
		diabo.preparar_tiro(paganini.origem_tiro.global_position, false)
		salva = _mirar_contratempo()
		await esperar(aviso_segunda_salva)
		_apagar_avisos(salva.avisos)
		if pode_atacar():
			_disparar_leque_contratempo(salva)
	_encerrar_coreografia()


## Calcula as curvas da salva e desenha cada uma: o aviso mostra os vãos para
## passar entre as notas. A salva sai exatamente pelas curvas avisadas.
func _mirar_contratempo() -> Dictionary:
	var origem = diabo.origem_tiro.global_position
	var destino_y = paganini.origem_tiro.global_position.y
	var limite_x = paganini.global_position.x
	var topo = ProjetilDuelo.altura_ricochete(origem.y, teto_ricochete, _raio_contratempo)
	var fundo = ProjetilDuelo.altura_ricochete(origem.y, piso_ricochete, _raio_contratempo)
	var controles: Array[float] = []
	var linhas: Array = []
	for i in notas_contratempo:
		var fracao = float(i) / (notas_contratempo - 1) if notas_contratempo > 1 else 0.5
		var controle_y = lerpf(topo, fundo, fracao)
		controles.append(controle_y)
		# Mesma curva do projetil_contratempo.gd
		var pontos: Array[Vector2] = []
		for passo in 17:
			var t = passo / 16.0
			var y = lerpf(lerpf(origem.y, controle_y, t), lerpf(controle_y, destino_y, t), t)
			pontos.append(Vector2(lerpf(origem.x, limite_x, t), y))
		linhas.append(_novo_aviso("Contratempo", diabo.cor_projetil, pontos))
	return {"destino_y": destino_y, "controles": controles, "avisos": linhas}


func _disparar_leque_contratempo(salva: Dictionary) -> void:
	var origem = diabo.origem_tiro.global_position
	for controle_y in salva.controles:
		var nota = _preparar_projetil(diabo, paganini, cena_contratempo) as ProjetilContratempo
		nota.direcao = Vector2(signf(nota.limite_lateral - origem.x), 0.0)
		nota.destino_y = salva.destino_y
		nota.controle_y = controle_y
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
	var direcoes = _direcoes_leque(atirador, atirador.preparar_tiro(rival.origem_tiro.global_position, false))
	var linhas = _aviso_leque(atirador, direcoes)
	var direcoes_rival: Array[Vector2] = []
	if simultaneo:
		direcoes_rival = _direcoes_leque(rival, rival.preparar_tiro(atirador.origem_tiro.global_position, false))
		linhas += _aviso_leque(rival, direcoes_rival)
	Audio.tocar("boss_conjura")

	await esperar(tempo_preparo)
	atirador.encerrar_preparo()
	if simultaneo:
		rival.encerrar_preparo()
	_apagar_avisos(linhas)
	if not pode_atacar():
		return
	for direcao in direcoes:
		_disparar(atirador, rival, direcao)
	for direcao in direcoes_rival:
		_disparar(rival, atirador, direcao)


func _direcoes_leque(atirador: Duelista, direcao: Vector2) -> Array[Vector2]:
	var metade_abertura = deg_to_rad(atirador.abertura_leque * 0.5)
	var quantidade = atirador.tiros_por_leque
	if fase == 1:
		quantidade = mini(quantidade, tiros_leque_fase_1)
	var direcoes: Array[Vector2] = []
	for i in quantidade:
		var fracao = float(i) / (quantidade - 1) if quantidade > 1 else 0.5
		direcoes.append(direcao.rotated(lerpf(-metade_abertura, metade_abertura, fracao)))
	return direcoes


# ---------------------------------------------------------------- Avisos

## Copia um modelo de Avisos/Modelos e o desenha pelos pontos (globais).
## A cor é a de quem atira, que muda a cada ataque, por isso vem do código.
func _novo_aviso(modelo: String, cor: Color, pontos: Array) -> Line2D:
	var linha: Line2D = _modelos_aviso.get_node(modelo).duplicate()
	linha.modulate = cor
	for ponto in pontos:
		linha.add_point(avisos.to_local(ponto))
	avisos.add_child(linha)
	return linha


func _apontar_aviso(linha: Line2D, origem: Vector2, destino: Vector2) -> void:
	linha.points = PackedVector2Array([avisos.to_local(origem), avisos.to_local(destino)])


## Leque: um raio curto para cada nota, mostrando os vãos entre elas
func _aviso_leque(atirador: Duelista, direcoes: Array[Vector2]) -> Array:
	var origem = atirador.origem_tiro.global_position
	var linhas: Array = []
	for direcao in direcoes:
		linhas.append(_novo_aviso("Leque", atirador.cor_projetil, [origem, origem + direcao * alcance_aviso_leque]))
	return linhas


## Staccato: linha grossa que pisca no tempo das três notas
func _aviso_staccato(atirador: Duelista, rival: Duelista) -> Line2D:
	var linha = _novo_aviso(
		"Staccato", atirador.cor_projetil, [atirador.origem_tiro.global_position, rival.origem_tiro.global_position]
	)
	var piscar = linha.create_tween().set_loops()
	piscar.tween_property(linha, "modulate:a", 0.25, intervalo_staccato * 0.5)
	piscar.tween_property(linha, "modulate:a", 1.0, intervalo_staccato * 0.5)
	return linha


## Glissando: trilho na coluna do duelista, com seta para onde ele vai tocando
func _aviso_glissando(atirador: Duelista, percurso: Vector2) -> Line2D:
	var x = atirador.origem_tiro.global_position.x
	var pai = atirador.get_parent() as Node2D
	var inicio = Vector2(x, pai.to_global(Vector2(0.0, percurso.x)).y)
	var fim = Vector2(x, pai.to_global(Vector2(0.0, percurso.y)).y)
	var volta = Vector2(0.0, -signf(fim.y - inicio.y) * 18.0)
	return _novo_aviso(
		"Glissando", atirador.cor_projetil,
		[inicio, fim, fim + volta + Vector2(-14.0, 0.0), fim, fim + volta + Vector2(14.0, 0.0)]
	)


func _apagar_avisos(linhas: Array) -> void:
	for linha in linhas:
		if is_instance_valid(linha):
			linha.queue_free()


func _limpar_avisos() -> void:
	for filho in avisos.get_children():
		if filho != _modelos_aviso:
			filho.queue_free()


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


func _preparar_projetil(
	atirador: Duelista, rival: Duelista, cena: PackedScene, frames: SpriteFrames = null
) -> ProjetilDuelo:
	atirador.tocar_ataque()
	var projetil: ProjetilDuelo = cena.instantiate()
	projetil.position = projeteis.to_local(atirador.origem_tiro.global_position)
	projetil.velocidade = atirador.velocidade_projetil
	var animacao = frames if frames != null else atirador.frames_projetil
	if animacao != null:
		var escala = escala_pinball if frames == frames_pinball and frames != null else atirador.escala_projetil
		_aplicar_animacao_do_tiro(projetil, animacao, atirador, escala)
	else:
		projetil.modulate = atirador.cor_projetil
		_aplicar_desenho_do_tiro(projetil, atirador)
	projetil.limite_lateral = rival.global_position.x
	projetil.habilitar_dissonancia(atirador == paganini)
	projetil.encontro_de_notas.connect(_ao_colidir_notas)
	return projetil


## Troca a bola padrão pela nota de quem atira. O tamanho acompanha a escala
## que cada cena de projétil dá à bola (o pinball é maior), então muda durante
## a partida conforme o tiro e fica em código.
func _aplicar_desenho_do_tiro(projetil: ProjetilDuelo, atirador: Duelista) -> void:
	if atirador.textura_projetil == null:
		return
	var desenho: Sprite2D = projetil.get_node("Sprite2D")
	var largura_antiga = desenho.texture.get_width() * desenho.scale.x
	desenho.texture = atirador.textura_projetil
	desenho.scale = Vector2.ONE * largura_antiga * atirador.escala_projetil / atirador.textura_projetil.get_width()


## Troca a bola padrão pela animação do tiro (nota ou orbe), já colorida na arte.
## A cor de quem atira vai só para as faíscas e o rastro. O tamanho segue a
## escala que cada cena de projétil dá à bola, por isso fica em código.
func _aplicar_animacao_do_tiro(
	projetil: ProjetilDuelo, frames: SpriteFrames, atirador: Duelista, escala: float
) -> void:
	var bola: Sprite2D = projetil.get_node("Sprite2D")
	var animacao: AnimatedSprite2D = projetil.get_node("Animacao")
	var largura_antiga = bola.texture.get_width() * bola.scale.x
	var largura_quadro = frames.get_frame_texture(&"default", 0).get_width()
	animacao.sprite_frames = frames
	animacao.scale = Vector2.ONE * largura_antiga * escala / largura_quadro
	animacao.play(&"default")
	# Cada nota começa num quadro diferente para a rajada não piscar em uníssono
	animacao.frame = randi() % frames.get_frame_count(&"default")
	animacao.show()
	bola.hide()
	projetil.get_node("Faiscas").modulate = atirador.cor_projetil
	if projetil.has_node("Rastro"):
		projetil.get_node("Rastro").modulate = atirador.cor_projetil


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


## Troca de fase: clarão, tremor forte e os dois duelistas piscam na cor do tiro
func _ao_avancar_fase() -> void:
	Combate.tremer(tremor_fase, 0.45)
	var clarao = create_tween()
	flash_fase.modulate.a = opacidade_flash_fase
	clarao.tween_property(flash_fase, "modulate:a", 0.0, duracao_flash_fase)
	for duelista in [paganini, diabo]:
		var brilho = create_tween()
		duelista.modulate = Color(2.0, 2.0, 2.0)
		brilho.tween_property(duelista, "modulate", Color.WHITE, duracao_flash_fase)


func _sincronizar_derrota() -> void:
	if diabo.animation == &"death":
		diabo.self_modulate = _cor_diabo
		paganini.stop()
		paganini.play(&"death")
