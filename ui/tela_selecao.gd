extends ColorRect
## Seleção de personagem: aparece depois de "Solo" ou "Dueto" no menu.
##
## Cada jogador anda entre os cartões com os próprios comandos (esquerda e
## direita), confirma com atacar, entrar ou A e desfaz a escolha com esquivar.
## No Solo só o P1 escolhe; no Dueto os dois confirmam e não podem pegar o
## mesmo personagem. Esc (ou esquivar do P1 antes de escolher) volta ao menu.
##
## Os cartões ficam na cena (tela_selecao.tscn), na mesma ordem de
## Jogo.PERSONAGENS. Aqui fica só o comportamento: quem está em qual cartão.

signal confirmada
signal cancelada

## Tempo sem ler comandos ao abrir, para o botão que abriu a tela não
## escolher um personagem no mesmo instante
const ESPERA_AO_ABRIR = 0.2
## Pausa com os dois "PRONTO" na tela antes de começar a fase
const ESPERA_AO_CONFIRMAR = 0.5

## Borda do cartão sem ninguém em cima
@export var cor_livre := Color(0.45, 0.38, 0.55)

@onready var cartoes: Array = $Margens/Painel/Respiro/Coluna/Cartoes.get_children()

var em_dupla := false
var cursor := {1: 0, 2: 1}
var pronto := {1: false, 2: false}
var _espera := 0.0
var _iniciando := false


func abrir(dupla: bool) -> void:
	em_dupla = dupla
	cursor = {1: Jogo.personagens[1], 2: Jogo.personagens[2]}
	pronto = {1: false, 2: false}
	_espera = ESPERA_AO_ABRIR
	_iniciando = false
	show()
	_atualizar()


func _ids() -> Array:
	return [1, 2] if em_dupla else [1]


func _process(delta: float) -> void:
	if not visible or _iniciando:
		return
	if _espera > 0.0:
		_espera -= delta
		return
	for id_jogador in _ids():
		if pronto[id_jogador]:
			if _apertou(id_jogador, "dodge"):
				pronto[id_jogador] = false
				Audio.tocar("nota_good", 0.0)
				_atualizar()
			continue
		if _apertou(id_jogador, "mover_esquerda"):
			_mover(id_jogador, -1)
		elif _apertou(id_jogador, "mover_direita"):
			_mover(id_jogador, 1)
		elif _apertou(id_jogador, "atacar") or _apertou(id_jogador, "entrar") or _apertou(id_jogador, "riff_mode"):
			_confirmar(id_jogador)
		elif id_jogador == 1 and _apertou(1, "dodge"):
			_cancelar()
			return


func _unhandled_input(evento: InputEvent) -> void:
	if visible and not _iniciando and evento is InputEventKey and evento.pressed and evento.keycode == KEY_ESCAPE:
		_cancelar()
		get_viewport().set_input_as_handled()


func _apertou(id_jogador: int, nome: String) -> bool:
	return Input.is_action_just_pressed(Controles.acao(id_jogador, nome))


func _mover(id_jogador: int, passo: int) -> void:
	cursor[id_jogador] = wrapi(cursor[id_jogador] + passo, 0, cartoes.size())
	Audio.tocar("nota_good", 0.0)
	_atualizar()


func _confirmar(id_jogador: int) -> void:
	var outro = 2 if id_jogador == 1 else 1
	if em_dupla and pronto[outro] and cursor[outro] == cursor[id_jogador]:
		# Já é do parceiro: o cartão treme e nada muda
		Audio.tocar("nota_miss", 0.0)
		_tremer(cartoes[cursor[id_jogador]])
		return
	pronto[id_jogador] = true
	Audio.tocar("ui_confirma", 0.0)
	# O parceiro que ainda não escolheu sai do cartão que acabou de ser pego
	if em_dupla and not pronto[outro] and cursor[outro] == cursor[id_jogador]:
		cursor[outro] = wrapi(cursor[outro] + 1, 0, cartoes.size())
	_atualizar()
	if _ids().all(func(id): return pronto[id]):
		_iniciar()


func _iniciar() -> void:
	_iniciando = true
	await get_tree().create_timer(ESPERA_AO_CONFIRMAR).timeout
	Jogo.escolher_personagens(cursor[1], cursor[2] if em_dupla else -1)
	confirmada.emit()


func _cancelar() -> void:
	hide()
	cancelada.emit()


func _tremer(cartao: Control) -> void:
	var tween = create_tween()
	for desvio in [8.0, -8.0, 5.0, 0.0]:
		tween.tween_property(cartao, "position:x", cartao.position.x + desvio, 0.04)


## Borda, marcas e brilho de cada cartão. A cor da borda muda em código porque
## depende de quem está em cima do cartão (P1 azul, P2 rosa).
func _atualizar() -> void:
	for i in cartoes.size():
		var cartao: Control = cartoes[i]
		var marcas = cartao.get_node("Conteudo/Marcas")
		var de: Array = _ids().filter(func(id): return cursor[id] == i)
		for id_jogador in [1, 2]:
			var marca: Label = marcas.get_node("P%d" % id_jogador)
			marca.visible = id_jogador in de
			marca.text = "P%d PRONTO" % id_jogador if pronto[id_jogador] else "P%d" % id_jogador
		var escolhido = de.filter(func(id): return pronto[id])
		var borda: Color = cor_livre
		if not escolhido.is_empty():
			borda = Jogo.cor(escolhido[0])
		elif not de.is_empty():
			borda = Jogo.cor(de[0]).lerp(Color.WHITE, 0.35)
		cartao.get_theme_stylebox("panel").border_color = borda
		var sprite: AnimatedSprite2D = cartao.get_node("Conteudo/Palco/Sprite")
		sprite.modulate = Color.WHITE if not de.is_empty() else Color(0.55, 0.5, 0.6)
