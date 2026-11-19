extends SceneTree
## Teste da seleção de personagem: cada jogador escolhe o seu, ninguém pega o
## do parceiro, e a fase troca o Dylan gravado pelo personagem escolhido.
## Rode com: tests/rodar_testes.sh

const DYLAN = "res://personagens/dylan/jogador.tscn"
const KEVIN = "res://personagens/baterista/baterista.tscn"
const MIKU = "res://personagens/miku/miku.tscn"

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
		# A seleção lê a tecla no _process (is_action_just_pressed): segura por
		# pelo menos dois quadros, senão um quadro lento engole o aperto
		await process_frame
		await process_frame
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
	await _teste_miku()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _abrir_selecao(em_dupla: bool) -> Node:
	jogo.personagens = {1: 0, 2: 1}
	change_scene_to_file("res://ui/tela_inicial.tscn")
	await esperar(0.5)
	var menu = current_scene
	menu.get_node("MenuModo/Dueto" if em_dupla else "MenuModo/Solo").pressed.emit()
	await esperar(0.3)
	# Logo depois de abrir, a seleção ignora as teclas por ESPERA_AO_ABRIR
	var limite = Time.get_ticks_msec() + 3000
	while menu.selecao._espera > 0.0 and Time.get_ticks_msec() < limite:
		await process_frame
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


func _teste_miku() -> void:
	print("== Miku secreta (F10)")
	var dylan = load(DYLAN).instantiate()
	var miku = load(MIKU).instantiate()
	var faltando = Array(dylan.get_node("AnimatedSprite2D").sprite_frames.get_animation_names()).filter(
		func(nome): return not miku.get_node("AnimatedSprite2D").sprite_frames.has_animation(nome))
	checar(faltando.is_empty(), "a Miku tem todas as animações do Dylan %s" % [faltando])
	checar(miku.get_script() == dylan.get_script() and miku._minirriffs_disponiveis() == dylan._minirriffs_disponiveis(), "e os mesmos minirriffs do Dylan")
	dylan.free()
	miku.free()

	var selecao = await _abrir_selecao(false)
	checar(not selecao.cartao_secreto.visible, "o cartão da Miku começa escondido")
	await apertar("p1_mover_direita")
	await apertar("p1_mover_direita")
	checar(selecao.cursor[1] == 0, "sem o segredo, passar do Kevin volta ao Dylan")
	var evento = InputEventKey.new()
	evento.keycode = KEY_F10
	evento.pressed = true
	Input.parse_input_event(evento)
	await esperar(0.2)
	checar(selecao.cartao_secreto.visible, "F10 mostra a Miku")
	await apertar("p1_mover_esquerda")
	checar(selecao.cursor[1] == 2, "e ela fica depois do Kevin")
	await apertar("p1_atacar")
	await esperar(1.0)
	checar(personagem(1) == MIKU and jogo.jogador_por_id(1).id_jogador == 1, "o P1 joga com a Miku")
	jogo.entrar_p2()
	await esperar(0.5)
	checar(personagem(2) == DYLAN, "o P2 que entra no meio fica com o Dylan, não com outro segredo")
	jogo.voltar_ao_inicio()
	await esperar(0.5)
	selecao = await _abrir_selecao_sem_resetar(false)
	checar(selecao.cartao_secreto.visible and selecao.cursor[1] == 2, "quem jogou com a Miku volta com o cartão dela aberto")


func _abrir_selecao_sem_resetar(em_dupla: bool) -> Node:
	change_scene_to_file("res://ui/tela_inicial.tscn")
	await esperar(0.5)
	current_scene.get_node("MenuModo/Dueto" if em_dupla else "MenuModo/Solo").pressed.emit()
	await esperar(0.3)
	return current_scene.selecao
