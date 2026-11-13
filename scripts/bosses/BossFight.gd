extends Node2D
## Arena de boss (serve para os 3 bosses).
##
## A cena precisa ter:
##   - um boss (qualquer nó com script "extends Boss")
##   - Player (o P1; o P2 é criado sozinho se estiver jogando)
##   - HUD/BossHealthBar, HUD/RiffHUD (instância de scenes/ui/riff_hud.tscn)
##   - HudJogo (instância de scenes/ui/hud.tscn)
##
## Qualquer jogador aperta o botão do Riff para começar/parar. Durante o Riff
## os dois ficam parados tocando, em revezamento.

@export var texto_inicio = "Modo Riff — só as notas ferem o boss!"

@onready var boss: Boss = get_tree().get_first_node_in_group("boss")
@onready var boss_health_bar = $HUD/BossHealthBar
@onready var riff_hud = $HUD/RiffHUD
@onready var hud = $HudJogo

var riff_ativo = false
var fim_de_jogo = false
var venceu = false


func _ready() -> void:
	Jogo.preparar_jogadores(self)
	Jogo.game_over.connect(_ao_game_over)
	Jogo.jogador_entrou.connect(_ao_jogador_entrar)

	riff_hud.boss = boss
	boss_health_bar.max_value = boss.vida_maxima
	boss_health_bar.value = boss.vida_atual
	boss.vida_atualizada.connect(_atualizar_barra_boss)
	boss.derrotado.connect(_ao_derrotar_boss)
	hud.definir_progresso(Jogo.nome_fase_atual().to_upper())
	hud.mostrar_aviso("ESPAÇO / LB: " + texto_inicio, 6.0)
	boss.ciclo_ataques()
	riff_hud.hide()


func limites_arena() -> Rect2:
	return Rect2(20, 60, 1130, 560)


func _ao_jogador_entrar(jogador) -> void:
	jogador.bloqueado = riff_ativo


func _atualizar_barra_boss(vida):
	boss_health_bar.value = vida

	if vida <= 0:
		_encerrar_riff()
		for jogador in Jogo.jogadores:
			jogador.bloqueado = true
			jogador.invencivel = true


func _encerrar_riff():
	riff_ativo = false
	riff_hud.parar_riff()
	riff_hud.hide()
	for jogador in Jogo.jogadores:
		jogador.bloqueado = false


func _ao_game_over():
	_encerrar_riff()
	fim_de_jogo = true
	hud.mostrar_fim("GAME OVER", "R / START para tentar de novo", Color(1, 0.25, 0.25))


func _ao_derrotar_boss():
	fim_de_jogo = true
	venceu = true
	var subtitulo = "R / START para voltar ao início" if Jogo.eh_ultima_fase() else "R / START para seguir"
	hud.mostrar_fim("VITÓRIA!", subtitulo, Color(1, 0.3, 0.72))


func _apertou(nome: String) -> bool:
	for id_jogador in [1, 2]:
		if Input.is_action_just_pressed(Controles.acao(id_jogador, nome)):
			return true
	return false


func _process(_delta: float) -> void:
	if fim_de_jogo:
		if _apertou("reiniciar"):
			if venceu:
				Jogo.proxima_fase()
			else:
				Jogo.reiniciar_fase()
		return

	if boss.vida_atual <= 0:
		return

	if _apertou("riff_mode"):
		riff_ativo = not riff_ativo
		for jogador in Jogo.jogadores:
			jogador.bloqueado = riff_ativo
		riff_hud.visible = riff_ativo

		if riff_ativo:
			riff_hud.iniciar_riff()
		else:
			riff_hud.parar_riff()
