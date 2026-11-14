@tool
extends Node2D
## Círculo "segure para levantar" que aparece sobre o jogador caído
## e enche enquanto o parceiro segura interagir perto dele. Em cima, o ícone
## do botão de interagir do PARCEIRO (E do P1, L do P2 ou B no controle),
## pulsando. Os ícones ficam no Inspector; o tamanho na tela é altura_icone.

@export var icone_teclado_p1: Texture2D
@export var icone_teclado_p2: Texture2D
@export var icone_controle: Texture2D
## Altura do ícone na tela (px), qualquer que seja o tamanho da imagem
@export var altura_icone := 24.0

var _tween_botao: Tween

@export var cor := Color(1.0, 0.3, 0.72):
	set(valor):
		cor = valor
		queue_redraw()
@export_range(0.0, 1.0) var progresso := 0.0:
	set(valor):
		progresso = valor
		queue_redraw()
@export var raio := 16.0:
	set(valor):
		raio = valor
		queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 5.0)
	if progresso > 0.0:
		draw_arc(Vector2.ZERO, raio, -PI / 2, -PI / 2 + TAU * progresso, 32, cor, 5.0)


## Mostra o círculo com o botão de quem pode levantar (o parceiro)
func mostrar_para(id_parceiro: int) -> void:
	var botao = $Botao
	if Controles.controle_do_jogador(id_parceiro) >= 0:
		botao.texture = icone_controle
	else:
		botao.texture = icone_teclado_p1 if id_parceiro == 1 else icone_teclado_p2
	var base = Vector2.ONE * altura_icone / botao.texture.get_height()
	botao.scale = base
	show()
	# Pulsa como um "aperte e segure"
	if _tween_botao:
		_tween_botao.kill()
	_tween_botao = create_tween().set_loops()
	_tween_botao.tween_property(botao, "scale", base * 1.2, 0.35)
	_tween_botao.tween_property(botao, "scale", base, 0.35)
