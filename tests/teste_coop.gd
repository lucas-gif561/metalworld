extends SceneTree
## Teste do co-op: P2 entrando, mira dos inimigos, reviver, game over
## e Riff em revezamento. Rode com: tests/rodar_testes.sh

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


func segurar(acao: String, segundos: float) -> void:
	_evento(acao, true)
	await esperar(segundos)
	_evento(acao, false)
	await process_frame


func apertar(acao: String) -> void:
	await segurar(acao, 0.1)


func _evento(acao: String, pressionado: bool) -> void:
	var evento = InputEventAction.new()
	evento.action = acao
	evento.pressed = pressionado
	Input.parse_input_event(evento)


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	await _teste_rua()
	await _teste_boss()
	await _teste_solo()
	await _teste_reiniciar_boss()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _teste_rua() -> void:
	print("== Rua: entrada do P2, mira, reviver e game over")
	jogo.p2_ativo = false
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.6)
	var cena = current_scene
	checar(jogo.jogadores.size() == 1, "começa só com o P1")

	await apertar("p2_entrar")
	await esperar(0.2)
	var p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	checar(p2 != null and jogo.p2_ativo, "P2 entrou apertando START")
	checar(cena.hud.paineis[2].visible, "painel de vida do P2 apareceu")
	checar(p2.sprite.material != null, "P2 com outra cor")

	# Mira: o inimigo persegue quem está mais perto
	await esperar(1.0)
	var inimigos = get_nodes_in_group("inimigos")
	checar(not inimigos.is_empty(), "inimigos na arena")
	if not inimigos.is_empty():
		var inimigo = inimigos[0]
		inimigo.global_position = Vector2(700, 450)
		p1.global_position = Vector2(150, 350)
		p2.global_position = Vector2(780, 450)
		await esperar(0.7)
		checar(inimigo.jogador == p2, "inimigo mira o P2 (mais perto)")
		p2.global_position = Vector2(150, 550)
		p1.global_position = Vector2(780, 450)
		await esperar(0.7)
		checar(inimigo.jogador == p1, "inimigo troca para o P1 quando ele fica mais perto")

	for inimigo in get_nodes_in_group("inimigos"):
		inimigo.set_physics_process(false)

	# Reviver
	var game_over = [false]
	jogo.game_over.connect(func(): game_over[0] = true)
	p2.receber_dano(99)
	await esperar(0.2)
	checar(p2.caido, "P2 caiu com a vida zerada")
	checar(not game_over[0], "sem game over com o P1 de pé")
	checar(cena.hud.paineis[2].get_node("TextoVida").text.contains("CAÍDO"), "HUD mostra P2 CAÍDO")

	p1.global_position = p2.global_position + Vector2(40, 0)
	await segurar("p1_interagir", 0.8)
	checar(p2.caido and p2.progresso_reviver > 0.2, "segurar um pouco enche o círculo (%.2f)" % p2.progresso_reviver)
	await esperar(1.0)
	checar(p2.progresso_reviver < 0.05, "soltar esvazia o círculo")
	await segurar("p1_interagir", 2.3)
	checar(not p2.caido and p2.vida == 3, "P2 levantou com metade da vida (%d)" % p2.vida)

	# Game over só quando os dois caem
	p1.timer_invencibilidade.stop()
	p2.timer_invencibilidade.stop()
	p1.receber_dano(99)
	await esperar(0.1)
	checar(not game_over[0], "um caído não é game over")
	p2.receber_dano(99)
	await esperar(0.3)
	checar(game_over[0] and cena.fim_de_jogo, "dois caídos = game over")

	await apertar("p2_reiniciar")
	await esperar(0.8)
	checar(jogo.jogadores.size() == 2, "reiniciar mantém os dois jogadores")


func _teste_boss() -> void:
	print("== Boss: Riff em revezamento")
	change_scene_to_file("res://scenes/main/Bossfight.tscn")
	await esperar(0.6)
	var cena = current_scene
	var riff = cena.riff_hud
	var p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	checar(p1 != null and p2 != null, "os dois jogadores no boss")
	# Ninguém toma dano no meio do teste (com a vida compartilhada isso cura o boss)
	p1.invencivel = true
	p2.invencivel = true

	await apertar("p2_riff_mode")
	checar(cena.riff_ativo and p1.bloqueado and p2.bloqueado, "P2 abre o Riff e os dois ficam tocando")

	riff.bpm = 600.0
	await esperar(2.2)
	var donos = []
	for nota in riff._notas():
		donos.append(nota.dono)
	donos.reverse() # a mais antiga primeiro
	print("  donos das notas: ", donos)
	var trocas = 0
	for i in range(1, donos.size()):
		if donos[i] != donos[i - 1]:
			trocas += 1
	checar(donos.size() >= 8 and 1 in donos and 2 in donos and trocas <= donos.size() / 4 + 1, "notas em blocos alternando P1 e P2")

	# Só o dono da nota acerta
	riff.parar_riff()
	await process_frame
	riff.tocando = true
	var vida = cena.boss.vida_atual
	var nota = riff.cena_nota.instantiate()
	riff.notas_container.add_child(nota)
	nota.coluna = 1 # pista ↑
	nota.dono = 2
	nota.velocidade = 0.0
	nota.position = Vector2(74, riff.posicao_acerto)
	riff.verificar_nota(1, 1)
	checar(cena.boss.vida_atual == vida and is_instance_valid(nota) and not nota.acertada, "P1 não acerta nota do P2")
	await apertar("p2_riff_cima")
	checar(cena.boss.vida_atual == vida - cena.boss.dano_da_nota(true), "P2 acerta a própria nota pelo controle (PERFECT)")

	# Com um caído, todas as notas vão para quem está de pé
	p2.morrer()
	await esperar(0.1)
	riff.notas_no_bloco = 0
	var donos_solo = []
	for i in 6:
		donos_solo.append(riff._proximo_dono())
	checar(donos_solo.all(func(d): return d == 1), "P2 caído: notas só do P1")

	await apertar("p1_riff_mode")
	checar(not cena.riff_ativo and not p1.bloqueado, "P1 fecha o Riff")
	p2.reviver()


func _teste_solo() -> void:
	print("== Solo")
	jogo.p2_ativo = false
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.6)
	var cena = current_scene
	checar(jogo.jogadores.size() == 1, "sozinho: só o P1")
	jogo.jogador_por_id(1).receber_dano(99)
	await esperar(0.2)
	checar(cena.fim_de_jogo, "sozinho: cair é game over")


func _teste_reiniciar_boss() -> void:
	print("== Reiniciar no meio do ataque do boss")
	jogo.p2_ativo = true
	for cena in ["res://scenes/main/Bossfight.tscn", "res://fases/boss_2/boss_2.tscn", "res://fases/boss_3/boss_3.tscn"]:
		change_scene_to_file(cena)
		await esperar(4.5)
		jogo.reiniciar_fase()
		await esperar(1.5)
		checar(jogo.jogadores.size() == 2, "recarregou " + cena.get_file() + " (erros de script aparecem no rodar_testes.sh)")
