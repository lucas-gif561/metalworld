extends Node2D
## Arena de boss (serve para os 3 bosses).
##
## A cena precisa ter:
##   - um boss (qualquer nó com script "extends Boss")
##   - Player (o P1; o P2 é criado sozinho se estiver jogando)
##   - HUD/BossHealthBar, HUD/CaboDeForca, HUD/RiffHUD (scenes/ui/riff_hud.tscn)
##   - HudJogo (instância de scenes/ui/hud.tscn)
##
## Riff: qualquer jogador aperta o botão do Riff para começar. Durante o Riff
## os dois ficam parados tocando, em revezamento. Qualquer outro botão fecha.
##
## Cabo de força (usar_cabo_de_forca): a dupla divide UMA vida contra o boss.
## Dano em qualquer jogador enche o boss; dano no boss enche a dupla.
## Se a vida da dupla zerar, os dois caem juntos.

const ACOES_DO_RIFF = ["riff_mode", "riff_esquerda", "riff_cima", "riff_baixo", "riff_direita"]

@export var texto_inicio = "Modo Riff — só as notas ferem o boss!"
@export var usar_cabo_de_forca := true
## Vida inicial da dupla no cabo de força (a barra vai até o dobro)
@export var vida_inicial_da_dupla: int = 5

@onready var boss: Boss = get_tree().get_first_node_in_group("boss")
@onready var boss_health_bar = $HUD/BossHealthBar
@onready var cabo = $HUD/CaboDeForca
@onready var riff_hud = $HUD/RiffHUD
@onready var hud = $HudJogo

var riff_ativo = false
var fim_de_jogo = false
var venceu = false
var vida_dupla := 0
var vida_dupla_maxima := 0
var vida_boss_por_vida_dupla := 1.0
var credito_cura := 0.0


func _ready() -> void:
	Jogo.preparar_jogadores(self)
	Jogo.game_over.connect(_ao_game_over)
	Jogo.jogador_entrou.connect(_ao_jogador_entrar)
	Audio.tocar_musica("boss")

	riff_hud.boss = boss
	boss_health_bar.max_value = boss.vida_maxima
	boss_health_bar.value = boss.vida_atual
	boss.vida_atualizada.connect(_atualizar_barra_boss)
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.anuncio.connect(func(texto): hud.mostrar_aviso(texto, 4.0))
	boss.fase_avancou.connect(_encerrar_riff)

	if usar_cabo_de_forca:
		_iniciar_cabo_de_forca()
	else:
		cabo.hide()

	hud.definir_progresso(Jogo.nome_fase_atual().to_upper())
	hud.mostrar_aviso("ESPAÇO / LB: " + texto_inicio, 6.0)
	boss.ciclo_ataques()
	riff_hud.hide()


func limites_arena() -> Rect2:
	return Rect2(20, 60, 1130, 560)


func _ao_jogador_entrar(jogador) -> void:
	jogador.bloqueado = riff_ativo
	jogador.em_riff = riff_ativo
	if usar_cabo_de_forca:
		_ligar_vida_compartilhada(jogador)


# ---------------------------------------------------------------- Cabo de força

func _iniciar_cabo_de_forca() -> void:
	vida_dupla = vida_inicial_da_dupla
	vida_dupla_maxima = vida_inicial_da_dupla * 2
	boss.iniciar_cabo_de_forca()
	vida_boss_por_vida_dupla = float(boss.vida_maxima) / vida_dupla_maxima
	boss.dano_recebido.connect(_ao_boss_sofrer_dano)

	for jogador in Jogo.jogadores:
		_ligar_vida_compartilhada(jogador)

	cabo.conectar(Jogo.jogador_por_id(1), boss)
	cabo.show()
	boss_health_bar.hide()
	hud.usar_vida_compartilhada()


func _ligar_vida_compartilhada(jogador) -> void:
	if not jogador.dano_sofrido.is_connected(_ao_jogador_sofrer_dano):
		jogador.dano_sofrido.connect(_ao_jogador_sofrer_dano.bind(jogador))
	jogador.sincronizar_vida(vida_dupla, vida_dupla_maxima)


func _ao_jogador_sofrer_dano(valor, atingido) -> void:
	if valor <= 0:
		return
	vida_dupla = maxi(vida_dupla - valor, 0)
	boss.curar(roundi(valor * vida_boss_por_vida_dupla))
	_sincronizar_dupla(atingido)


func _ao_boss_sofrer_dano(valor) -> void:
	credito_cura += valor / vida_boss_por_vida_dupla
	var cura = floori(credito_cura)
	if cura <= 0:
		return
	credito_cura -= cura
	vida_dupla = mini(vida_dupla + cura, vida_dupla_maxima)
	_sincronizar_dupla(null)


func _sincronizar_dupla(exceto) -> void:
	for jogador in Jogo.jogadores.duplicate():
		if jogador != exceto and is_instance_valid(jogador):
			jogador.sincronizar_vida(vida_dupla, vida_dupla_maxima)


# ---------------------------------------------------------------- Riff e fim

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
		jogador.em_riff = false


func _abrir_riff():
	riff_ativo = true
	for jogador in Jogo.jogadores:
		jogador.bloqueado = true
		jogador.em_riff = true # saca a guitarra e toca
	riff_hud.show()
	riff_hud.iniciar_riff()


func _ao_game_over():
	_encerrar_riff()
	fim_de_jogo = true
	Audio.parar_musica()
	hud.mostrar_fim("GAME OVER", "R / START para tentar de novo", Color(1, 0.25, 0.25))


func _ao_derrotar_boss():
	fim_de_jogo = true
	venceu = true
	Audio.parar_musica()
	Audio.tocar("vitoria", 0.0)
	var subtitulo = "R / START para voltar ao início" if Jogo.eh_ultima_fase() else "R / START para seguir"
	hud.mostrar_fim("VITÓRIA!", subtitulo, Color(1, 0.3, 0.72))


func _apertou(nome: String) -> bool:
	for id_jogador in [1, 2]:
		if Input.is_action_just_pressed(Controles.acao(id_jogador, nome)):
			return true
	return false


# Qualquer tecla ou botão que não seja do Riff fecha o modo, para dar tempo de reagir
func _input(event: InputEvent) -> void:
	if not riff_ativo or not event.is_pressed() or event.is_echo():
		return

	if not (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
		return

	for id_jogador in [1, 2]:
		for acao in ACOES_DO_RIFF:
			if event.is_action(Controles.acao(id_jogador, acao)):
				return

	_encerrar_riff()


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
		if riff_ativo:
			_encerrar_riff()
		else:
			_abrir_riff()
