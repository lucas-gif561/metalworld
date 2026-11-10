extends Node2D

signal vida_atualizada(vida)
signal derrotado
signal anuncio(texto)
signal desafinar(duracao)
signal fase_avancou
signal dano_recebido(valor)

# Ordem dos ataques: [nome, fase mínima, pausa depois]
const ROTEIRO = [
	["rajada", 1, 2.0],
	["trilha", 1, 1.5],
	["leque", 1, 2.0],
	["bomba", 1, 1.5],
	["descanso", 1, 1.0],
	["espiral", 2, 1.5],
	["desafina", 2, 0.5],
	["corredor", 2, 2.0],
	["capangas", 2, 1.5],
	["teleporte", 2, 0.3],
	["escudo", 3, 1.0],
	["area", 1, 5.0],
	["descanso", 1, 1.0],
]

# Interruptor de cada ataque novo. Os que não estão aqui são os originais.
const INTERRUPTORES = {
	"trilha": "usar_trilha",
	"bomba": "usar_bomba",
	"espiral": "usar_espiral",
	"desafina": "usar_desafino",
	"corredor": "usar_corredor",
	"capangas": "usar_capangas",
	"teleporte": "usar_teleporte",
	"escudo": "usar_escudo",
	"descanso": "usar_descanso",
}

const DURACAO_DESCANSO = 4.0

const PONTOS_TELEPORTE = [Vector2(470, 150), Vector2(576, 160), Vector2(682, 150)]
const PONTOS_RUNA = [Vector2(220, 340), Vector2(932, 340), Vector2(576, 400)]
const PONTOS_CAPANGA = [Vector2(220, 300), Vector2(932, 300)]
const MAXIMO_CAPANGAS = 3
const COR_ESCUDO = Color(0.5, 0.8, 1.0)

@export var cena_ataque_area: PackedScene
@export var cena_projetil: PackedScene
@export var cena_granada: PackedScene
@export var cena_capanga: PackedScene
@export var cena_runa: PackedScene
@export var cena_particulas: PackedScene
@export var jogador: Node2D
@export var vida_maxima: int = 100

@export_group("Novidades")
@export var novidades_ativas := true
@export var vida_com_novidades: int = 200
@export var usar_fases := true
@export var usar_punicao_miss := true
@export var usar_escudo := true
@export var usar_trilha := true
@export var usar_corredor := true
@export var usar_bomba := true
@export var usar_espiral := true
@export var usar_desafino := true
@export var usar_nota_maldita := true
@export var usar_capangas := true
@export var usar_teleporte := true
@export var usar_descanso := true
@export var usar_riff_forte := true
@export var usar_cabo_de_forca := true
@export var perfects_por_fase: int = 6
@export var goods_por_fase: int = 9

@onready var sprite = $AnimatedSprite2D
@onready var sinal_riff = $SinalRiff

var atacando: bool = false
var vida_atual: int
var vida_referencia: int
var fase: int = 1
var escudo_ativo: bool = false
var runas_restantes: int = 0
var proxima_punicao_ms: int = 0
var tween_teleporte: Tween
var tween_sinal: Tween
var descansando: bool = false


func _ready() -> void:
	if novidades_ativas:
		vida_maxima = vida_com_novidades
	vida_atual = vida_maxima
	vida_referencia = vida_maxima
	sprite.animation_finished.connect(_ao_terminar_animacao)


func recurso_ativo(interruptor: bool) -> bool:
	return novidades_ativas and interruptor


# No cabo de força o boss começa no meio da barra; as fases contam a partir daí
func iniciar_cabo_de_forca() -> void:
	vida_atual = vida_maxima / 2
	vida_referencia = vida_atual
	vida_atualizada.emit(vida_atual)


func curar(valor: int) -> void:
	if vida_atual <= 0:
		return

	vida_atual = mini(vida_atual + valor, vida_maxima)
	vida_atualizada.emit(vida_atual)


func receber_dano(valor: int):
	if vida_atual <= 0 or escudo_ativo:
		return
	var vida_antes = vida_atual
	vida_atual = max(vida_atual - valor, 0)
	vida_atualizada.emit(vida_atual)
	dano_recebido.emit(vida_antes - vida_atual)

	if vida_atual <= 0:
		morrer()
		return

	sprite.stop()
	sprite.play("hurt")
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_atualizar_fase()


func _atualizar_fase():
	if not recurso_ativo(usar_fases):
		return

	var porcentagem = float(vida_atual) / vida_referencia
	var nova_fase = 1 if porcentagem > 0.66 else (2 if porcentagem > 0.33 else 3)

	if nova_fase > fase:
		fase = nova_fase
		if not _ativar_escudo("FASE %d! " % fase):
			anuncio.emit("FASE %d! O boss enfureceu!" % fase)
		fase_avancou.emit()


