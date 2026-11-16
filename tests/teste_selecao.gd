extends SceneTree
## Teste da seleção de personagem: cada jogador escolhe o seu, ninguém pega o
## do parceiro, e a fase troca o Dylan gravado pelo personagem escolhido.
## Rode com: tests/rodar_testes.sh

const DYLAN = "res://personagens/dylan/jogador.tscn"
const KEVIN = "res://personagens/baterista/baterista.tscn"

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


func personagem(id_jogador: int) -> String:
	var jogador = jogo.jogador_por_id(id_jogador)
	return jogador.scene_file_path if jogador else ""


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	await _teste_solo()
	await _teste_dueto()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _abrir_selecao(em_dupla: bool) -> Node:
	jogo.personagens = {1: 0, 2: 1}
	change_scene_to_file("res://ui/tela_inicial.tscn")
	await esperar(0.5)
	var menu = current_scene
	menu.get_node("MenuModo/Dueto" if em_dupla else "MenuModo/Solo").pressed.emit()
	await esperar(0.3)
	return menu.selecao


func _teste_solo() -> void:
	print("== Solo com o Kevin")
	var selecao = await _abrir_selecao(false)
	checar(selecao.visible and selecao.cursor[1] == 0, "a seleção abre com o P1 no Dylan")
	checar(not selecao.cartoes[0].get_node("Conteudo/Marcas/P2").visible, "no Solo não aparece o P2")
	await apertar("p1_mover_direita")
	checar(selecao.cursor[1] == 1, "D anda para o Kevin")
	await apertar("p1_atacar")
	checar(selecao.pronto[1], "F confirma")
	await esperar(1.0)
	checar(current_scene.scene_file_path == jogo.FASES[0].cena, "a Rua 1 abre")
	checar(personagem(1) == KEVIN and jogo.jogador_por_id(1).id_jogador == 1, "o P1 é o Kevin")
	checar(current_scene.get_node("Player").scene_file_path == KEVIN, "no lugar do Dylan gravado na fase")
	var rosto = current_scene.get_node("HudJogo/PainelVida/Retrato/Rosto")
	checar(rosto.texture == jogo.jogador_por_id(1).retrato, "o HUD mostra o rosto do Kevin")

	jogo.entrar_p2()
	await esperar(0.5)
	checar(personagem(2) == DYLAN and jogo.jogador_por_id(2).id_jogador == 2, "o P2 que entra no meio fica com o Dylan")

	jogo.reiniciar_fase()
	await esperar(0.5)
	checar(personagem(1) == KEVIN and personagem(2) == DYLAN, "reiniciar a fase mantém os personagens")

	jogo.proxima_fase()
	await esperar(0.5)
	checar(current_scene.scene_file_path == jogo.FASES[1].cena and personagem(1) == KEVIN, "a arena do boss também troca o P1")
	jogo.voltar_ao_inicio()
	await esperar(0.5)


func _teste_dueto() -> void:
	print("== Dueto: cada um o seu")
	var selecao = await _abrir_selecao(true)
	checar(selecao.cursor[1] == 0 and selecao.cursor[2] == 1, "P1 no Dylan e P2 no Kevin")
	await apertar("p2_mover_esquerda")
	checar(selecao.cursor[2] == 0, "seta para a esquerda leva o P2 ao Dylan")
	await apertar("p1_atacar")
	checar(selecao.pronto[1] and selecao.cursor[2] == 1, "P1 pega o Dylan e o P2 sai do cartão dele")
	await apertar("p2_mover_esquerda")
	await apertar("p2_atacar")
	checar(not selecao.pronto[2], "P2 não pode pegar o Dylan do P1")
	await apertar("p1_dodge")
	checar(not selecao.pronto[1], "esquivar desfaz a escolha do P1")
	await apertar("p2_atacar")
	checar(selecao.pronto[2] and selecao.cursor[2] == 0, "agora o P2 pega o Dylan")
	checar(not selecao.pronto[1] and selecao.cursor[1] == 1, "o P1 foi empurrado para o Kevin e ainda não escolheu")
	await apertar("p1_atacar")
	await esperar(1.0)
	checar(current_scene.scene_file_path == jogo.FASES[0].cena, "os dois prontos: a Rua 1 abre")
	checar(personagem(1) == KEVIN and personagem(2) == DYLAN, "P1 Kevin e P2 Dylan")
	jogo.voltar_ao_inicio()
	await esperar(0.5)

	print("== Esc volta ao menu")
	selecao = await _abrir_selecao(false)
	var evento = InputEventKey.new()
	evento.keycode = KEY_ESCAPE
	evento.pressed = true
	Input.parse_input_event(evento)
	await esperar(0.2)
	checar(not selecao.visible and current_scene.menu_modo.visible, "Esc fecha a seleção e volta ao Solo/Dueto")
