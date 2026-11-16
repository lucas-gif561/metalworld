extends ColorRect
## Referência compartilhada pelo menu principal e pelo menu de pausa.

signal fechada

const Jogador = preload("res://personagens/dylan/jogador.gd")
const Baterista = preload("res://personagens/baterista/baterista.gd")
const NOTAS_POR_DISPOSITIVO = [["T", "Y"], ["I", "L"], ["LB", "RB"]]

@onready var combos = $Margens/Painel/Respiro/Coluna/Conteudo/Secoes/Combos
@onready var conteudo = $Margens/Painel/Respiro/Coluna/Conteudo
@onready var voltar = $Margens/Painel/Respiro/Coluna/Voltar


func _ready() -> void:
	voltar.pressed.connect(_fechar)
	_adicionar_combos("Dylan", Jogador.MINIRRIFFS, NOTAS_POR_DISPOSITIVO[0])
	_adicionar_combos("Kevin", Baterista.MINIRRIFFS_KEVIN, NOTAS_POR_DISPOSITIVO[1])


func _adicionar_combos(personagem: String, minirriffs: Dictionary, teclado: Array) -> void:
	for sequencia in minirriffs:
		var especial: Dictionary = minirriffs[sequencia]
		_adicionar_celula(personagem)
		_adicionar_celula(especial.nome)
		for teclas in [teclado, NOTAS_POR_DISPOSITIVO[2]]:
			var notas := PackedStringArray()
			for nota in sequencia:
				notas.append(teclas[0] if nota == "A" else teclas[1])
			_adicionar_celula(" ".join(notas))
		_adicionar_celula(str(especial.custo).trim_suffix(".0"))


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


func _adicionar_celula(texto: String) -> void:
	var celula := Label.new()
	celula.text = texto
	celula.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	celula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combos.add_child(celula)