func morrer():
	atacando = false
	_encerrar_descanso()
	if tween_teleporte:
		tween_teleporte.kill()
	modulate.a = 1.0
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE

	for capanga in get_tree().get_nodes_in_group("capangas"):
		capanga.queue_free()

	Audio.tocar("granada", 0.0)
	sprite.stop()
	sprite.play("death")
	await sprite.animation_finished
	derrotado.emit()


func _ao_terminar_animacao():
	if vida_atual > 0:
		sprite.play("descanso" if descansando else "idle")


func _conjurar():
	Audio.tocar("boss_conjura")
	sprite.stop()
	sprite.play("cast")


func pode_atacar() -> bool:
	return vida_atual > 0 and jogador_vivo()


func jogador_vivo() -> bool:
	return is_instance_valid(jogador) and jogador.vida > 0


func _ritmo() -> float:
	if not recurso_ativo(usar_fases):
		return 1.0
	return [1.0, 0.8, 0.6][fase - 1]


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos * _ritmo()).timeout


func _passo_disponivel(passo: Array) -> bool:
	var interruptor = INTERRUPTORES.get(passo[0], "")

	if interruptor == "":
		return true

	if not recurso_ativo(get(interruptor)):
		return false

	return not recurso_ativo(usar_fases) or fase >= passo[1]


func ciclo_ataques():
	await get_tree().create_timer(2.0).timeout

	while pode_atacar():
		for passo in ROTEIRO:
			if not pode_atacar():
				return

			if _passo_disponivel(passo):
				await _executar(passo[0])
				await _esperar(_pausa_do_passo(passo))


# O descanso que vem depois da área já cumpre o papel da pausa longa
func _pausa_do_passo(passo: Array) -> float:
	if passo[0] == "area" and recurso_ativo(usar_descanso):
		return 1.0

	return passo[2]


func _executar(nome: String) -> void:
	match nome:
		"descanso":
			await _descansar()
		"rajada":
			await iniciar_rajada()
		"leque":
			await _leque_triplo()
		"area":
			await _area_quadrupla()
		"trilha":
			await _trilha_sigilos()
		"bomba":
			_bomba_sigilo()
		"espiral":
			await _chuva_espiral()
		"desafina":
			desafinar.emit(5.0)
		"corredor":
			await _corredor_da_morte()
		"capangas":
			_invocar_capangas()
		"teleporte":
			await _teleporte()
		"escudo":
			_ativar_escudo("")


# ATAQUES ORIGINAIS

func iniciar_rajada():
	if atacando or cena_projetil == null or not pode_atacar():
		return

	atacando = true

	for i in range(6):
		if not pode_atacar():
			break

		_conjurar()
		_criar_projetil((jogador.global_position - global_position).normalized())

		await get_tree().create_timer(0.4).timeout

	atacando = false


func ataque_leque():
	if atacando or cena_projetil == null or not pode_atacar():
		return

	_conjurar()

	var direcao_central = (jogador.global_position - global_position).normalized()

	for angulo in [-40, -20, 0, 20, 40]:
		_criar_projetil(direcao_central.rotated(deg_to_rad(angulo)))


func _leque_triplo():
	for i in range(3):
		if not pode_atacar():
			return

		ataque_leque()

		if i < 2:
			await _esperar(0.7)


func _criar_projetil(direcao: Vector2):
	var projetil = cena_projetil.instantiate()
	get_parent().add_child(projetil)
	projetil.global_position = global_position
	projetil.direcao = direcao


func ataque_area():
	if atacando or cena_ataque_area == null or not pode_atacar():
		return

	atacando = true
	_conjurar()

	var area = cena_ataque_area.instantiate()
	get_parent().add_child(area)

	area.global_position = jogador.global_position

	await get_tree().create_timer(1.5).timeout

	atacando = false


func _area_quadrupla():
	for i in range(4):
		if not pode_atacar():
			return

		await ataque_area()

		if i < 3:
			await _esperar(0.5)


# ATAQUES NOVOS

func _criar_sigilo(posicao: Vector2, dano: int, tempo_aviso: float):
	var area = cena_ataque_area.instantiate()
	area.dano = dano
	area.tempo_aviso = tempo_aviso
	area.position = posicao
	get_parent().add_child(area)


func _trilha_sigilos():
	for i in range(6):
		if not pode_atacar():
			return

		_conjurar()
		_criar_sigilo(jogador.global_position, 1, 0.9)
		await get_tree().create_timer(0.3).timeout


func _corredor_da_morte():
	var colunas = [110, 300, 490, 680, 870, 1060]

	# Começa no lado oposto ao jogador e varre na direção dele
	if jogador.global_position.x < global_position.x:
		colunas.reverse()

	var linhas = [120, 205, 290, 375, 460, 545]

	for x in colunas:
		if not pode_atacar():
			return

		_conjurar()
		var buraco = randi_range(2, linhas.size() - 1)

		for i in range(linhas.size()):
			if i != buraco:
				_criar_sigilo(Vector2(x, linhas[i]), 2, 1.0)

		await get_tree().create_timer(0.8).timeout


