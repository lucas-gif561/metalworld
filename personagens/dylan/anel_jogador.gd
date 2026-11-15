@tool
extends Node2D
## Anel colorido no pé do jogador. A cor é trocada pelo jogador ao entrar
## (P1 rosa, P2 azul); o achatamento vem da escala do nó.
## Também mostra a recarga do dodge: depois de esquivar, o anel fica apagado
## e vai se completando (sentido horário, a partir da frente) até o dodge voltar.

@export var cor := Color(1.0, 0.3, 0.72, 0.85):
	set(valor):
		cor = valor
		queue_redraw()
@export var raio := 26.0:
	set(valor):
		raio = valor
		queue_redraw()
@export var espessura := 3.0:
	set(valor):
		espessura = valor
		queue_redraw()
## 0 = dodge acabou de ser usado, 1 = dodge pronto (anel inteiro).
@export_range(0.0, 1.0) var progresso := 1.0:
	set(valor):
		valor = clampf(valor, 0.0, 1.0)
		if is_equal_approx(valor, progresso):
			return
		progresso = valor
		queue_redraw()
## Opacidade do trecho do anel que ainda está recarregando.
@export_range(0.0, 1.0) var opacidade_recarga := 0.25:
	set(valor):
		opacidade_recarga = valor
		queue_redraw()


func _draw() -> void:
	if progresso >= 1.0:
		draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, cor, espessura)
		return
	var apagada = Color(cor, cor.a * opacidade_recarga)
	draw_arc(Vector2.ZERO, raio, 0.0, TAU, 32, apagada, espessura)
	if progresso > 0.0:
		# Começa embaixo (frente do anel achatado, onde o jogador mais vê) e gira.
		var inicio = PI / 2.0
		var pontos = maxi(int(32 * progresso), 2)
		draw_arc(Vector2.ZERO, raio, inicio, inicio + TAU * progresso, pontos, cor, espessura)
