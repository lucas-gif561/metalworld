extends Control


func _unhandled_input(event: InputEvent) -> void:
	# START/A no controle do P2 já começa com os dois
	if Controles.controle_p2 >= 0 and event.is_action_pressed(Controles.acao(2, "entrar")):
		Jogo.p2_ativo = true
		Jogo.iniciar_jogo()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed(Controles.acao(1, "entrar")):
		Jogo.iniciar_jogo()