func _bomba_sigilo():
	if cena_granada == null or not pode_atacar():
		return

	_conjurar()

	var alvo = jogador.global_position
	var granada = cena_granada.instantiate()
	granada.direcao = global_position.direction_to(alvo)
	granada.alcance = global_position.distance_to(alvo)
	granada.dano = 2
	get_parent().add_child(granada)
	granada.global_position = global_position


func _chuva_espiral():
	_conjurar()

	for i in range(40):
		if not pode_atacar():
			return

		var angulo = deg_to_rad(i * 25.0)
		_criar_projetil(Vector2.RIGHT.rotated(angulo))
		_criar_projetil(Vector2.LEFT.rotated(angulo))
		await get_tree().create_timer(0.08).timeout


func _invocar_capangas():
	if cena_capanga == null:
		return

	_conjurar()
	var vivos = get_tree().get_nodes_in_group("capangas").size()

	for ponto in PONTOS_CAPANGA:
		if vivos >= MAXIMO_CAPANGAS:
			return

		# Dois corpos exatamente no mesmo ponto travam na física
		var nascimento = ponto + Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
		var capanga = cena_capanga.instantiate()
		capanga.add_to_group("capangas")
		capanga.position = nascimento
		get_parent().add_child(capanga)
		_criar_particulas(nascimento)
		vivos += 1


func _criar_particulas(posicao: Vector2):
	if cena_particulas == null:
		return

	var particulas = cena_particulas.instantiate()
	particulas.position = posicao
	particulas.finished.connect(particulas.queue_free)
	get_parent().add_child(particulas)


func _teleporte():
	var destinos = PONTOS_TELEPORTE.filter(func(p): return p.distance_to(global_position) > 1.0)

	Audio.tocar("teleporte")
	_criar_particulas(global_position)
	tween_teleporte = create_tween()
	tween_teleporte.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween_teleporte.finished

	global_position = destinos.pick_random()
	_criar_particulas(global_position)

	tween_teleporte = create_tween()
	tween_teleporte.tween_property(self, "modulate:a", 1.0, 0.25)
	await tween_teleporte.finished


# DESCANSO: janela segura para entrar no Riff

func _descansar():
	# Com escudo as notas não ferem, então o sinal enganaria o jogador
	if escudo_ativo or not pode_atacar():
		return

	descansando = true
	sprite.stop()
	sprite.play("ajoelhar")
	sinal_riff.modulate.a = 1.0
	sinal_riff.show()

	tween_sinal = create_tween().set_loops()
	tween_sinal.tween_property(sinal_riff, "modulate:a", 0.35, 0.3)
	tween_sinal.tween_property(sinal_riff, "modulate:a", 1.0, 0.3)

	var restante = DURACAO_DESCANSO * _ritmo()

	while restante > 0.0 and pode_atacar() and not escudo_ativo:
		await get_tree().process_frame

		if not is_inside_tree():
			return

		restante -= get_process_delta_time()

	_encerrar_descanso()

	if vida_atual > 0:
		sprite.play("idle")


func _encerrar_descanso():
	descansando = false
	sinal_riff.hide()

	if tween_sinal:
		tween_sinal.kill()


# ESCUDO

# Retorna true se o escudo foi ativado agora
func _ativar_escudo(prefixo: String) -> bool:
	if not recurso_ativo(usar_escudo) or escudo_ativo or cena_runa == null:
		return false

	escudo_ativo = true
	Audio.tocar("escudo", 0.0)
	runas_restantes = PONTOS_RUNA.size()
	sprite.self_modulate = COR_ESCUDO

	for ponto in PONTOS_RUNA:
		var runa = cena_runa.instantiate()
		runa.position = ponto
		runa.quebrada.connect(_ao_quebrar_runa)
		get_parent().add_child(runa)

	anuncio.emit(prefixo + "Escudo ativo! Quebre as runas no tiro (ESPAÇO)")
	return true


func _ao_quebrar_runa():
	runas_restantes -= 1

	if runas_restantes <= 0:
		escudo_ativo = false
		sprite.self_modulate = Color.WHITE
		anuncio.emit("Escudo quebrado! Volte ao Riff!")


# RIFF

# Dano ajustado para uma sessão bem-sucedida valer uma fase inteira
func dano_da_nota(perfect: bool) -> int:
	if not recurso_ativo(usar_riff_forte):
		return 3 if perfect else 1

	# 34% é a maior fatia entre as fases (de 100% até 66%)
	var fatia = vida_referencia * 0.34
	return ceili(fatia / (perfects_por_fase if perfect else goods_por_fase))


func punir_miss():
	if not recurso_ativo(usar_punicao_miss) or not pode_atacar() or cena_projetil == null:
		return

	var agora = Time.get_ticks_msec()

	if agora < proxima_punicao_ms:
		return

	proxima_punicao_ms = agora + 500
	_criar_projetil(global_position.direction_to(jogador.global_position))


func nota_maldita_disponivel() -> bool:
	if not recurso_ativo(usar_nota_maldita):
		return false

	return not recurso_ativo(usar_fases) or fase >= 2
