extends Control
## Riscos finos sobre a barra de vida do boss: um em cada ponto em que ele
## ainda muda de fase. Quando a fase passa, o risco some.
## Quem é dono da barra (cabo de força ou barra comum) diz onde cada um fica,
## porque as posições mudam durante a luta.

@export var cor := Color(1, 1, 1, 0.45)
@export var largura: float = 2.0

## Posição de cada risco, de 0 (início da barra) a 1 (fim)
var posicoes: Array = []


func definir(novas: Array) -> void:
	if novas == posicoes:
		return
	posicoes = novas
	queue_redraw()


func _draw() -> void:
	for posicao in posicoes:
		var x = clampf(posicao, 0.0, 1.0) * size.x
		draw_rect(Rect2(x - largura / 2.0, 0.0, largura, size.y), cor)
