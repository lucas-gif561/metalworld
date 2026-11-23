extends "res://bosses/base/arena_boss.gd"


func _ao_jogador_entrar(jogador) -> void:
	super._ao_jogador_entrar(jogador)
	if jogador.id_jogador == 2 and jogador.entrando:
		_ajustar_chegada_p2.call_deferred(jogador)


func _ajustar_chegada_p2(jogador) -> void:
	# O P2 chega pela lateral inclinada. O destino precisa ficar dentro do
	# piso mesmo quando o parceiro estiver encostado numa das bordas.
	if Jogo.esta_vivo(jogador) and jogador.entrando:
		var destino: Vector2 = jogador.destino_entrada
		var piso: Line2D = $Arena/LimiteDoPiso
		destino.y = clampf(destino.y, piso.points[0].y + 24.0, piso.points[2].y - 24.0)
		var altura = inverse_lerp(piso.points[0].y, piso.points[3].y, destino.y)
		var esquerda = lerpf(piso.points[0].x, piso.points[3].x, altura) + 32.0
		var direita = lerpf(piso.points[1].x, piso.points[2].x, altura) - 32.0
		destino.x = clampf(destino.x, esquerda, direita)
		jogador.destino_entrada = destino
