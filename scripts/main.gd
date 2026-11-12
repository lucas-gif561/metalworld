extends Node2D

@export var quantidade_arenas = 3
@export var duracao_transicao = 0.8
@export var margem_superior = 280.0
@export var margem_inferior = 123.0
@onready var player = $Player
@onready var camera = $Camera2D
@onready var enemy_manager = $EnemyManager
@onready var portal = $Portal
@onready var hud = $HudJogo

@export_group("Combo e solo")
@export var tempo_combo = 2.0
@export var carga_solo_maxima = 100.0
@export var cena_onda_solo: PackedScene


var fase_concluida = false
var combo = 0
var maior_combo = 0
var combo_expira_ms = 0
var dano_na_arena = 0.0
var ultima_nota = ""
var carga_solo = 0.0
var arena_atual = 1
var em_transicao = false
var largura_tela = 0.0
var altura_tela = 0.0

func _ready():
	largura_tela = get_viewport_rect().size.x / camera.zoom.x
	altura_tela = get_viewport_rect().size.y / camera.zoom.y

	Audio.tocar_musica("ruas")
	hud.conectar_jogador(player)
	player.morreu.connect(_ao_jogador_morrer)
	enemy_manager.onda_iniciada.connect(_ao_iniciar_onda)
	enemy_manager.arena_concluida.connect(_ao_concluir_arena)
	Combate.acerto.connect(_ao_acertar)
	player.dano_sofrido.connect(_ao_sofrer_dano)
	hud.mostrar_solo(true)
	hud.atualizar_solo(carga_solo, carga_solo_maxima)


func _ao_iniciar_onda(arena, onda, total_ondas):
	hud.definir_progresso("ARENA %d/%d  ·  ONDA %d/%d" % [arena, quantidade_arenas, onda, total_ondas])

	if onda == 1:
		dano_na_arena = 0.0
		maior_combo = 0


func _ao_concluir_arena():
	ultima_nota = calcular_nota()

	if arena_atual < quantidade_arenas:
		hud.mostrar_aviso("NOTA %s  ·  Área limpa! Siga para a direita  →" % ultima_nota)


# COMBO E NOTA

func _ao_acertar(carga):
	combo += 1
	maior_combo = maxi(maior_combo, combo)
	combo_expira_ms = Time.get_ticks_msec() + int(tempo_combo * 1000.0)
	hud.mostrar_combo(combo)
	carga_solo = minf(carga_solo + carga, carga_solo_maxima)
	hud.atualizar_solo(carga_solo, carga_solo_maxima)


func _ao_sofrer_dano(valor):
	dano_na_arena += valor
	_zerar_combo()


func _zerar_combo():
	combo = 0
	hud.esconder_combo()


func calcular_nota() -> String:
	if dano_na_arena == 0 and maior_combo >= 10:
		return "S"
	if dano_na_arena <= 1 and maior_combo >= 6:
		return "A"
	if dano_na_arena <= 3:
		return "B"
	return "C"


# SOLO DE GUITARRA: com a barra cheia, atordoa todos na tela

func solo_de_guitarra():
	carga_solo = 0.0
	hud.atualizar_solo(carga_solo, carga_solo_maxima)
	Audio.tocar("vitoria", 0.0)
	Combate.tremer(14.0, 0.4)
	Combate.pausar(0.08)
	hud.piscar_tela()

	if cena_onda_solo:
		var onda = cena_onda_solo.instantiate()
		onda.position = player.global_position
		onda.finished.connect(onda.queue_free)
		add_child(onda)

	var area = limites_arena().grow(80.0)

	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not alvo.has_method("atordoar") or alvo.morto or not area.has_point(alvo.global_position):
			continue

		var direcao = player.global_position.direction_to(alvo.global_position)
		alvo.empurrar(direcao * 1000.0)
		alvo.receber_dano(1)
		alvo.atordoar(2.5)


func _ao_jogador_morrer():
	Audio.parar_musica()
	hud.mostrar_fim("GAME OVER", "Pressione R para tentar de novo", Color(1, 0.25, 0.25))


func _process(_delta):
	if combo > 0 and Time.get_ticks_msec() >= combo_expira_ms:
		_zerar_combo()

	if em_transicao or player.vida <= 0:
		return

	# VERIFICAR FIM DA FASE
	if not fase_concluida and arena_atual == quantidade_arenas and enemy_manager.arena_liberada:
		concluir_fase()

	# LIMITES DA ARENA
	var limites = limites_arena()

	player.global_position.y = clampf(
		player.global_position.y,
		limites.position.y,
		limites.end.y
	)

	# LIMITE ESQUERDO
	if player.global_position.x < limites.position.x:
		player.global_position.x = limites.position.x

	# LIMITE DIREITO
	if player.global_position.x >= limites.end.x:
		player.global_position.x = limites.end.x

		if arena_atual < quantidade_arenas and enemy_manager.arena_liberada:
			proxima_arena()


func limites_arena() -> Rect2:
	var esquerda = camera.global_position.x - largura_tela / 2.0 + 60
	var direita = camera.global_position.x + largura_tela / 2.0 - 60
	var superior = camera.global_position.y - altura_tela / 2.0 + margem_superior
	var inferior = camera.global_position.y + altura_tela / 2.0 - margem_inferior

	return Rect2(esquerda, superior, direita - esquerda, inferior - superior)


func proxima_arena():
	em_transicao = true
	player.bloqueado = true
	hud.esconder_aviso()

	var distancia = largura_tela - 120
	var destino = camera.global_position + Vector2(distancia, 0)

	var tween = create_tween()

	tween.tween_property(
		camera,
		"global_position",
		destino,
		duracao_transicao
	)

	await tween.finished

	arena_atual += 1

	# GERA OS INIMIGOS DA NOVA ARENA
	enemy_manager.iniciar_arena(arena_atual)

	em_transicao = false
	player.bloqueado = false


func _input(event):
	if player.vida <= 0 and event.is_action_pressed("reiniciar"):
		enemy_manager.reiniciando = true
		get_tree().call_deferred("reload_current_scene")
		return

	if player.vida > 0 and event.is_action_pressed("riff_mode") and carga_solo >= carga_solo_maxima:
		solo_de_guitarra()

func concluir_fase():
	fase_concluida = true

	player.bloqueado = false
	player.velocity = Vector2.ZERO
	
	portal.ativar_portal()
	hud.mostrar_aviso("NOTA %s  ·  O portal abriu! Vá até ele e pressione E" % ultima_nota)
