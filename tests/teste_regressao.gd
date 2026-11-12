extends SceneTree
# Regressão do jogo inteiro: ruas, portal, boss, Riff, cabo de força e teclas.
# Rodar: Godot --headless --path . --script tests/teste_regressao.gd

var falhas = 0


func ok(condicao, mensagem):
	print(("  OK   " if condicao else "  FALHA ") + mensagem)
	if not condicao:
		falhas += 1


func esperar(segundos):
	await create_timer(segundos, true, false, true).timeout


func _initialize():
	_rodar()


func abrir(caminho):
	change_scene_to_file(caminho)
	await esperar(0.3)
	return current_scene


func inimigos(cena):
	return cena.get_children().filter(func(n): return n is CharacterBody2D and not n.is_in_group("jogador"))


func tecla(acao):
	var eventos = InputMap.action_get_events(acao)
	return eventos[0].physical_keycode if eventos.size() == 1 else -1


func nota_perfeita(b):
	var r = b.riff_hud
	var n = load("res://scenes/objects/NotaRiff.tscn").instantiate()
	r.notas_container.add_child(n)
	n.coluna = 1
	n.position.y = 260
	r.verificar_nota(1)


func sem_ciclo(b):
	var c = b.boss
	var j = c.jogador
	c.jogador = null
	await esperar(2.1)
	c.jogador = j


func _rodar():
	print("== teclas")
	ok(tecla("atirar") == KEY_SPACE and tecla("golpe") == KEY_J and tecla("especial") == KEY_K, "Espaco atira, J golpe, K especial")
	ok(tecla("dodge") == KEY_SHIFT and tecla("riff_mode") == KEY_R and tecla("interagir") == KEY_E, "Shift dodge, R Riff/solo, E portal")

	print("== tela inicial")
	var t = await abrir("res://scenes/ui/tela_inicial.tscn")
	ok(t.name == "TelaInicial" and root.get_node("Audio").musica_atual == "ruas", "tela inicial com a musica das ruas")

	print("== ruas")
	var m = await abrir("res://scenes/main/main.tscn")
	var hud = m.get_node("HudJogo")
	ok(hud.texto_vida.text == "VIDA 5/5" and hud.barra_solo.visible, "HUD com vida e barra de solo")
	var ps = m.player
	ok(ps.get_node("CollisionShape2D").shape.size == Vector2(88, 136) and is_equal_approx(ps.escala_personagem, 1.0), "nas ruas o Dylan tem o dobro do tamanho")
	var fr = ps.sprite.sprite_frames
	ok(fr.get_frame_count("idle") == 8 and fr.get_frame_count("run") == 8 and fr.get_frame_count("dodge") == 6, "parado, corrida e slide do pack novo")
	ok(fr.get_frame_texture("dodge", 0).atlas.resource_path.ends_with("dylan_novo/slide.png"), "dodge usa o slide")
	ok(hud.progresso.text.begins_with("ARENA 1/3"), "progresso: " + hud.progresso.text)
	ok(inimigos(m).size() == 4, "4 inimigos na primeira onda")
	m.player.invencivel = true
	for arena in range(1, 4):
		for onda in range(2):
			for e in inimigos(m):
				e.receber_dano(99)
			await esperar(1.0)
			ok(inimigos(m).is_empty(), "arena %d onda %d limpa" % [arena, onda + 1])
			await esperar(1.8)
		if arena < 3:
			ok(hud.aviso.text.contains("NOTA") and hud.aviso.text.contains("direita"), "nota e aviso de seguir: " + hud.aviso.text)
			m.player.global_position.x = m.camera.global_position.x + 5000
			await esperar(1.3)
			ok(m.arena_atual == arena + 1, "transicao para a arena %d" % (arena + 1))
	await esperar(0.2)
	ok(m.fase_concluida and m.portal.visible and hud.aviso.text.contains("portal"), "portal abre no fim com a nota")
	m.player.invencivel = false
	m.player.timer_invencibilidade.stop()
	m.player.receber_dano(99)
	await esperar(0.1)
	ok(hud.tela_fim.visible and hud.titulo_fim.text == "GAME OVER", "game over nas ruas")

	print("== boss")
	var b = await abrir("res://scenes/main/Bossfight.tscn")
	var c = b.boss
	var j = b.jogador
	await sem_ciclo(b)
	j.invencivel = true
	ok(root.get_node("Audio").musica_atual == "boss", "musica do boss")
	ok(j.get_node("CollisionShape2D").shape.size == Vector2(44, 68) and is_equal_approx(j.escala_personagem, 0.5), "no boss o Dylan volta ao tamanho original")
	ok(b.cabo.visible and abs(b.cabo.barra.value - 0.5) < 0.01, "cabo de forca comeca no meio")
	c._descansar()
	await process_frame
	ok(c.sinal_riff.visible and c.sprite.animation == &"ajoelhar", "boss ajoelha com o sinal do Riff")
	while c.descansando:
		await process_frame
	b.riff_ativo = true
	j.bloqueado = true
	b.riff_hud.visible = true
	b.riff_hud.iniciar_riff()
	var v0 = c.vida_atual
	var vj = j.vida
	nota_perfeita(b)
	ok(c.vida_atual == v0 - 6 and j.vida > vj, "PERFECT tira 6 e transfere para o Dylan")
	for i in range(5):
		nota_perfeita(b)
	await process_frame
	ok(c.fase == 2 and not b.riff_ativo and c.escudo_ativo, "6 PERFECT: fase 2, Riff fecha, escudo ativo")
	var ev = InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.pressed = true
	b.riff_ativo = true
	j.bloqueado = true
	b.riff_hud.visible = true
	b._input(ev)
	ok(not b.riff_ativo and not j.bloqueado, "outra tecla fecha o Riff")
	for r in get_nodes_in_group("runas"):
		r.receber_dano(99)
	await process_frame
	ok(not c.escudo_ativo, "runas quebradas desligam o escudo")
	c._invocar_capangas()
	await process_frame
	var capangas = get_nodes_in_group("capangas")
	ok(capangas.size() == 2 and capangas.all(func(x): return x.is_in_group("alvos_golpe")), "capangas entram como alvos do combo")
	j.invencivel = false
	j.timer_invencibilidade.stop()
	j.global_position = Vector2(300, 420)
	vj = j.vida
	await esperar(4.0)
	ok(j.vida < vj, "capanga chega, avisa e acerta")
	j.invencivel = true
	c.escudo_ativo = false
	c.vida_atual = 3
	c.receber_dano(99)
	await esperar(1.6)
	ok(b.venceu and get_nodes_in_group("capangas").is_empty(), "vitoria e capangas somem")

	print("== luta longa")
	b = await abrir("res://scenes/main/Bossfight.tscn")
	b.jogador.invencivel = true
	b.boss.fase = 3
	await esperar(30.0)
	ok(b.boss.vida_atual > 0 and not b.fim_de_jogo, "30 s de luta na fase 3 sem travar")

	print("== dodge")
	m = await abrir("res://scenes/main/main.tscn")
	m.enemy_manager.reiniciando = true
	await process_frame
	Input.action_press("dodge")
	await physics_frame
	await physics_frame
	Input.action_release("dodge")
	ok(m.player.esquivando and abs(m.player.stamina - 67.0) < 0.5, "Shift esquiva e gasta stamina")

	print("RESULTADO: %d falhas" % falhas)
	quit(1 if falhas else 0)
