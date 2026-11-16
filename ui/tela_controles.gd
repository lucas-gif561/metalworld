extends ColorRect
## Referência compartilhada pelo menu principal e pelo menu de pausa.

signal fechada

const Jogador = preload("res://personagens/dylan/jogador.gd")
const Baterista = preload("res://personagens/baterista/baterista.gd")

## Ícones das duas notas dos minirriffs ("A" e "B" na sequência), escolhidos na
## cena. A tabela de minirriffs é montada no código porque sai das constantes
## dos personagens (MINIRRIFFS); o resto da tela fica todo no .tscn.
@export var notas_p1: Array[Texture2D] = []
@export var notas_controle: Array[Texture2D] = []
@export var icone_poder: Texture2D

@onready var combos = $Margens/Painel/Respiro/Coluna/Conteudo/Secoes/FaixaCombos/Respiro/Combos
@onready var conteudo = $Margens/Painel/Respiro/Coluna/Conteudo
@onready var voltar = $Margens/Painel/Respiro/Coluna/Voltar


func _ready() -> void:
	voltar.pressed.connect(_fechar)
	_adicionar_combos("Dylan", Jogador.MINIRRIFFS, notas_p1)
	# Qualquer jogador pode ser qualquer personagem: a tabela mostra as teclas
	# do P1, e o texto abaixo dela diz quais o P2 usa
	_adicionar_combos("Kevin", Baterista.MINIRRIFFS_KEVIN, notas_p1)


func _adicionar_combos(personagem: String, minirriffs: Dictionary, teclado: Array[Texture2D]) -> void:
	for sequencia in minirriffs:
		var especial: Dictionary = minirriffs[sequencia]
		_adicionar_celula(personagem)
		_adicionar_celula(especial.nome).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for notas in [teclado, notas_controle]:
			var icones: Array[Texture2D] = []
			for nota in sequencia:
				icones.append(notas[0] if nota == "A" else notas[1])
			_adicionar_icones(icones, 28.0)
		var poder: Array[Texture2D] = []
		poder.resize(int(especial.custo))
		poder.fill(icone_poder)
		_adicionar_icones(poder, 20.0)


func abrir() -> void:
	show()
	conteudo.scroll_vertical = 0
	voltar.grab_focus()


func _fechar() -> void:
	hide()
	fechada.emit()


func _input(evento: InputEvent) -> void:
	if not is_visible_in_tree() or evento.is_echo():
		return
	var botao_voltar = evento is InputEventJoypadButton and evento.pressed and evento.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]
	if botao_voltar or evento.is_action_pressed("ui_cancel"):
		_fechar()
		get_viewport().set_input_as_handled()
		return
	for id_jogador in [1, 2]:
		if not evento is InputEventJoypadButton and (evento.is_action_pressed(Controles.acao(id_jogador, "pausar")) or evento.is_action_pressed(Controles.acao(id_jogador, "atacar"))):
			_fechar()
			get_viewport().set_input_as_handled()
			return
		if evento.is_action_pressed(Controles.acao(id_jogador, "mover_cima")):
			conteudo.scroll_vertical -= 42
			get_viewport().set_input_as_handled()
			return
		if evento.is_action_pressed(Controles.acao(id_jogador, "mover_baixo")):
			conteudo.scroll_vertical += 42
			get_viewport().set_input_as_handled()
			return


func _adicionar_celula(texto: String) -> Label:
	var celula := Label.new()
	celula.text = texto
	celula.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	celula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combos.add_child(celula)
	return celula


## Uma célula com vários ícones lado a lado, no mesmo estilo da tabela de
## comandos da cena (pixel art ampliada sem borrar).
func _adicionar_icones(texturas: Array[Texture2D], altura: float) -> void:
	var celula := HBoxContainer.new()
	celula.add_theme_constant_override("separation", 2)
	celula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for textura in texturas:
		var icone := TextureRect.new()
		icone.texture = textura
		icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icone.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icone.custom_minimum_size = Vector2(0, altura)
		icone.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		celula.add_child(icone)
	combos.add_child(celula)
