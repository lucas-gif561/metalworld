extends Node2D
## Minirriff em cima do jogador: cada nota tocada aparece como a tecla (estilo
## Kenney) que o jogador apertou, com o prazo embaixo. Ao terminar, a sequência
## pisca dourada (virou especial) ou vermelha (errou, tempo esgotado ou sem poder).
## Ícones, cores e posições ficam na cena; o código só troca as teclas, porque
## elas mudam a cada nota e dependem de quem toca (P1, P2 ou controle).

@export_group("Teclado P1")
@export var grave_p1: Texture2D
@export var agudo_p1: Texture2D
@export_group("Teclado P2")
@export var grave_p2: Texture2D
@export var agudo_p2: Texture2D
@export_group("Controle")
@export var grave_controle: Texture2D
@export var agudo_controle: Texture2D
@export_group("Visual")
@export var tecla_vazia: Texture2D
@export var cor_vazia := Color(1, 1, 1, 0.35)
@export var cor_acerto := Color(1, 0.85, 0.3)
@export var cor_erro := Color(1, 0.35, 0.35)

@onready var jogador = get_parent()
@onready var teclas: Array = $Teclas.get_children()
@onready var prazo: Node2D = $Prazo
@onready var barra: Control = $Prazo/Barra


func _ready() -> void:
	hide()


func _process(_delta: float) -> void:
	if jogador.caido:
		hide()
		return

	var sequencia: String = jogador.sequencia_minirriff
	if not sequencia.is_empty():
		_mostrar(sequencia, Color.WHITE)
		prazo.show()
		barra.scale.x = clampf(jogador.tempo_minirriff / jogador.janela_minirriff, 0.0, 1.0)
	elif jogador.tempo_mensagem_minirriff > 0.0 and not jogador.ultima_sequencia_minirriff.is_empty():
		var virou_especial = not jogador._especial_pendente.is_empty()
		_mostrar(jogador.ultima_sequencia_minirriff, cor_acerto if virou_especial else cor_erro)
		prazo.hide()
	else:
		hide()


func _mostrar(sequencia: String, cor: Color) -> void:
	show()
	var controle = jogador.minirriff_usando_controle and Controles.controle_do_jogador(jogador.id_jogador) >= 0
	var grave = grave_controle if controle else (grave_p1 if jogador.id_jogador == 1 else grave_p2)
	var agudo = agudo_controle if controle else (agudo_p1 if jogador.id_jogador == 1 else agudo_p2)

	for i in teclas.size():
		var tecla: Sprite2D = teclas[i]
		if i < sequencia.length():
			tecla.texture = grave if sequencia[i] == "A" else agudo
			tecla.modulate = cor
		else:
			tecla.texture = tecla_vazia
			tecla.modulate = cor_vazia
