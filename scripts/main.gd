extends Node2D
## Fase de rua (beat 'em up). Serve para as ruas 1, 2 e 3.
##
## A cena precisa ter: Player (o P1), Camera2D, Spawns (ArenaN/OndaN/pontos),
## EnemyManager, Portal e HudJogo. A câmera anda uma tela para a direita a
## cada arena limpa; no fim, o portal leva para a próxima fase.

@export var duracao_transicao = 0.8
@export var margem_superior = 310.0
@export var margem_inferior = 100.0
@onready var camera = $Camera2D
@onready var enemy_manager = $EnemyManager
@onready var portal = $Portal
@onready var hud = $HudJogo


var fase_concluida = false
var arena_atual = 1
var em_transicao = false
var fim_de_jogo = false
var largura_tela = 0.0
var altura_tela = 0.0


func _ready():
	largura_tela = get_viewport_rect().size.x / camera.zoom.x
	altura_tela = get_viewport_rect().size.y / camera.zoom.y

	Jogo.preparar_jogadores(self)
	Jogo.game_over.connect(_ao_game_over)
	Jogo.jogador_entrou.connect(_ao_jogador_entrar)
	enemy_manager.onda_iniciada.connect(_ao_iniciar_onda)
	enemy_manager.arena_concluida.connect(_ao_concluir_arena)
	Audio.tocar_musica("ruas")


func quantidade_arenas() -> int:
	return enemy_manager.quantidade_arenas()


func _ao_iniciar_onda(arena, onda, total_ondas):
	hud.definir_progresso("%s  ·  ARENA %d/%d  ·  ONDA %d/%d" % [
		Jogo.nome_fase_atual().to_upper(), arena, quantidade_arenas(), onda, total_ondas])


func _ao_concluir_arena():
	# Último inimigo da rua: câmera lenta para fechar com impacto
	if arena_atual == quantidade_arenas():
		Combate.camera_lenta(0.9)

	if arena_atual < quantidade_arenas():
		hud.mostrar_aviso("Área limpa! Siga para a direita  →")


func _ao_jogador_entrar(jogador):
	jogador.bloqueado = em_transicao


func _ao_game_over():
	fim_de_jogo = true
	Audio.parar_musica()
	hud.mostrar_fim("GAME OVER", "R / START para tentar de novo", Color(1, 0.25, 0.25))


func _process(_delta):
	if fim_de_jogo:
		for id_jogador in [1, 2]:
			if Input.is_action_just_pressed(Controles.acao(id_jogador, "reiniciar")):
				enemy_manager.reiniciando = true
				Jogo.reiniciar_fase()
				return
		return

	if em_transicao:
		return

	# VERIFICAR FIM DA FASE
	if not fase_concluida and arena_atual == quantidade_arenas() and enemy_manager.arena_liberada:
		concluir_fase()

	# LIMITES DA ARENA (os dois jogadores ficam na mesma tela)
	var limites = limites_arena()
	var alguem_na_borda = false

	for jogador in Jogo.jogadores:
		jogador.global_position = jogador.global_position.clamp(limites.position, limites.end)
		if not jogador.caido and jogador.global_position.x >= limites.end.x:
			alguem_na_borda = true

	if alguem_na_borda and arena_atual < quantidade_arenas() and enemy_manager.arena_liberada:
		proxima_arena()


func limites_arena() -> Rect2:
	var esquerda = camera.global_position.x - largura_tela / 2.0 + 40
	var direita = camera.global_position.x + largura_tela / 2.0 - 40
	var superior = camera.global_position.y - altura_tela / 2.0 + margem_superior
	var inferior = camera.global_position.y + altura_tela / 2.0 - margem_inferior

	return Rect2(esquerda, superior, direita - esquerda, inferior - superior)


func proxima_arena():
	em_transicao = true
	for jogador in Jogo.jogadores:
		jogador.bloqueado = true
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
	for jogador in Jogo.jogadores:
		jogador.bloqueado = false


func concluir_fase():
	fase_concluida = true

	portal.ativar_portal()
	hud.mostrar_aviso("O portal abriu! Vá até ele e pressione E / B")
