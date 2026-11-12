extends SceneTree
# Testes da troca de arma e da metralhadora.
# Rodar: Godot --headless --path . --script tests/teste_metralhadora.gd

var falhas = 0
var m
var p


func ok(condicao, mensagem):
	print(("  OK   " if condicao else "  FALHA ") + mensagem)
	if not condicao:
		falhas += 1


func esperar(segundos):
	await create_timer(segundos, true, false, true).timeout


func _initialize():
	_rodar()


func apertar(acao):
	await process_frame
	Input.action_press(acao)
	await physics_frame
	await physics_frame
	Input.action_release(acao)
	await physics_frame


func balas():
	return m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("projetil.gd"))


func limpar():
	for n in m.get_children():
		if (n is CharacterBody2D and not n.is_in_group("jogador")) or n is CPUParticles2D or n is StaticBody2D:
			n.free()
		elif n is Area2D and n != m.portal:
			n.free()
	await physics_frame


func segurar_tiro(segundos):
	var vistos = {}
	for b in balas():
		vistos[b.get_instance_id()] = true
	var y_saida = []
	Input.action_press("atirar")
	var fim = Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await physics_frame
		for b in balas():
			if not vistos.has(b.get_instance_id()):
				vistos[b.get_instance_id()] = true
				y_saida.append(b.global_position.y - p.global_position.y)
	Input.action_release("atirar")
	await physics_frame
	return y_saida


