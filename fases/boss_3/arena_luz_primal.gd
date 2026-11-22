extends "res://bosses/base/arena_boss.gd"

@onready var limite_entrada_p2: Marker2D = $Arena/LimiteEntradaP2


func _ao_jogador_entrar(jogador) -> void:
	super._ao_jogador_entrar(jogador)
	if jogador.id_jogador == 2 and jogador.entrando:
		_ajustar_chegada_p2.call_deferred(jogador)


func _ajustar_chegada_p2(jogador) -> void:
	# Jogo define o destino depois de emitir jogador_entrou. A margem à
	# esquerda impede que o P2 termine a corrida do lado de fora da parede.
	if Jogo.esta_vivo(jogador) and jogador.entrando:
		jogador.destino_entrada.x = maxf(jogador.destino_entrada.x, limite_entrada_p2.global_position.x)
