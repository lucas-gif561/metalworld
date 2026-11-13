extends SceneTree
## Teste rápido: joga as 6 fases em sequência com 2 jogadores, forçando a
## vitória em cada uma, e confere se a corrente inteira funciona.
## Rode com: tests/rodar_testes.sh

var jogo: Node
var falhas := 0


func checar(condicao: bool, texto: String) -> void:
	if condicao:
		print("  ok    ", texto)
	else:
		falhas += 1
		print("  FALHOU ", texto)


func esperar(segundos: float) -> void:
	await create_timer(segundos).timeout


## Aperta e solta um botão como se fosse o jogador (passa pela fila de entrada)
func apertar(acao: String, segurar := 0.1) -> void:
	_evento(acao, true)
	await esperar(segurar)
	_evento(acao, false)
	await process_frame


func _evento(acao: String, pressionado: bool) -> void:
	var evento = InputEventAction.new()
	evento.action = acao
	evento.pressed = pressionado
	Input.parse_input_event(evento)


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	jogo.p2_ativo = true
	change_scene_to_file(jogo.FASES[0].cena)
	await esperar(0.5)

	for i in jogo.FASES.size():
		var fase = jogo.FASES[i]
		print("== ", fase.nome)
		checar(current_scene != null and current_scene.scene_file_path == fase.cena, "abriu " + fase.cena)
		checar(jogo.jogadores.size() == 2, "dois jogadores na fase")

		# Os dois andam e atiram um pouco
		for acao in ["p1_mover_direita", "p2_mover_direita", "p1_atacar", "p2_atacar"]:
			Input.action_press(acao)
		await esperar(0.6)
		for acao in ["p1_mover_direita", "p2_mover_direita", "p1_atacar", "p2_atacar"]:
			Input.action_release(acao)

		if current_scene.has_node("Portal"):
			await _vencer_rua()
		else:
			await _vencer_boss()

		await esperar(0.6)

	checar(current_scene != null and current_scene.scene_file_path == jogo.CENA_INICIO, "voltou para a tela inicial no fim")
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _vencer_rua() -> void:
	var cena = current_scene
	var portal = cena.get_node("Portal")
	var limite = Time.get_ticks_msec() + 40000

	while not portal.ativado and Time.get_ticks_msec() < limite:
		for inimigo in get_nodes_in_group("inimigos"):
			inimigo.receber_dano(999)
		# Leva o P1 até a borda direita para a câmera andar
		if cena.gerenciador_ondas.arena_liberada and not cena.em_transicao:
			var p1 = jogo.jogador_por_id(1)
			p1.global_position.x = cena.limites_arena().end.x + 5
		await esperar(0.3)

	checar(portal.ativado, "rua concluída e portal aberto (%d arenas)" % cena.quantidade_arenas())
	if portal.ativado:
		var p1 = jogo.jogador_por_id(1)
		p1.global_position = portal.global_position
		await esperar(0.2)
		await apertar("p1_interagir")
		await esperar(0.5)


func _vencer_boss() -> void:
	var cena = current_scene
	var boss = cena.boss
	checar(boss != null, "boss encontrado")
	boss.receber_dano(boss.vida_atual)
	var limite = Time.get_ticks_msec() + 8000
	while not cena.venceu and Time.get_ticks_msec() < limite:
		await esperar(0.2)
	checar(cena.venceu, "boss derrotado e tela de vitória")
	await apertar("p2_reiniciar")
	await esperar(0.5)