func _rodar():
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.4)
	m = current_scene
	m.enemy_manager.reiniciando = true
	p = m.player
	await limpar()
	var hud = m.get_node("HudJogo")
	p.invencivel = true

	print("== troca de arma")
	ok(p.arma == "guitarra" and hud.texto_arma.text.begins_with("GUITARRA"), "comeca com a guitarra")
	var frames_guitarra = p.sprite.sprite_frames
	await apertar("trocar_arma")
	ok(p.arma == "metralhadora" and p.sprite.sprite_frames == p.frames_metralhadora, "Q troca para a metralhadora")
	ok(hud.texto_arma.text.begins_with("METRALHADORA"), "HUD mostra a arma: " + hud.texto_arma.text)
	ok(p.frames_metralhadora.resource_path.ends_with("dylan_metralhadora.tres"), "usa o sprite sheet novo")
	var nomes = ["idle", "run", "attack", "run_attack", "hurt", "death", "dodge"]
	ok(nomes.all(func(n): return p.frames_metralhadora.has_animation(n)), "sprite sheet tem as 7 animacoes")
	ok(is_equal_approx(p.timer_tiro.wait_time, 0.1), "cadencia de 0,1 s")

	print("== rajada")
	p.global_position = Vector2(300, 440)
	var y = await segurar_tiro(1.0)
	ok(y.size() >= 8 and y.size() <= 11, "cerca de 10 tiros por segundo: %d" % y.size())
	var y_min = 999.0
	var y_max = -999.0
	for v in y:
		y_min = minf(y_min, v)
		y_max = maxf(y_max, v)
	ok(y_max - y_min > 8.0 and y_max - y_min <= 28.0, "rajada espalha um pouco na vertical: %.1f px" % (y_max - y_min))
	await esperar(1.3)
	y = await segurar_tiro(5.0)
	ok(y.size() >= 40, "sem limite: continua disparando por 5 s (%d tiros)" % y.size())
	await esperar(1.3)

	print("== dano e efeitos")
	await limpar()
	p.global_position = Vector2(300, 440)
	var alvo = load("res://scenes/enemies/inimigo.tscn").instantiate()
	m.add_child(alvo)
	alvo.global_position = Vector2(520, 435)
	alvo.set_physics_process(false)
	alvo.vida = 10.0
	p.timer_tiro.stop()
	p.direcao_olhar = 1
	p.atirar()
	var efeitos = m.get_children().filter(func(n): return n is CPUParticles2D)
	ok(efeitos.size() == 1, "clarao no cano e capsula")
	await esperar(0.6)
	ok(is_equal_approx(alvo.vida, 9.5), "cada bala tira 0,5: vida %.1f" % alvo.vida)
	p.direcao_olhar = -1
	p.timer_tiro.stop()
	p.atirar()
	efeitos = m.get_children().filter(func(n): return n is CPUParticles2D)
	ok(efeitos.size() >= 1 and efeitos[-1].scale.x < 0.0 and balas()[-1].direcao == -1, "virado para a esquerda o disparo sai para a esquerda")
	p.direcao_olhar = 1
	await limpar()

	print("== peso ao atirar")
	p.global_position = Vector2(300, 440)
	Input.action_press("mover_direita")
	await esperar(0.5)
	var x0 = p.global_position.x
	await esperar(0.5)
	var livre = p.global_position.x - x0
	Input.action_press("atirar")
	await esperar(0.1)
	x0 = p.global_position.x
	await esperar(0.5)
	var atirando = p.global_position.x - x0
	Input.action_release("atirar")
	Input.action_release("mover_direita")
	ok(atirando < livre * 0.85 and atirando > livre * 0.6, "mais lento disparando: %.0f contra %.0f px" % [atirando, livre])

	print("== animacao da rajada")
	p.global_position = Vector2(300, 440)
	Input.action_press("mover_direita")
	Input.action_press("atirar")
	var quadros = {}
	var reinicios = 0
	var anterior = -1
	for k in range(36):
		await physics_frame
		if p.sprite.animation == &"run_attack":
			quadros[p.sprite.frame] = true
			if p.sprite.frame < anterior:
				reinicios += 1
			anterior = p.sprite.frame
	Input.action_release("atirar")
	Input.action_release("mover_direita")
	ok(quadros.size() >= 5, "correndo e atirando as pernas seguem o ciclo: quadros %s" % str(quadros.keys()))
	await esperar(0.5)

	print("== volta para a guitarra")
	await apertar("trocar_arma")
	ok(p.arma == "guitarra" and p.sprite.sprite_frames == frames_guitarra and is_equal_approx(p.timer_tiro.wait_time, 0.3), "Q volta para a guitarra e o tiro normal")
	p.global_position = Vector2(300, 440)
	y = await segurar_tiro(1.0)
	ok(y.size() >= 3 and y.size() <= 4, "guitarra continua com cerca de 3 tiros por segundo: %d" % y.size())
	p.timer_tiro.stop()
	p.atirar()
	ok(is_equal_approx(balas()[-1].dano, 1.0), "tiro da guitarra continua com dano 1")

	print("== alvos com vida fracionada")
	await limpar()
	var caixa = load("res://scenes/objects/caixote.tscn").instantiate()
	m.add_child(caixa)
	caixa.global_position = Vector2(500, 440)
	caixa.receber_dano(0.5)
	caixa.receber_dano(0.5)
	caixa.receber_dano(0.5)
	ok(not caixa.morto and is_equal_approx(caixa.vida, 0.5), "caixote soma meio dano por bala")
	caixa.receber_dano(0.5)
	ok(caixa.morto, "4 balas da metralhadora quebram o caixote")

	print("== no boss")
	change_scene_to_file("res://scenes/main/Bossfight.tscn")
	await esperar(0.4)
	var b = current_scene
	ok(b.hud.texto_arma.visible and b.hud.texto_arma.text.begins_with("GUITARRA"), "HUD da arma aparece no boss")
	b.jogador.trocar_arma()
	ok(b.jogador.arma == "metralhadora" and b.hud.texto_arma.text.begins_with("METRALHADORA"), "troca funciona no boss")
	var runa = load("res://scenes/bosses/runa.tscn").instantiate()
	b.add_child(runa)
	for i in range(5):
		runa.receber_dano(0.5)
	ok(is_instance_valid(runa) and not runa.is_queued_for_deletion() and is_equal_approx(runa.vida, 0.5), "runa soma meio dano por bala")

	print("RESULTADO: %d falhas" % falhas)
	quit(1 if falhas else 0)
