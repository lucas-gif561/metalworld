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
	await _teste_pausa()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _teste_rua() -> void:
	print("== Rua: entrada do P2, mira, reviver e game over")
	jogo.p2_ativo = false
	change_scene_to_file("res://fases/rua_1/rua_1.tscn")
	await esperar(0.6)
	var cena = current_scene
	checar(jogo.jogadores.size() == 1, "começa só com o P1")
	await process_frame
	checar(cena.hud.vaga_p2.visible, "vaga do P2 piscando no HUD")

	await apertar("p2_entrar")
	var p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	checar(p2 != null and p2.entrando and p2.global_position.x < p1.global_position.x - 70, "P2 chega correndo de fora da tela")
	await esperar(1.0)
	checar(p2 != null and not p2.entrando, "P2 terminou a entrada e já joga")
	checar(not cena.hud.vaga_p2.visible, "vaga do P2 sumiu")
	checar(p2 != null and jogo.p2_ativo, "P2 entrou apertando START")
	checar(cena.hud.paineis[2].visible, "painel de vida do P2 apareceu")
	checar(p2 != null and p2.sprite.sprite_frames.resource_path == "res://personagens/baterista/sprites/baterista.tres",
		"P2 usa os sprites do Kevin")

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
	p2.timer_invencibilidade.stop() # algum inimigo pode ter acertado antes
	p2.receber_dano(99)
	await esperar(0.2)
	checar(p2.caido, "P2 caiu com a vida zerada")
	checar(not game_over[0], "sem game over com o P1 de pé")
	checar(cena.hud.paineis[2].get_node("Retrato").modulate != Color.WHITE, "HUD mostra P2 CAÍDO")
	checar(cena.hud.paineis[2].get_node("Icones/Coracoes").get_children().all(func(c): return c.value == 0.0), "HUD mostra os corações do P2 vazios")

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
	print("== Boss: Riffs independentes")
	change_scene_to_file("res://fases/boss_1/boss_1.tscn")
	await esperar(0.6)
	for riff_jogador in current_scene.riffs.values():
		riff_jogador.trava_restante = 0.0 # pula a trava de entrada na arena
	var cena = current_scene
	var riff_p1 = cena.riffs[1]
	var riff_p2 = cena.riffs[2]
	var p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	p1.invencivel = true
	p2.invencivel = true
	cena.boss.usar_fases = false
	checar(riff_p1.global_position.x < riff_p2.global_position.x, "pistas do P1 à esquerda e do P2 à direita")

	await apertar("p2_riff_mode")
	checar(riff_p2.tocando and riff_p2.visible and p2.bloqueado, "P2 abre o próprio Riff")
	checar(not riff_p1.tocando and not riff_p1.visible and not p1.bloqueado, "P1 continua livre")
	await esperar(1.0)
	checar(not riff_p2._notas().is_empty() and riff_p2._notas().all(func(nota): return nota.dono == 2), "P2 recebe apenas as próprias notas")

	var vida = cena.boss.vida_atual
	var dano = riff_p2.dano_perfect
	_nota_na_linha(riff_p2)
	await apertar("p1_riff_esquerda")
	checar(is_equal_approx(cena.boss.vida_atual, vida), "P1 não acerta nota do P2")
	await apertar("p2_riff_esquerda")
	checar(is_equal_approx(cena.boss.vida_atual, vida - dano * 0.5), "acerto do P2 sozinho causa 0,5x")

	await apertar("p1_riff_mode")
	checar(riff_p1.tocando and riff_p2.tocando, "P1 pode entrar com o Riff do P2 aberto")
	vida = cena.boss.vida_atual
	_nota_na_linha(riff_p1)
	await apertar("p1_riff_esquerda")
	checar(is_equal_approx(cena.boss.vida_atual, vida - dano * 1.0), "acerto em dupla causa 1x de dano")

	await apertar("p1_dodge")
	checar(not riff_p1.tocando and riff_p1.travado() and not p1.bloqueado and p1.recarga_dodge_restante > 0.0, "P1 sai do próprio Riff esquivando")
	checar(riff_p2.tocando and not riff_p2.travado() and p2.bloqueado, "P2 continua tocando")

	await esperar(p1.duracao_dodge + 0.1)
	p1.invencivel = false
	p1.timer_invencibilidade.stop()
	p1.receber_dano(1)
	checar(riff_p2.tocando, "dano em P1 não interrompe o Riff de P2")
	p2.invencivel = false
	p2.timer_invencibilidade.stop()
	p2.receber_dano(1)
	checar(not riff_p2.tocando and riff_p2.trava_total == riff_p2.trava_por_dano, "dano em P2 interrompe e trava suas pistas")


