extends ColorRect
## Opções do jogo: volume geral, da música e dos efeitos. Quem guarda e salva
## os volumes é o autoload Audio; aqui fica só a tela. Compartilhada pelo menu
## principal e pelo menu de pausa, como a tela de Controles.
##
## Navegação: cima/baixo trocam de barra e esquerda/direita mudam o volume
## (WASD, setas, direcional ou analógico de qualquer jogador). Voltar: Esc, B,
## a tecla de pausar ou confirmar no botão "Voltar".

signal fechada

const ESPERA_NAVEGACAO = 0.15
## Mesmo rosa do título e da barra cheia
const COR_DESTAQUE = Color(1, 0.3, 0.72)

@onready var barras := {
	"geral": $Centro/Painel/Respiro/Coluna/Volumes/Geral/Barra,
	"musica": $Centro/Painel/Respiro/Coluna/Volumes/Musica/Barra,
	"efeitos": $Centro/Painel/Respiro/Coluna/Volumes/Efeitos/Barra,
}
@onready var voltar = $Centro/Painel/Respiro/Coluna/Voltar

var _proxima_navegacao := 0.0


func _ready() -> void:
	voltar.pressed.connect(_fechar)
	for canal in barras:
		var barra: HSlider = barras[canal]
		barra.value_changed.connect(_ao_mudar.bind(canal))
		# A barra não tem bolinha e o HSlider não desenha o estilo de foco: a
		# linha escolhida aparece pelo nome e pela porcentagem em rosa
		barra.focus_entered.connect(_destacar.bind(barra, true))
		barra.focus_exited.connect(_destacar.bind(barra, false))
	for controle in _focaveis():
		controle.focus_entered.connect(func(): Audio.tocar("nota_good", 0.0))
		controle.mouse_entered.connect(controle.grab_focus)


func abrir() -> void:
	for canal in barras:
		barras[canal].set_value_no_signal(Audio.volume(canal) * 100.0)
		_mostrar_valor(canal)
	show()
	barras.geral.grab_focus()


func _fechar() -> void:
	Audio.salvar_volumes()
	hide()
	fechada.emit()


func _ao_mudar(valor: float, canal: String) -> void:
	Audio.definir_volume(canal, valor / 100.0)
	_mostrar_valor(canal)
	# Um toque curto para ouvir como ficou
	Audio.tocar("nota_good", 0.0)


func _mostrar_valor(canal: String) -> void:
	barras[canal].get_parent().get_node("Valor").text = "%d%%" % roundi(barras[canal].value)


func _destacar(barra: HSlider, aceso: bool) -> void:
	for nome in ["Nome", "Valor"]:
		var rotulo: Label = barra.get_parent().get_node(nome)
		if aceso:
			rotulo.add_theme_color_override("font_color", COR_DESTAQUE)
		else:
			rotulo.remove_theme_color_override("font_color")


func _focaveis() -> Array:
	return barras.values() + [voltar]


func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var no_controle = evento is InputEventJoypadButton
	if (no_controle and evento.pressed and evento.button_index == JOY_BUTTON_B) or evento.is_action_pressed("ui_cancel"):
		_fechar()
		get_viewport().set_input_as_handled()
		return
	if no_controle and evento.pressed and evento.button_index == JOY_BUTTON_A and voltar.has_focus():
		_fechar()
		get_viewport().set_input_as_handled()
		return
	for id_jogador in [1, 2]:
		if not no_controle and not evento.is_echo() and (evento.is_action_pressed(Controles.acao(id_jogador, "pausar"))
				or (voltar.has_focus() and evento.is_action_pressed(Controles.acao(id_jogador, "atacar")))):
			_fechar()
		elif evento.is_action_pressed(Controles.acao(id_jogador, "mover_cima"), true):
			_navegar(-1)
		elif evento.is_action_pressed(Controles.acao(id_jogador, "mover_baixo"), true):
			_navegar(1)
		elif evento.is_action_pressed(Controles.acao(id_jogador, "mover_esquerda"), true):
			_ajustar(-1)
		elif evento.is_action_pressed(Controles.acao(id_jogador, "mover_direita"), true):
			_ajustar(1)
		else:
			continue
		get_viewport().set_input_as_handled()
		return


func _navegar(passo: int) -> void:
	var agora = Time.get_ticks_msec() / 1000.0
	if agora < _proxima_navegacao:
		return
	_proxima_navegacao = agora + ESPERA_NAVEGACAO
	var lista = _focaveis()
	var atual = lista.find(get_viewport().gui_get_focus_owner())
	lista[wrapi(atual + passo, 0, lista.size())].grab_focus()


## Segurar a tecla repete (eco), de 5 em 5%
func _ajustar(direcao: int) -> void:
	var focado = get_viewport().gui_get_focus_owner()
	if focado is HSlider:
		focado.value += direcao * focado.step
