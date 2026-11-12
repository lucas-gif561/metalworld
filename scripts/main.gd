extends Node2D

@export var quantidade_arenas = 3
@export var duracao_transicao = 0.8
@export var margem_superior = 310.0
@export var margem_inferior = 100.0
@onready var player = $Player
@onready var camera = $Camera2D
@onready var enemy_manager = $EnemyManager
@onready var portal = $Portal
@onready var hud = $HudJogo


var fase_concluida = false
var arena_atual = 1
var em_transicao = false
var largura_tela = 0.0
var altura_tela = 0.0

func _ready():
	largura_tela = get_viewport_rect().size.x / camera.zoom.x
	altura_tela = get_viewport_rect().size.y / camera.zoom.y

	hud.conectar_jogador(player)
	player.morreu.connect(_ao_jogador_morrer)
	enemy_manager.onda_iniciada.connect(_ao_iniciar_onda)
	enemy_manager.arena_concluida.connect(_ao_concluir_arena)


func _ao_iniciar_onda(arena, onda, total_ondas):
	hud.definir_progresso("ARENA %d/%d  ·  ONDA %d/%d" % [arena, quantidade_arenas, onda, total_ondas])


func _ao_concluir_arena():
	if arena_atual < quantidade_arenas:
		hud.mostrar_aviso("Área limpa! Siga para a direita  →")


func _ao_jogador_morrer():
	hud.mostrar_fim("GAME OVER", "Pressione R para tentar de novo", Color(1, 0.25, 0.25))


func _process(_delta):
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
	var esquerda = camera.global_position.x - largura_tela / 2.0 + 40
	var direita = camera.global_position.x + largura_tela / 2.0 - 40
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

func concluir_fase():
	fase_concluida = true

	player.bloqueado = false
	player.velocity = Vector2.ZERO
	
	portal.ativar_portal()
	hud.mostrar_aviso("O portal abriu! Vá até ele e pressione E")
