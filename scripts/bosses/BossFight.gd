extends Node2D

@onready var boss = $Arena/Boss
@onready var boss_health_bar = $HUD/BossHealthBar
@onready var jogador = $Player
@onready var riff_hud = $HUD/RiffHUD
@onready var hud = $HudJogo

var riff_ativo = false
var fim_de_jogo = false
var venceu = false


func _ready() -> void:
	boss.jogador = jogador

	boss_health_bar.max_value = boss.vida_maxima
	boss_health_bar.value = boss.vida_atual
	boss.vida_atualizada.connect(_atualizar_barra_boss)
	boss.derrotado.connect(_ao_derrotar_boss)
	jogador.morreu.connect(_ao_jogador_morrer)
	hud.conectar_jogador(jogador)
	hud.definir_progresso("BOSS")
	hud.mostrar_aviso("ESPAÇO: Modo Riff — só as notas ferem o boss!", 6.0)
	boss.ciclo_ataques()
	riff_hud.hide()


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
	hud.mostrar_fim("GAME OVER", "Pressione R para tentar de novo", Color(1, 0.25, 0.25))


func _ao_derrotar_boss():
	fim_de_jogo = true
	venceu = true
	hud.mostrar_fim("VITÓRIA!", "Pressione R para voltar ao início", Color(1, 0.3, 0.72))


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
