extends SceneTree
# Testes da esquiva perfeita (dodge no último instante deixa o tempo lento).
# Rodar: Godot --headless --path . --script tests/teste_esquiva_perfeita.gd

var falhas = 0
var m
var p
var combate
var audio


func ok(condicao, mensagem):
	print(("  OK   " if condicao else "  FALHA ") + mensagem)
	if not condicao:
		falhas += 1


func esperar(segundos):
	await create_timer(segundos, true, false, true).timeout


func _initialize():
	_rodar()


func esquivar():
	Input.action_press("dodge")
	await physics_frame
	await physics_frame
	Input.action_release("dodge")


func limpar():
	for n in m.get_children():
		if (n is CharacterBody2D and not n.is_in_group("jogador")) or n is Sprite2D and n.name != "Background" or n is CPUParticles2D:
			n.free()
		elif n is Area2D and n != m.portal:
			n.free()
	await physics_frame


func preparar(x = 400.0):
	p.global_position = Vector2(x, 440)
	p.vida = p.vida_maxima
	p.vida_alterada.emit(p.vida, p.vida_maxima)
	p.stamina = p.stamina_maxima
	p.espera_stamina = 0.0
	p.timer_invencibilidade.stop()
	p.invencivel = false


func esperar_fim_camera_lenta():
	while combate.em_camera_lenta():
		await process_frame
	await esperar(0.3)


func _rodar():
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.4)
	m = current_scene
	m.enemy_manager.reiniciando = true
	p = m.player
	combate = root.get_node("Combate")
	audio = root.get_node("Audio")
	await limpar()
	var hud = m.get_node("HudJogo")
	var normal = "res://scenes/enemies/inimigo.tscn"

	print("== esquiva no ultimo instante")
	preparar()
	var e = load(normal).instantiate()
	m.add_child(e)
	e.global_position = Vector2(540, 440)
	while not e.preparando:
		await physics_frame
	await create_timer(0.27).timeout
	var vida = p.vida
	var combo = m.combo
	var solo = m.carga_solo
	await esquivar()
	var ativou = false
	for k in range(30):
		await physics_frame
		if combate.em_camera_lenta():
			ativou = true
			break
	ok(ativou and p.esquiva_perfeita_usada, "golpe logo depois do dodge ativa a esquiva perfeita")
	ok(is_equal_approx(Engine.time_scale, 0.35), "tempo fica lento: %.2f" % Engine.time_scale)
	ok(is_equal_approx(audio.musica.pitch_scale, 0.7), "musica fica arrastada")
	ok(is_equal_approx(p.stamina, p.stamina_maxima), "o dodge sai de graca: stamina %.0f" % p.stamina)
	ok(p.vida == vida, "Dylan nao toma o golpe")
	ok(hud.destaque.visible and hud.destaque.text == "ESQUIVA PERFEITA!", "HUD anuncia ESQUIVA PERFEITA")
	ok(m.combo == combo + 1 and is_equal_approx(m.carga_solo, minf(solo + 15.0, 100.0)), "conta no combo e enche o solo")
	await esperar(0.3)
	ok(hud.tom_lento.color.a > 0.1, "tela ganha tom roxo")
	var rastros = m.get_children().filter(func(n): return n is Sprite2D and n.name != "Background")
	ok(rastros.size() >= 3, "Dylan deixa rastros na camera lenta: %d" % rastros.size())
	ok(not p.tentar_esquiva_perfeita(), "so vale uma vez por dodge")
	combate.pausar(0.05)
	ok(is_equal_approx(Engine.time_scale, 0.05), "pausa de impacto funciona por cima")
	await esperar(0.1)
	ok(is_equal_approx(Engine.time_scale, 0.35), "depois da pausa volta para a camera lenta, nao para o normal")
	await esperar_fim_camera_lenta()
	ok(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(audio.musica.pitch_scale, 1.0), "camera lenta acaba em 1,5 s e a musica volta")
	ok(hud.tom_lento.color.a < 0.02, "tom roxo some")
	await limpar()

	print("== dodge antecipado nao vale")
	preparar()
	e = load(normal).instantiate()
	m.add_child(e)
	e.global_position = Vector2(540, 440)
	while not e.preparando:
		await physics_frame
	await esquivar()
	await esperar(0.6)
	ok(not combate.em_camera_lenta() and not p.esquiva_perfeita_usada, "esquivar cedo demais nao ativa")
	await limpar()

	print("== bala raspando")
	preparar(400)
	await esperar(0.5)
	var bala = load("res://scenes/enemies/projetil_inimigo.tscn").instantiate()
	bala.direcao = -1
	m.add_child(bala)
	bala.global_position = Vector2(560, 440)
	while is_instance_valid(bala) and bala.global_position.x > p.global_position.x + 75.0:
		await physics_frame
	await esquivar()
	ativou = false
	for k in range(30):
		await physics_frame
		if combate.em_camera_lenta():
			ativou = true
			break
	ok(ativou, "bala passando raspando durante o dodge tambem vale")
	await esperar_fim_camera_lenta()
	await limpar()

	print("== skatista")
	preparar(400)
	var skate = load("res://scenes/enemies/inimigo_rapido.tscn").instantiate()
	m.add_child(skate)
	skate.global_position = Vector2(660, 445)
	ativou = false
	for k in range(200):
		await physics_frame
		if skate.investindo and abs(skate.global_position.x - p.global_position.x) < 130 and not p.esquivando:
			await esquivar()
		if combate.em_camera_lenta():
			ativou = true
			break
	ok(ativou, "esquivar da investida do skatista vale")
	await esperar_fim_camera_lenta()
	await limpar()

	print("== casos")
	preparar()
	ok(not p.tentar_esquiva_perfeita(), "sem dodge nao ativa")
	p.usar_esquiva_perfeita = false
	await esquivar()
	await physics_frame
	ok(not p.tentar_esquiva_perfeita() and not combate.em_camera_lenta(), "interruptor desligado")
	p.usar_esquiva_perfeita = true
	await esperar(0.5)

	print("== no boss")
	change_scene_to_file("res://scenes/main/Bossfight.tscn")
	await esperar(0.4)
	var b = current_scene
	ok(b.hud.destaque != null and not b.hud.destaque.visible, "HUD do boss tem o destaque")
	b.jogador.stamina = 100.0
	await esquivar()
	await physics_frame
	ok(b.jogador.tentar_esquiva_perfeita() and combate.em_camera_lenta(), "funciona na luta do boss")
	await esperar_fim_camera_lenta()

	print("RESULTADO: %d falhas" % falhas)
	quit(1 if falhas else 0)
