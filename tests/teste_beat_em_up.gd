extends SceneTree
# Testes das melhorias do beat 'em up.
# Rodar: Godot --headless --path . --script tests/teste_beat_em_up.gd

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


func limpar():
	for n in m.get_children():
		if n is CharacterBody2D and not n.is_in_group("jogador"):
			n.free()
		elif n.get_script() != null and (n.get_script().resource_path.ends_with("quebravel.gd") or n.get_script().resource_path.ends_with("item_vida.gd")):
			n.free()
		elif n is Area2D and n != m.portal:
			n.free()
	await physics_frame


func criar(cena, posicao, fisica = true):
	var e = load(cena).instantiate()
	m.add_child(e)
	e.global_position = posicao
	if not fisica:
		e.set_physics_process(false)
	await physics_frame
	return e


func preparar_jogador(x = 400.0, y = 440.0):
	p.global_position = Vector2(x, y)
	p.vida = p.vida_maxima
	p.vida_alterada.emit(p.vida, p.vida_maxima)
	p.stamina = p.stamina_maxima
	p.espera_stamina = 0.0
	p.timer_invencibilidade.stop()
	p.direcao_olhar = 1
	p.cadeia_ate_ms = 0
	p.invencivel = false


func _rodar():
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.4)
	m = current_scene
	m.enemy_manager.reiniciando = true
	var quebraveis_fase = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("quebravel.gd")).size()
	p = m.player
	await limpar()
	var normal = "res://scenes/enemies/inimigo.tscn"

	print("== impacto")
	var combate = root.get_node_or_null("Combate")
	ok(combate != null, "autoload Combate carregado")
	combate.pausar(0.06)
	ok(is_equal_approx(Engine.time_scale, 0.05), "pausa no impacto congela o jogo")
	await esperar(0.12)
	ok(is_equal_approx(Engine.time_scale, 1.0), "jogo volta ao normal depois da pausa")
	combate.tremer(10.0, 0.2)
	await esperar(0.05)
	var deslocou = m.camera.offset != Vector2.ZERO
	await esperar(0.35)
	ok(deslocou and m.camera.offset == Vector2.ZERO, "tremor mexe a camera e volta ao centro")
	ok(p.get_node("Sombra").z_index == -1 and m.get_node("Background").z_index == -2, "sombra do Dylan acima do fundo")
	var e0 = await criar(normal, Vector2(900, 440), false)
	ok(e0.get_node("Sombra").z_index == -1, "inimigos tem sombra")
	e0.free()

	print("== empurrao")
	preparar_jogador(300)
	var alvo = await criar(normal, Vector2(500, 440))
	alvo.vida = 20
	alvo.velocidade = 0.0
	alvo.set_physics_process(true)
	var x_antes = alvo.global_position.x
	p.atirar()
	var x_max = x_antes
	for k in range(30):
		await physics_frame
		x_max = maxf(x_max, alvo.global_position.x)
	ok(x_max > x_antes + 15.0, "tiro empurra o inimigo: +%.0f px" % (x_max - x_antes))
	alvo.vida = 1
	x_antes = alvo.global_position.x
	alvo.empurrar(Vector2(560, 0))
	alvo.receber_dano(2)
	await esperar(0.4)
	ok(alvo.morto and alvo.global_position.x > x_antes + 100.0, "golpe final arremessa o corpo: +%.0f px" % (alvo.global_position.x - x_antes))
	await limpar()

	print("== combo corpo a corpo")
	preparar_jogador(400)
	alvo = await criar(normal, Vector2(520, 440), false)
	alvo.vida = 30
	var vida_antes = alvo.vida
	var min_escala = [1.0]
	var amostra = func(): min_escala[0] = minf(min_escala[0], Engine.time_scale)
	process_frame.connect(amostra)
	var etapas = []
	for i in range(3):
		await apertar("golpe")
		etapas.append(p.etapa_golpe)
		if i < 2:
			while p.golpeando:
				await physics_frame
	while p.golpeando:
		await physics_frame
	process_frame.disconnect(amostra)
	ok(etapas == [0, 1, 2], "soco, soco e chute em sequencia: %s" % str(etapas))
	ok(vida_antes - alvo.vida == 4, "dano 1 + 1 + 2: %d" % (vida_antes - alvo.vida))
	ok(min_escala[0] < 0.2, "golpe que acerta pausa o jogo")
	ok(m.combo >= 3, "contador de combo: %d" % m.combo)
	ok(m.hud.texto_combo.visible and m.hud.texto_combo.text == "COMBO x%d" % m.combo, "HUD mostra o combo")
	ok(m.carga_solo >= 30.0, "golpes carregam o solo: %.0f" % m.carga_solo)
	await esperar(0.5)
	await apertar("golpe")
	ok(p.etapa_golpe == 0, "depois da janela, o combo recomeca do primeiro golpe")
	while p.golpeando:
		await physics_frame
	alvo.global_position = Vector2(520, 560)
	vida_antes = alvo.vida
	await esperar(0.5)
	await apertar("golpe")
	while p.golpeando:
		await physics_frame
	ok(alvo.vida == vida_antes, "fora da faixa da rua nao acerta")
	alvo.global_position = Vector2(340, 440)
	await esperar(0.5)
	await apertar("golpe")
	while p.golpeando:
		await physics_frame
	ok(alvo.vida == vida_antes, "nao acerta quem esta atras")
	await esperar(0.5)
	await apertar("golpe")
	ok(p.golpeando and p.sprite.animation == &"attack", "sem quadros proprios usa o ataque da guitarra")
	await physics_frame
	await physics_frame
	ok(not is_zero_approx(p.sprite.rotation), "guitarra gira durante o golpe")
	await apertar("dodge")
	ok(p.esquivando and not p.golpeando and is_zero_approx(p.sprite.rotation), "dodge cancela o golpe")
	await esperar(0.5)
	await esperar(2.2)
	ok(m.combo == 0 and not m.hud.texto_combo.visible, "combo zera depois de 2 s sem acertar")
	await limpar()

	print("== golpe especial")
	preparar_jogador(400)
	var esq = await criar(normal, Vector2(300, 440))
	var dir = await criar(normal, Vector2(500, 470))
	esq.vida = 10
	dir.vida = 10
	var longe = await criar(normal, Vector2(800, 440), false)
	longe.vida = 10
	await apertar("especial")
	ok(p.no_especial and is_equal_approx(p.stamina, 50.0), "especial gasta 50 de stamina")
	var vj = p.vida
	p.receber_dano(1)
	ok(p.vida == vj, "invulneravel durante o especial")
	await esperar(0.5)
	ok(esq.vida == 9 and dir.vida == 9 and longe.vida == 10, "atinge so quem esta em volta")
	ok(esq.global_position.x < 260.0 and dir.global_position.x > 540.0, "empurra para os dois lados (%.0f / %.0f)" % [esq.global_position.x, dir.global_position.x])
	p.stamina = 30.0
	p.espera_stamina = 99.0
	await apertar("especial")
	ok(not p.no_especial, "sem stamina nao solta o especial")
	await limpar()

	print("== fila de ataque")
	preparar_jogador(576)
	p.invencivel = true
	var grupo = []
	for i in range(4):
		grupo.append(await criar(normal, Vector2(576 + (i - 1.5) * 260, 360 + i * 50)))
	var vez = {}
	var maximo = 0
	var soma_dist = 0.0
	var amostras = 0
	for k in range(40):
		await esperar(0.2)
		var fila = grupo.filter(func(e): return e in e.atacantes)
		maximo = maxi(maximo, fila.size())
		for e in fila:
			vez[e.get_instance_id()] = true
		if k >= 10:
			for e in grupo.filter(func(e): return not e in e.atacantes):
				soma_dist += e.global_position.distance_to(p.global_position)
				amostras += 1
	ok(maximo <= 2, "no maximo 2 atacam ao mesmo tempo: %d" % maximo)
	ok(vez.size() >= 3, "a vez de atacar passa adiante: %d inimigos atacaram" % vez.size())
	var dist_media = soma_dist / maxi(amostras, 1)
	var limite_espera = grupo[0].distancia_ataque * 1.4
	ok(dist_media > limite_espera, "quem espera fica fora do alcance de ataque: media %.0f px (minimo %.0f)" % [dist_media, limite_espera])
	await limpar()

	print("== aviso antes do golpe")
	preparar_jogador(400)
	var bat = await criar(normal, Vector2(540, 440))
	var vida_jogador = p.vida
	var preparou = false
	for k in range(30):
		await physics_frame
		if bat.preparando:
			preparou = true
			break
	ok(preparou and bat.sprite.modulate.r > 1.0, "inimigo pisca antes de bater")
	ok(p.vida == vida_jogador, "golpe nao e instantaneo")
	await esperar(0.6)
	ok(p.vida < vida_jogador, "golpe acerta depois do aviso")
	await esperar(1.0)
	preparar_jogador(400)
	bat.timer_ataque.stop()
	bat.global_position = Vector2(540, 440)
	vida_jogador = p.vida
	while not bat.preparando:
		await physics_frame
	p.global_position = Vector2(150, 440)
	await esperar(0.6)
	ok(p.vida == vida_jogador, "sair durante o aviso evita o golpe")
	await limpar()

	print("== skatista")
	preparar_jogador(400)
	var skate = await criar("res://scenes/enemies/inimigo_rapido.tscn", Vector2(660, 445))
	vida_jogador = p.vida
	var investiu = false
	for k in range(150):
		await physics_frame
		if skate.investindo and abs(skate.velocity.x) > 400.0:
			investiu = true
		if p.vida < vida_jogador:
			break
	ok(investiu, "skatista avanca em linha reta")
	ok(p.vida < vida_jogador, "investida acerta o Dylan")
	await limpar()

	print("== atirador recua")
	preparar_jogador(400)
	var atirador = await criar("res://scenes/enemies/inimigo_atirador.tscn", Vector2(480, 440))
	var atirou_fugindo = false
	for k in range(18):
		await physics_frame
		var tiros = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("projetil_inimigo.gd"))
		if not tiros.is_empty() and abs(atirador.global_position.x - p.global_position.x) < atirador.distancia_fuga:
			atirou_fugindo = true
	ok(atirador.global_position.x > 510.0 and not atirou_fugindo, "atirador foge sem atirar quando o Dylan chega perto: x=%.0f" % atirador.global_position.x)
	await limpar()

	print("== drone de chao")
	preparar_jogador(400)
	var vizinho = await criar(normal, Vector2(520, 590), false)
	vizinho.vida = 10
	var kami = await criar("res://scenes/enemies/inimigo_drone_chao.tscn", Vector2(560, 450))
	vida_jogador = p.vida
	for k in range(120):
		await physics_frame
		if kami.morto:
			break
	ok(kami.morto and p.vida == vida_jogador - 2, "drone pisca e explode: Dylan perde %d" % (vida_jogador - p.vida))
	ok(vizinho.vida == 9, "explosao atinge inimigos proximos")
	await esperar(0.6)
	preparar_jogador(400)
	kami = await criar("res://scenes/enemies/inimigo_drone_chao.tscn", Vector2(700, 440))
	kami.receber_dano(1)
	await esperar(1.0)
	ok(p.vida == p.vida_maxima, "drone destruido antes nao explode")
	await limpar()

	print("== nota da arena")
	var casos = [[0.0, 12, "S"], [1.0, 6, "A"], [3.0, 2, "B"], [5.0, 20, "C"]]
	for c in casos:
		m.dano_na_arena = c[0]
		m.maior_combo = c[1]
		ok(m.calcular_nota() == c[2], "dano %d e combo %d: nota %s" % [c[0], c[1], m.calcular_nota()])
	m.dano_na_arena = 0.0
	m.maior_combo = 12
	m._ao_concluir_arena()
	ok(m.hud.aviso.text.begins_with("NOTA S"), "aviso mostra a nota: %s" % m.hud.aviso.text)

	print("== solo de guitarra")
	preparar_jogador(400)
	var s1 = await criar(normal, Vector2(600, 440))
	var s2 = await criar(normal, Vector2(250, 500))
	s1.vida = 10
	s2.vida = 10
	m.carga_solo = 60.0
	m.hud.atualizar_solo(m.carga_solo, m.carga_solo_maxima)
	var ev = InputEventAction.new()
	ev.action = "riff_mode"
	ev.pressed = true
	m._input(ev)
	ok(s1.vida == 10 and m.carga_solo == 60.0, "com a barra incompleta o R nao faz nada")
	m.carga_solo = 100.0
	m.hud.atualizar_solo(m.carga_solo, m.carga_solo_maxima)
	ok(m.hud.texto_solo.visible, "barra cheia avisa SOLO PRONTO")
	m._input(ev)
	await physics_frame
	ok(s1.vida == 9 and s2.vida == 9, "solo atinge todos na tela")
	ok(s1.atordoado_ate_ms > Time.get_ticks_msec() and s2.atordoado_ate_ms > Time.get_ticks_msec(), "solo atordoa os inimigos")
	ok(m.carga_solo == 0.0 and not m.hud.texto_solo.visible, "barra zera depois do solo")
	await esperar(0.5)
	var parado = s1.global_position
	await esperar(0.8)
	ok(s1.global_position.distance_to(parado) < 2.0, "atordoado nao se mexe")
	await esperar(1.5)
	ok(s1.atordoado_ate_ms == 0 or s1.atordoado_ate_ms < Time.get_ticks_msec(), "atordoamento passa")
	await limpar()

	print("== quebraveis e itens")
	preparar_jogador(400)
	var caixa = await criar("res://scenes/objects/caixote.tscn", Vector2(530, 440))
	await apertar("golpe")
	while p.golpeando:
		await physics_frame
	ok(not caixa.morto and caixa.vida == 1, "caixote aguenta o primeiro golpe")
	await apertar("golpe")
	while p.golpeando:
		await physics_frame
	await physics_frame
	var itens = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("item_vida.gd"))
	ok(caixa.morto and itens.size() == 1, "caixote quebra e solta uma maca")
	var maca = itens[0]
	p.global_position = maca.global_position
	await esperar(0.2)
	ok(is_instance_valid(maca) and not maca.is_queued_for_deletion(), "com vida cheia a maca fica no chao")
	p.timer_invencibilidade.stop()
	p.receber_dano(2)
	p.timer_invencibilidade.stop()
	var vida_ferido = p.vida
	await esperar(0.2)
	ok(not is_instance_valid(maca) and p.vida == vida_ferido + 1, "maca cura 1")
	preparar_jogador(400)
	var barril = await criar("res://scenes/objects/barril.tscn", Vector2(620, 440))
	p.atirar()
	await esperar(0.4)
	p.timer_tiro.stop()
	p.atirar()
	await esperar(0.4)
	ok(barril.morto, "tiro tambem quebra o barril")
	await esperar(0.1)
	var carnes = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("item_vida.gd"))
	ok(carnes.size() == 1 and is_equal_approx(carnes[0].cura, 2.0), "barril solta carne que cura 2")
	var tanque = await criar("res://scenes/enemies/inimigo_grande.tscn", Vector2(900, 440), false)
	tanque.receber_dano(99)
	await physics_frame
	await physics_frame
	carnes = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("item_vida.gd"))
	ok(carnes.size() == 2, "tanque solta carne ao morrer")
	await limpar()
	ok(quebraveis_fase == 4, "4 quebraveis posicionados nas ruas: %d" % quebraveis_fase)

	print("== arena 3")
	m.enemy_manager.reiniciando = false
	m.enemy_manager.arena_atual = 3
	m.enemy_manager.onda_atual = 1
	m.enemy_manager.criar_onda()
	await physics_frame
	var drones = m.get_children().filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("inimigo_kamikaze.gd"))
	ok(drones.size() == 1, "drone de chao aparece na arena 3")
	m.enemy_manager.reiniciando = true

	print("RESULTADO: %d falhas" % falhas)
	quit(1 if falhas else 0)
