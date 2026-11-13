extends SceneTree
## Teste da IA de grupo dos inimigos (estilo Castle Crashers): vagas de
## ataque por lado, revezamento, rodear à distância, não empilhar e co-op.
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
	await create_timer(segundos, true, false, true).timeout


func _initialize() -> void:
	_rodar()


func _cena_limpa(p2: bool) -> Node:
	jogo.p2_ativo = p2
	change_scene_to_file("res://fases/rua_1/rua_1.tscn")
	await esperar(0.6)
	# Sem ondas da fase: só os inimigos criados pelo teste
	for no in current_scene.find_children("*", "", true, false):
		if no.has_method("criar_onda"):
			no.reiniciando = true
	for e in get_nodes_in_group("inimigos"):
		e.queue_free()
	await process_frame
	return current_scene


func _criar(cena, n: int, centro: Vector2) -> Array:
	var lista = []
	for i in n:
		var e = load("res://inimigos/base/inimigo.tscn").instantiate()
		cena.add_child(e)
		e.global_position = centro + Vector2(260 + 40 * i, -60 + 40 * i)
		lista.append(e)
	return lista


func _rodar() -> void:
	jogo = root.get_node("Jogo")

	print("== Grupo contra um jogador")
	var cena = await _cena_limpa(false)
	var p1 = jogo.jogador_por_id(1)
	p1.set_physics_process(false)
	p1.invencivel = true
	p1.global_position = cena.limites_arena().get_center()
	var inimigos = _criar(cena, 5, p1.global_position)

	var max_vagas = 0
	var atacaram = {}
	var dist_min = INF
	var esperando_longe = 0
	var amostras = 0
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000:
		await process_frame
		var com_vaga = inimigos.filter(func(e): return is_instance_valid(e) and e._lado_vaga != 0)
		max_vagas = max(max_vagas, com_vaga.size())
		for e in inimigos:
			if e.preparando:
				atacaram[e] = true
		if Time.get_ticks_msec() - t0 > 3000:
			amostras += 1
			for e in inimigos:
				if e._lado_vaga == 0 and Time.get_ticks_msec() >= e._recuar_ate_ms and e.global_position.distance_to(p1.global_position) > e.raio_espera * 0.5:
					esperando_longe += 1
			for i in inimigos.size():
				for j in range(i + 1, inimigos.size()):
					dist_min = min(dist_min, inimigos[i].global_position.distance_to(inimigos[j].global_position))
	var lados = {}
	for e in inimigos:
		if e._lado_vaga != 0:
			lados[e._lado_vaga] = true
	checar(max_vagas <= 2, "no máximo 2 inimigos com vaga de ataque ao mesmo tempo (%d)" % max_vagas)
	checar(atacaram.size() >= 3, "inimigos se revezam no ataque (%d diferentes atacaram)" % atacaram.size())
	checar(esperando_longe > amostras, "quem está sem vaga rodeia à distância")
	checar(dist_min > 20.0, "inimigos não se empilham (menor distância %.0f px)" % dist_min)

	print("== Co-op: vagas por jogador")
	cena = await _cena_limpa(true)
	p1 = jogo.jogador_por_id(1)
	var p2 = jogo.jogador_por_id(2)
	for p in [p1, p2]:
		p.set_physics_process(false)
		p.invencivel = true
	var centro = cena.limites_arena().get_center()
	p1.global_position = centro - Vector2(250, 0)
	p2.global_position = centro + Vector2(250, 0)
	var grupo1 = _criar(cena, 3, p1.global_position - Vector2(520, 0))
	var grupo2 = _criar(cena, 3, p2.global_position)
	await esperar(3.0)
	var vagas_p1 = (grupo1 + grupo2).filter(func(e): return e._lado_vaga != 0 and e.jogador == p1).size()
	var vagas_p2 = (grupo1 + grupo2).filter(func(e): return e._lado_vaga != 0 and e.jogador == p2).size()
	checar(vagas_p1 >= 1 and vagas_p1 <= 2 and vagas_p2 >= 1 and vagas_p2 <= 2, "cada jogador tem as próprias 2 vagas (P1 %d, P2 %d)" % [vagas_p1, vagas_p2])

	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)
