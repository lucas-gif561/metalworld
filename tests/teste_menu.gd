extends SceneTree
## Teste do menu principal: navegação, Controles/Créditos e iniciar
## sozinho ou em dupla. Rode com: tests/rodar_testes.sh

var jogo: Node
var falhas := 0


func checar(condicao: bool, texto: String) -> void:
	if condicao:
		print("  ok    ", texto)
	else:
		falhas += 1
		print("  FALHOU ", texto)


func esperar(segundos: float) -> void:
	await create_timer(segundos, true, false, true).timeout


func apertar(acao: String) -> void:
	for pressionado in [true, false]:
		var evento = InputEventAction.new()
		evento.action = acao
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await esperar(0.1)


func focado() -> String:
	var no = root.gui_get_focus_owner()
	return no.name if no else ""


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	print("== Menu principal")
	change_scene_to_file("res://ui/tela_inicial.tscn")
	await esperar(0.5)
	var menu = current_scene
	checar(focado() == "JogarSozinho", "começa com 'Jogar sozinho' aceso")

	await apertar("p1_mover_baixo")
	checar(focado() == "JogarDupla", "S desce para 'Jogar em dupla'")
	await esperar(0.2)
	await apertar("ui_down")
	checar(focado() == "Controles", "seta para baixo desce para 'Controles'")
	await esperar(0.2)
	await apertar("p1_mover_cima")
	checar(focado() == "JogarDupla", "W sobe de volta")
	await esperar(0.2)
	await apertar("p1_mover_cima")
	await esperar(0.2)
	await apertar("p1_mover_cima")
	checar(focado() == "Creditos", "subir do primeiro dá a volta para o último")

	await apertar("p1_atacar")
	checar(menu.janela.visible and menu.titulo_janela.text == "Créditos", "J abre a janela de Créditos")
	await apertar("p1_dodge")
	checar(not menu.janela.visible, "qualquer botão fecha a janela")

	menu.get_node("Menu/JogarDupla").grab_focus()
	await esperar(0.2)
	await apertar("p1_atacar")
	await esperar(0.8)
	checar(current_scene != null and current_scene.scene_file_path == jogo.FASES[0].cena, "'Jogar em dupla' abre a Rua 1")
	checar(jogo.p2_ativo and jogo.jogadores.size() == 2, "e já começa com os dois jogadores")

	jogo.voltar_ao_inicio()
	await esperar(0.6)
	current_scene.get_node("Menu/JogarSozinho").grab_focus()
	await esperar(0.2)
	await apertar("p2_entrar")
	await esperar(0.8)
	checar(not jogo.p2_ativo and jogo.jogadores.size() == 1, "START em 'Jogar sozinho' começa só com o P1")

	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)
