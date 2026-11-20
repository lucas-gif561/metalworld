extends CanvasLayer
## Menu de pause: Esc (P1), P (P2 no teclado) ou START (de quem está jogando).
##
## Continuar, Controles, Opções (volumes), remover o jogador 2 (ele pode
## entrar de novo com START) ou voltar ao menu principal. Visual na cena (menu_pausa.tscn), no mesmo tema
## do menu principal. Roda com o jogo pausado (process_mode = Sempre).
## A moldura acompanha os botões (CenterContainer + PanelContainer na cena):
## sozinho, sem "Remover jogador 2", ela fica menor.
##
## Navegação: setas, WASD, direcional ou analógico de qualquer jogador.
## Confirmar: Enter, Espaço, F, J, A. Voltar ao jogo: Esc, P, B ou START.

const ESPERA_NAVEGACAO = 0.18

@onready var moldura = $Painel
@onready var menu = $Painel/Caixa/Respiro/Menu
@onready var controles = $TelaControles
@onready var opcoes = $TelaOpcoes
@onready var botao_remover_p2 = menu.get_node("RemoverP2")

var _proxima_navegacao := 0.0


func _ready() -> void:
	hide()
	menu.get_node("Continuar").pressed.connect(continuar)
	menu.get_node("Controles").pressed.connect(_abrir_controles)
	controles.fechada.connect(_fechar_controles)
	menu.get_node("Opcoes").pressed.connect(_abrir_opcoes)
	opcoes.fechada.connect(_fechar_opcoes)
	botao_remover_p2.pressed.connect(_remover_p2)
	menu.get_node("MenuPrincipal").pressed.connect(_ir_ao_menu)
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
	menu.get_node("Continuar").grab_focus()


func continuar() -> void:
	controles.hide()
	opcoes.hide()
	moldura.show()
	hide()
	get_tree().paused = false
	Audio.pausar_musica(false)


func _abrir_controles() -> void:
	Audio.tocar("ui_confirma", 0.0)
	moldura.hide()
	controles.abrir()


func _fechar_controles() -> void:
	moldura.show()
	menu.get_node("Controles").grab_focus()


func _abrir_opcoes() -> void:
	Audio.tocar("ui_confirma", 0.0)
	moldura.hide()
	opcoes.abrir()


func _fechar_opcoes() -> void:
	moldura.show()
	menu.get_node("Opcoes").grab_focus()


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


func _input(event: InputEvent) -> void:
	if not visible or controles.visible or opcoes.visible or not event is InputEventJoypadButton:
		return
	if event.button_index == JOY_BUTTON_B:
		if event.pressed:
			continuar()
		get_viewport().set_input_as_handled()
	elif event.button_index == JOY_BUTTON_A:
		var focado = get_viewport().gui_get_focus_owner()
		if event.pressed and focado is Button and focado.is_visible_in_tree():
			focado.pressed.emit()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		if _apertou(event, "pausar") and _pode_pausar():
			abrir()
			get_viewport().set_input_as_handled()
		return
	# Controles e Opções abertas cuidam da própria entrada (e voltam para cá ao fechar)
	if controles.visible or opcoes.visible:
		return

	if _apertou(event, "pausar") or event.is_action_pressed("ui_cancel"):
		continuar()
	elif _apertou(event, "mover_cima"):
		_navegar(-1)
	elif _apertou(event, "mover_baixo"):
		_navegar(1)
	elif not event is InputEventJoypadButton and _apertou(event, "atacar"):
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
