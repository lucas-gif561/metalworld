extends SceneTree
## Teste das novidades que voltaram: impacto, barris e comida, ataques do
## boss, fases, escudo, nota maldita, cabo de força (vida compartilhada)
## e "qualquer outro botão fecha o Riff". Rode com: tests/rodar_testes.sh

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


func apertar_tecla(tecla: Key) -> void:
	for pressionado in [true, false]:
		var evento = InputEventKey.new()
		evento.physical_keycode = tecla
		evento.keycode = tecla
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await esperar(0.1)


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	jogo.p2_ativo = true
	await _teste_ruas()
	await _teste_ataques_do_boss()
	await _teste_riff()
	await _teste_cabo_de_forca()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _teste_ruas() -> void:
	print("== Ruas: impacto, barris e comida")
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.6)
	var cena = current_scene
	var combate = root.get_node("Combate")
	var p1 = jogo.jogador_por_id(1)

	combate.pausar(0.2)
	await process_frame
	checar(Engine.time_scale < 0.1, "acerto congela o jogo por um instante")
	await esperar(0.35)
	checar(is_equal_approx(Engine.time_scale, 1.0), "e depois volta ao normal")

	var caixote = cena.get_node("Caixote1")
	checar(caixote.collision_layer & 2, "caixote pode ser atingido pelos tiros")
	caixote.receber_dano(99)
	await esperar(0.2)
	var itens = cena.get_children().filter(func(n): return n.has_method("_physics_process") and n.get("cura") != null)
	checar(itens.size() == 1, "caixote quebrado solta comida")

	if itens.size() == 1:
		p1.timer_invencibilidade.stop()
		p1.receber_dano(2)
		var vida = p1.vida
		p1.global_position = itens[0].global_position
		await esperar(0.3)
		checar(p1.vida == vida + 1 and not is_instance_valid(itens[0]), "comida cura quem pega (%d → %d)" % [vida, p1.vida])


func _boss_1() -> Node:
	change_scene_to_file("res://scenes/main/Bossfight.tscn")
	await esperar(0.6)
	for jogador in jogo.jogadores:
		jogador.invencivel = true
	return current_scene


func _teste_ataques_do_boss() -> void:
	print("== Boss 1: ataques novos")
	var cena = await _boss_1()
	var boss = cena.boss
	checar(cena.cabo.visible and not cena.boss_health_bar.visible, "cabo de força no lugar da barra do boss")

	var antes = get_nodes_in_group("capangas").size()
	boss.invocar_capangas()
	await esperar(0.1)
	checar(get_nodes_in_group("capangas").size() > antes, "boss invoca capangas")

	var posicao = boss.global_position
	await boss.teleporte()
	checar(boss.global_position != posicao and is_equal_approx(boss.modulate.a, 1.0), "teleporte troca o boss de lugar")

	var circulos = []
	var ao_entrar = func(no): if no.get("raio") != null: circulos.append(no)
	boss.get_parent().child_entered_tree.connect(ao_entrar)
	boss.area_no_chao()
	await process_frame
	boss.get_parent().child_entered_tree.disconnect(ao_entrar)
	checar(circulos.size() == 1 and circulos[0].raio == 90.0 and circulos[0].get_node("CollisionShape2D").shape.radius == 90.0, "círculo grande com o dobro do tamanho (raio 90)")
	await esperar(1.0)

	for ataque in ["rajada", "espiral", "trilha_no_chao", "corredor", "area_no_chao"]:
		await boss.call(ataque)
	checar(true, "rajada, espiral, trilha, corredor e área rodam sem erro")

	boss.ativar_escudo()
	checar(boss.escudo_ativo and get_nodes_in_group("runas").size() == 3, "escudo sobe com 3 runas")
	var vida = boss.vida_atual
	boss.receber_dano(10)
	checar(boss.vida_atual == vida, "com escudo o boss não perde vida")
	for runa in get_nodes_in_group("runas"):
		runa.receber_dano(99)
	await process_frame
	checar(not boss.escudo_ativo, "quebrar as runas derruba o escudo")

	boss.descansar()
	await esperar(0.2)
	checar(boss.descansando and boss.sinal_riff.visible, "boss se ajoelha e mostra o aviso do Riff")


func _teste_riff() -> void:
	print("== Riff: fases, nota maldita e fechar com outro botão")
	var cena = await _boss_1()
	var boss = cena.boss
	var riff = cena.riff_hud
	var p1 = jogo.jogador_por_id(1)

	await apertar("p1_riff_mode")
	checar(cena.riff_ativo, "Riff aberto")
	await apertar_tecla(KEY_W)
	checar(not cena.riff_ativo and not p1.bloqueado, "apertar W (andar) fecha o Riff")

	await apertar("p1_riff_mode")
	await apertar("p1_riff_cima")
	checar(cena.riff_ativo, "tocar uma nota não fecha o Riff")

	# Um Riff bom derruba uma fase inteira
	var dano = boss.dano_da_nota(true)
	checar(dano * boss.perfects_por_fase >= boss.vida_referencia * 0.34, "6 PERFECT valem uma fase (%d por nota)" % dano)
	boss.receber_dano(ceili(boss.vida_referencia * 0.4))
	await process_frame
	checar(boss.fase == 2, "boss passa para a fase 2")
	checar(not cena.riff_ativo, "mudar de fase fecha o Riff")
	checar(boss.nota_maldita_disponivel(), "nota maldita liberada na fase 2")

	# Nota maldita machuca quem toca e não fere o boss
	for runa in get_nodes_in_group("runas"):
		runa.receber_dano(99)
	await process_frame
	riff.tocando = true
	p1.invencivel = false
	p1.timer_invencibilidade.stop()
	var vida_p1 = p1.vida
	var vida_boss = boss.vida_atual
	var nota = riff.cena_nota.instantiate()
	riff.notas_container.add_child(nota)
	nota.coluna = 0
	nota.dono = 1
	nota.maldita = true
	nota.velocidade = 0.0
	nota.position = Vector2(13, riff.posicao_acerto)
	riff.verificar_nota(0, 1)
	checar(p1.vida == vida_p1 - 1, "nota maldita tira vida de quem tocou")
	checar(boss.vida_atual >= vida_boss, "nota maldita não fere o boss")
	riff.tocando = false


func _teste_cabo_de_forca() -> void:
	print("== Cabo de força: vida compartilhada")
	var cena = await _boss_1()
	var boss = cena.boss
	var p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	for jogador in [p1, p2]:
		jogador.invencivel = false
		jogador.timer_invencibilidade.stop()

	checar(p1.vida == p2.vida and p1.vida_maxima == 10, "a dupla começa com a mesma vida (%d/%d)" % [p1.vida, p1.vida_maxima])
	var vida_boss = boss.vida_atual
	p1.receber_dano(1)
	await process_frame
	checar(p1.vida == 4 and p2.vida == 4, "dano no P1 tira dos dois")
	checar(boss.vida_atual > vida_boss, "e enche o boss (%d → %d)" % [vida_boss, boss.vida_atual])

	boss.receber_dano(int(cena.vida_boss_por_vida_dupla * 2))
	await process_frame
	checar(p1.vida == 6 and p2.vida == 6, "dano no boss enche a dupla (%d)" % p1.vida)

	var game_over = [false]
	jogo.game_over.connect(func(): game_over[0] = true)
	p2.timer_invencibilidade.stop()
	p2.receber_dano(99)
	await esperar(0.2)
	checar(p1.caido and p2.caido, "vida da dupla zerou: os dois caem juntos")
	checar(game_over[0] and cena.fim_de_jogo, "e é game over")