func _nota_na_linha(riff) -> void:
	riff._criar_nota(0, riff.id_jogador, false)
	var nota = riff._notas().back()
	nota.velocidade = 0.0
	nota.position.y = riff.posicao_acerto


func _teste_solo() -> void:
	print("== Solo")
	jogo.p2_ativo = false
	change_scene_to_file("res://fases/rua_1/rua_1.tscn")
	await esperar(0.6)
	var cena = current_scene
	checar(jogo.jogadores.size() == 1, "sozinho: só o P1")
	jogo.jogador_por_id(1).receber_dano(99)
	await esperar(0.2)
	checar(cena.fim_de_jogo, "sozinho: cair é game over")
	await apertar("p2_entrar")
	await esperar(0.2)
	checar(jogo.jogadores.size() == 1 and not jogo.p2_ativo, "P2 não entra na tela de game over")
	await apertar("p1_reiniciar")
	await esperar(0.8)
	await apertar("p2_entrar")
	await esperar(0.2)
	checar(jogo.jogadores.size() == 2, "depois de reiniciar o P2 pode entrar de novo")


func _teste_reiniciar_boss() -> void:
	print("== Reiniciar no meio do ataque do boss")
	jogo.p2_ativo = true
	for cena in ["res://fases/boss_1/boss_1.tscn", "res://fases/boss_2/boss_2.tscn", "res://fases/boss_3/boss_3.tscn"]:
		change_scene_to_file(cena)
		await esperar(4.5)
		jogo.reiniciar_fase()
		await esperar(1.5)
		checar(jogo.jogadores.size() == 2, "recarregou " + cena.get_file() + " (erros de script aparecem no rodar_testes.sh)")


func _teste_pausa() -> void:
	print("== Pause: continuar e remover o P2")
	jogo.p2_ativo = true
	change_scene_to_file("res://fases/rua_1/rua_1.tscn")
	await esperar(0.6)
	var cena = current_scene
	var pausa = cena.hud.get_node("MenuPausa")
	checar(jogo.jogadores.size() == 2, "começa com P1 e P2")

	await apertar("p1_pausar")
	checar(paused and pausa.visible, "ESC pausa o jogo e abre o menu")
	checar(pausa.botao_remover_p2.visible, "opção de remover o P2 aparece em dupla")
	await apertar("p1_pausar")
	checar(not paused and not pausa.visible, "ESC de novo continua")

	await apertar("p2_pausar")
	checar(paused, "START do P2 também pausa")
	pausa.botao_remover_p2.pressed.emit()
	await esperar(0.2)
	checar(not paused, "remover o P2 volta ao jogo")
	checar(jogo.jogadores.size() == 1 and not jogo.p2_ativo, "P2 saiu da partida")
	checar(not cena.hud.paineis[2].visible, "painel do P2 sumiu do HUD")

	await apertar("p1_pausar")
	checar(not pausa.botao_remover_p2.visible, "sozinho, a opção de remover o P2 some")
	await apertar("p1_pausar")

	await apertar("p2_entrar")
	await esperar(0.2)
	checar(jogo.jogadores.size() == 2 and cena.hud.paineis[2].visible, "P2 entra de novo com START")
