extends HBoxContainer
## Ícones de um comando só para quem está jogando: a tecla do P1, a do P2 ou o
## botão do controle, sem repetir (dupla no controle = um ícone só; sozinho no
## teclado = só a tecla dele). Os ícones e os espaços ficam na cena; o código
## escolhe quais aparecem, porque isso muda na partida (P2 entra/sai, alguém
## troca do teclado para o controle).

@export var comando := "riff_mode"
@export var tecla_p1: Texture2D
@export var tecla_p2: Texture2D
@export var botao_controle: Texture2D

@onready var espacos: Array = get_children().filter(func(no): return no is TextureRect)


func _ready() -> void:
	Controles.dispositivo_mudou.connect(_ao_mudar)
	Controles.controles_mudaram.connect(_atualizar)
	Jogo.jogador_entrou.connect(_ao_mudar)
	Jogo.jogador_saiu.connect(_ao_mudar)
	_atualizar()


func _ao_mudar(_jogador_ou_id) -> void:
	_atualizar.call_deferred()


func _atualizar() -> void:
	var icones := []
	for id_jogador in Controles.ids_jogando():
		var icone = botao_controle if Controles.usa_controle(id_jogador) else (tecla_p1 if id_jogador == 1 else tecla_p2)
		if icone and not icone in icones:
			icones.append(icone)

	for i in espacos.size():
		espacos[i].visible = i < icones.size()
		if i < icones.size():
			espacos[i].texture = icones[i]
