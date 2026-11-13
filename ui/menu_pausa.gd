extends CanvasLayer
## Menu de pause: ESC (P1) ou START (de quem está jogando).
##
## Continuar, remover o jogador 2 (ele pode entrar de novo com START) ou
## voltar ao menu principal. Visual na cena (menu_pausa.tscn), no mesmo tema
## do menu principal. Roda com o jogo pausado (process_mode = Sempre).
##
## Navegação: setas, WASD, direcional ou analógico de qualquer jogador.
## Confirmar: Enter, Espaço, J, A. Voltar ao jogo: ESC / START de novo.

const ESPERA_NAVEGACAO = 0.18

@onready var menu = $Moldura/Menu
@onready var botao_remover_p2 = $Moldura/Menu/RemoverP2

var _proxima_navegacao := 0.0


func _ready() -> void:
	hide()
	$Moldura/Menu/Continuar.pressed.connect(continuar)
	botao_remover_p2.pressed.connect(_remover_p2)
	$Moldura/Menu/MenuPrincipal.pressed.connect(_ir_ao_menu)
	for botao in menu.get_children():
		botao.focus_entered.connect(func(): Audio.tocar("nota_good", 0.0))
		botao.mouse_entered.connect(botao.grab_focus)


func abrir() -> void:
	if visible:
		return
	botao_remover_p2.visible = Jogo.p2_ativo
	show()
	get_tree().paused = true
	Audio.pausar_musica(true)
	Audio.tocar("ui_confirma", 0.0)
	$Moldura/Menu/Continuar.grab_focus()


func continuar() -> void:
	hide()
	get_tree().paused = false
	Audio.pausar_musica(false)


func _remover_p2() -> void:
	Jogo.remover_p2()
	continuar()


func _ir_ao_menu() -> void:
	continuar()
	Jogo.voltar_ao_inicio()


## Só pausa durante a partida, e nunca na tela de game over/vitória
func _pode_pausar() -> bool:
	var hud = get_parent()
	return Jogo.esta_em_fase() and not get_tree().paused and not (hud and hud.tela_fim.visible)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _apertou(event, "pausar") and _pode_pausar():
			abrir()
			get_viewport().set_input_as_handled()
		return

	if _apertou(event, "pausar"):
		continuar()
	elif _apertou(event, "mover_cima"):
		_navegar(-1)
	elif _apertou(event, "mover_baixo"):
		_navegar(1)
	elif _apertou(event, "atacar"):
		var focado = get_viewport().gui_get_focus_owner()
		if focado is Button:
			focado.pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


# Só quem está jogando pausa (o START do P2 de fora serve para entrar)
func _apertou(event: InputEvent, nome: String) -> bool:
	for jogador in Jogo.jogadores:
		if is_instance_valid(jogador) and event.is_action_pressed(Controles.acao(jogador.id_jogador, nome), false):
			return true
	return false


func _navegar(passo: int) -> void:
	var agora = Time.get_ticks_msec() / 1000.0
	if agora < _proxima_navegacao:
		return
	_proxima_navegacao = agora + ESPERA_NAVEGACAO
	var botoes = menu.get_children().filter(func(b): return b.visible)
	var atual = botoes.find(get_viewport().gui_get_focus_owner())
	botoes[wrapi(atual + passo, 0, botoes.size())].grab_focus()
