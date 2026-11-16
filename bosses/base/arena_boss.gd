extends Node2D
## Arena de boss (serve para os 3 bosses).
##
## A cena precisa ter:
##   - um boss (qualquer nó com script "extends Boss")
##   - Player (o P1; o P2 é criado sozinho se estiver jogando)
##   - HUD/BossHealthBar, HUD/CaboDeForca e duas instâncias de riff/riff_hud.tscn (RiffHUD e RiffHUDP2)
##   - HudJogo (instância de ui/hud.tscn)
##
## Cada jogador abre e fecha o próprio Riff. Dano interrompe apenas o atingido.
## A troca de fase do boss encerra os dois Riffs.
##
## Cabo de força (usar_cabo_de_forca): a dupla divide UMA vida contra o boss.
## Dano em qualquer jogador enche o boss; dano no boss enche a dupla.
## Se a vida da dupla zerar, os dois caem juntos.

## Aviso no começo da luta (vazio = sem aviso). Sai com a tecla do Riff na frente.
@export var texto_inicio := ""
## Segundos com o cadeado ativo ao entrar na arena, antes do primeiro Riff
@export var trava_inicial: float = 5.0
@export var usar_cabo_de_forca := true
## Vida inicial da dupla no cabo de força (a barra vai até o dobro)
@export var vida_inicial_da_dupla: int = 5
## Chão onde dá para andar (capangas e granadas ficam dentro dele).
## Ajuste quando o fundo da arena tiver palco ou cenário nas bordas.
@export var limites: Rect2 = Rect2(20, 60, 1130, 560)

@onready var boss: Boss = get_tree().get_first_node_in_group("boss")
@onready var boss_health_bar = $HUD/BossHealthBar
@onready var cabo = $HUD/CaboDeForca
@onready var riff_hud = $HUD/RiffHUD
@onready var riffs = {1: riff_hud, 2: $HUD/RiffHUDP2}
@onready var hud = $HudJogo

var riff_ativo: bool:
	get:
		return riffs.values().any(func(riff): return riff.tocando)
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
	Jogo.jogador_saiu.connect(_encerrar_riff_de)
	for jogador in Jogo.jogadores:
		_ligar_dano_no_riff(jogador)
	Audio.tocar_musica("boss")

	for id_jogador in riffs:
		var riff = riffs[id_jogador]
		riff.boss = boss
		riff.parceiro = riffs[3 - id_jogador]
		riff.hide()
		if trava_inicial > 0.0:
			riff.travar(trava_inicial)
	boss_health_bar.max_value = boss.vida_maxima
	boss_health_bar.value = boss.vida_atual
	boss.vida_atualizada.connect(_atualizar_barra_boss)
	boss.derrotado.connect(_ao_derrotar_boss)
	boss.anuncio.connect(func(texto): hud.mostrar_aviso(texto, 4.0))
	boss.fase_avancou.connect(_encerrar_riff)
	boss.fase_avancou.connect(_atualizar_marcadores_fase)
	_atualizar_marcadores_fase()

	if usar_cabo_de_forca:
		_iniciar_cabo_de_forca()
	else:
		cabo.hide()

	hud.mostrar_titulo(Jogo.nome_fase_atual().to_upper())
	if not texto_inicio.is_empty():
		hud.mostrar_aviso(Controles.texto_comando("riff_mode") + ": " + texto_inicio, 6.0)
	boss.ciclo_ataques()


func limites_arena() -> Rect2:
	return limites


func _ao_jogador_entrar(jogador) -> void:
	_ligar_dano_no_riff(jogador)
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


## Riscos na barra comum (sem cabo de força) onde o boss muda de fase
func _atualizar_marcadores_fase() -> void:
	var marcadores = boss_health_bar.get_node_or_null("MarcadoresFase")
	if marcadores:
		marcadores.definir(boss.limites_restantes().map(func(vida): return vida / boss_health_bar.max_value))


# ---------------------------------------------------------------- Riff e fim

func _atualizar_barra_boss(vida):
	boss_health_bar.value = vida
	_atualizar_marcadores_fase()

	if vida <= 0:
		_encerrar_riff()
		for jogador in Jogo.jogadores:
			jogador.bloqueado = true
			jogador.invencivel = true


func _encerrar_riff():
	for id_jogador in riffs:
		_encerrar_riff_de(id_jogador)


func _encerrar_riff_de(id_jogador: int) -> void:
	var riff = riffs[id_jogador]
	if not riff.tocando:
		return
	riff.parar_riff()
	riff.hide()
	var jogador = Jogo.jogador_por_id(id_jogador)
	if jogador != null:
		jogador.bloqueado = false
		jogador.em_riff = false


func _abrir_riff(jogador) -> void:
	var riff = riffs[jogador.id_jogador]
	jogador.bloqueado = true
	jogador.em_riff = true
	riff.show()
	riff.iniciar_riff()


func _ao_game_over():
	_encerrar_riff()
	fim_de_jogo = true
	Audio.parar_musica()
	hud.mostrar_fim("GAME OVER", Controles.texto_comando("reiniciar") + " para tentar de novo", Color(1, 0.25, 0.25))


func _ao_derrotar_boss():
	fim_de_jogo = true
	venceu = true
	Audio.parar_musica()
	Audio.tocar("vitoria", 0.0)
	var tecla = Controles.texto_comando("reiniciar")
	var subtitulo = tecla + (" para voltar ao início" if Jogo.eh_ultima_fase() else " para seguir")
	hud.mostrar_fim("VITÓRIA!", subtitulo, Color(1, 0.3, 0.72))


func _apertou(nome: String) -> bool:
	for id_jogador in [1, 2]:
		if Input.is_action_just_pressed(Controles.acao(id_jogador, nome)):
			return true
	return false


func _ligar_dano_no_riff(jogador) -> void:
	var id_jogador: int = jogador.id_jogador
	jogador.dano_sofrido.connect(_ao_dano_no_riff.bind(id_jogador))
	jogador.morreu.connect(_encerrar_riff_de.bind(id_jogador))
	jogador.esquiva_iniciada.connect(_ao_sair_do_riff.bind(id_jogador))


func _ao_sair_do_riff(id_jogador: int) -> void:
	var riff = riffs[id_jogador]
	if riff.tocando:
		_encerrar_riff_de(id_jogador)
		riff.travar(riff.trava_ao_sair)


func _ao_dano_no_riff(valor, id_jogador: int) -> void:
	var riff = riffs[id_jogador]
	if valor > 0 and riff.tocando and boss.vida_atual > 0:
		_encerrar_riff_de(id_jogador)
		riff.travar(riff.trava_por_dano)


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

	for jogador in Jogo.jogadores_vivos():
		var id_jogador: int = jogador.id_jogador
		var riff = riffs[id_jogador]
		if not jogador.entrando and Input.is_action_just_pressed(jogador.acao("riff_mode")):
			if riff.tocando:
				_ao_sair_do_riff(id_jogador)
			elif riff.travado() or boss.escudo_ativo:
				# Totens de pé (ou na contagem depois deles): instrumentos desligados
				hud.recusar_riff(id_jogador)
			elif not jogador.esquivando:
				_abrir_riff(jogador)

	for id_jogador in riffs:
		var jogador = Jogo.jogador_por_id(id_jogador)
		var progresso := 1.0
		if jogador != null:
			progresso = minf(riffs[id_jogador].progresso_trava(), boss.progresso_instrumentos())
		hud.mostrar_trava_riff(progresso, id_jogador, jogador)
