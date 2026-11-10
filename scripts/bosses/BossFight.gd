extends Node2D

const ACOES_DO_RIFF = ["riff_mode", "riff_esquerda", "riff_cima", "riff_baixo", "riff_direita"]

@onready var boss = $Arena/Boss
@onready var boss_health_bar = $HUD/BossHealthBar
@onready var jogador = $Player
@onready var riff_hud = $HUD/RiffHUD
@onready var hud = $HudJogo
@onready var cabo = $HUD/CaboDeForca

var riff_ativo = false
var fim_de_jogo = false
var venceu = false
var vida_boss_por_vida_dylan = 1.0


func _ready() -> void:
	Audio.tocar_musica("boss")
	boss.jogador = jogador

	boss_health_bar.max_value = boss.vida_maxima
	boss_health_bar.value = boss.vida_atual
	boss.vida_atualizada.connect(_atualizar_barra_boss)
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.anuncio.connect(_ao_anunciar)
	boss.fase_avancou.connect(_encerrar_riff)
	boss.desafinar.connect(riff_hud.desafinar)
	jogador.morreu.connect(_ao_jogador_morrer)
	hud.conectar_jogador(jogador)

	if boss.recurso_ativo(boss.usar_cabo_de_forca):
		_iniciar_cabo_de_forca()
	else:
		cabo.hide()

	hud.definir_progresso("BOSS")
	hud.mostrar_aviso("R: Modo Riff — só as notas ferem o boss!", 6.0)
	boss.ciclo_ataques()
	riff_hud.hide()


# A barra é um saldo único: cada um começa com metade e o que um perde o outro ganha
func _iniciar_cabo_de_forca() -> void:
	jogador.vida_maxima = jogador.vida * 2
	boss.iniciar_cabo_de_forca()
	vida_boss_por_vida_dylan = float(boss.vida_maxima) / jogador.vida_maxima
	boss.dano_recebido.connect(_transferir_para_dylan)
	jogador.dano_sofrido.connect(_transferir_para_boss)
	cabo.conectar(jogador, boss)
	boss_health_bar.hide()
	hud.usar_cabo_de_forca()


func _transferir_para_dylan(valor) -> void:
	jogador.curar(valor / vida_boss_por_vida_dylan)


func _transferir_para_boss(valor) -> void:
	boss.curar(roundi(valor * vida_boss_por_vida_dylan))


func limites_arena() -> Rect2:
	return Rect2(20, 60, 1130, 560)


func _ao_anunciar(texto):
	hud.mostrar_aviso(texto, 4.0)


func _atualizar_barra_boss(vida):
	boss_health_bar.value = vida

	if vida <= 0:
		_encerrar_riff()
		jogador.bloqueado = true
		jogador.invencivel = true


func _encerrar_riff():
	riff_ativo = false
	riff_hud.parar_riff()
	riff_hud.hide()
	jogador.bloqueado = false


func _ao_jogador_morrer():
	_encerrar_riff()
	fim_de_jogo = true
	Audio.parar_musica()
	hud.mostrar_fim("GAME OVER", "Pressione R para tentar de novo", Color(1, 0.25, 0.25))


func _ao_derrotar_boss():
	fim_de_jogo = true
	venceu = true
	Audio.parar_musica()
	Audio.tocar("vitoria", 0.0)
	hud.mostrar_fim("VITÓRIA!", "Pressione R para voltar ao início", Color(1, 0.3, 0.72))


# Qualquer tecla ou botão fora do Riff fecha o modo, para o jogador poder reagir
func _input(event: InputEvent) -> void:
	if not riff_ativo or not event.is_pressed() or event.is_echo():
		return

	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return

	for acao in ACOES_DO_RIFF:
		if event.is_action(acao):
			return

	_encerrar_riff()


func _process(_delta: float) -> void:
	if fim_de_jogo:
		if Input.is_action_just_pressed("reiniciar"):
			if venceu:
				get_tree().change_scene_to_file("res://scenes/ui/tela_inicial.tscn")
			else:
				get_tree().reload_current_scene()
		return

	if boss.vida_atual <= 0:
		return

	if Input.is_action_just_pressed("riff_mode"):
		riff_ativo = not riff_ativo
		jogador.bloqueado = riff_ativo
		riff_hud.visible = riff_ativo

		if riff_ativo:
			riff_hud.iniciar_riff()
		else:
			riff_hud.parar_riff()
