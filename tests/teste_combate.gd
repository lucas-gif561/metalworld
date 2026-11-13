extends SceneTree
## Teste do combate corpo a corpo: socos alternados, alcance e faixa,
## empurrão, inimigos carregando o golpe e animação de guitarra no Riff.
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


func apertar(acao: String, segurar := 0.05) -> void:
	for pressionado in [true, false]:
		var evento = InputEventAction.new()
		evento.action = acao
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await esperar(segurar)


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	jogo.p2_ativo = false
	await _teste_socos()
	await _teste_carga_dos_inimigos()
	await _teste_atirador_nao_vira()
	await _teste_riff()
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _inimigo_parado(cena, posicao: Vector2):
	var inimigo = load("res://scenes/enemies/inimigo.tscn").instantiate()
	cena.add_child(inimigo)
	inimigo.global_position = posicao
	inimigo.vida = 99
	inimigo.set_physics_process(false)
	return inimigo


func _teste_socos() -> void:
	print("== Socos")
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.5)
	var cena = current_scene
	for e in get_nodes_in_group("inimigos"):
		e.queue_free()
	var p1 = jogo.jogador_por_id(1)
	p1.global_position = Vector2(400, 450)
	p1.direcao_olhar = 1
	await esperar(0.1)

	checar(is_equal_approx(p1.escala_personagem, 1.5), "na rua o Dylan fica 1,5x maior")
	var alvo = _inimigo_parado(cena, Vector2(460, 450))
	var atras = _inimigo_parado(cena, Vector2(340, 450))
	var outra_faixa = _inimigo_parado(cena, Vector2(460, 540))
	await process_frame
	checar(is_equal_approx(alvo.escala_personagem, 1.5), "e os inimigos também")

	await apertar("p1_atacar")
	checar(p1.sprite.animation == &"soco_esquerdo", "1º soco: esquerdo (jab)")
	await esperar(0.35)
	checar(alvo.vida == 98, "jab tira 1 de quem está na frente")
	checar(atras.vida == 99, "não acerta quem está atrás")
	checar(outra_faixa.vida == 99, "não acerta quem está em outra faixa da rua")

	await apertar("p1_atacar")
	checar(p1.sprite.animation == &"soco_direito", "2º soco: direito (direto)")
	var x_antes = alvo.global_position.x
	alvo.set_physics_process(true)
	await esperar(0.45)
	checar(alvo.vida == 96, "direto tira 2")
	checar(alvo.global_position.x > x_antes + 15, "direto empurra o inimigo para trás (%.0f px)" % (alvo.global_position.x - x_antes))
	alvo.set_physics_process(false)

	await esperar(0.8)
	await apertar("p1_atacar")
	checar(p1.sprite.animation == &"soco_esquerdo", "parou de bater: a sequência recomeça no jab")

	# Apertar durante o soco guarda o próximo
	await esperar(1.0)
	await apertar("p1_atacar")
	await apertar("p1_atacar")
	await esperar(0.25)
	checar(p1.sprite.animation == &"soco_direito", "apertar durante o jab emenda o direto")

	var posicao = p1.global_position
	_evento("p1_mover_direita", true)
	await apertar("p1_atacar")
	await esperar(0.1)
	checar(p1.global_position.distance_to(posicao) < 30.0, "para para bater")
	_evento("p1_mover_direita", false)
	await esperar(0.5)

	var caixote = cena.get_node("Caixote1")
	p1.global_position = caixote.global_position - Vector2(55, 0)
	p1.direcao_olhar = 1
	for i in 3:
		await esperar(0.5)
		await apertar("p1_atacar")
	await esperar(0.6)
	checar(not is_instance_valid(caixote) or caixote.morto, "caixote quebra na porrada")


func _evento(acao: String, pressionado: bool) -> void:
	var evento = InputEventAction.new()
	evento.action = acao
	evento.pressed = pressionado
	Input.parse_input_event(evento)


func _teste_carga_dos_inimigos() -> void:
	print("== Inimigos carregam o golpe")
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.5)
	var cena = current_scene
	for e in get_nodes_in_group("inimigos"):
		e.queue_free()
	var p1 = jogo.jogador_por_id(1)
	p1.global_position = Vector2(400, 450)
	p1.direcao_olhar = 1
	p1.set_physics_process(false)

	var inimigo = load("res://scenes/enemies/inimigo.tscn").instantiate()
	cena.add_child(inimigo)
	inimigo.global_position = Vector2(470, 450)
	await esperar(0.25)
	checar(inimigo.preparando, "inimigo perto para e carrega o golpe")
	checar(inimigo.sprite.modulate.r > 1.2, "e pisca branco enquanto carrega")
	checar(p1.vida == 5, "ainda não deu dano durante a carga")
	await esperar(0.4)
	checar(p1.vida == 4, "depois da carga, o golpe acerta")

	# Sair da faixa durante a carga = desviar
	p1.timer_invencibilidade.stop()
	inimigo.timer_ataque.stop()
	await esperar(0.15)
	checar(inimigo.preparando, "carregando de novo")
	p1.global_position.y += 90
	await esperar(0.5)
	checar(p1.vida == 4, "sair da faixa durante a carga desvia do golpe")

	# Soco durante a carga cancela o golpe
	p1.global_position = Vector2(400, 450)
	p1.timer_invencibilidade.stop()
	p1.set_physics_process(true)
	inimigo.timer_ataque.stop()
	var limite = Time.get_ticks_msec() + 2000
	while not inimigo.preparando and Time.get_ticks_msec() < limite:
		await process_frame
	await apertar("p1_atacar")
	await esperar(0.5)
	checar(p1.vida == 4, "socar durante a carga cancela o golpe (vida %d)" % p1.vida)


func _teste_atirador_nao_vira() -> void:
	print("== Atirador não vira durante a carga")
	change_scene_to_file("res://scenes/main/main.tscn")
	await esperar(0.5)
	var cena = current_scene
	for e in get_nodes_in_group("inimigos"):
		e.queue_free()
	var p1 = jogo.jogador_por_id(1)
	p1.set_physics_process(false)
	p1.invencivel = true
	p1.global_position = Vector2(700, 450)

	var atirador = load("res://scenes/enemies/inimigo_atirador.tscn").instantiate()
	cena.add_child(atirador)
	atirador.global_position = Vector2(420, 450)
	var limite = Time.get_ticks_msec() + 3000
	while not atirador.preparando and Time.get_ticks_msec() < limite:
		await process_frame
	checar(atirador.preparando and atirador.lado_carga == 1, "atirador começa a carregar virado para o jogador (direita)")

	# Jogador passa para o outro lado no meio da carga
	p1.global_position = Vector2(200, 450)
	var tiro = [null]
	cena.child_entered_tree.connect(func(no): if no.get("direcao") is int: tiro[0] = no)
	await esperar(0.2)
	checar(atirador.preparando and atirador.sprite.scale.x > 0, "não virou para o jogador durante a carga")
	await esperar(0.4)
	checar(tiro[0] != null and tiro[0].direcao == 1, "o tiro sai para o lado travado (direita)")


func _teste_riff() -> void:
	print("== Guitarra no Riff")
	change_scene_to_file("res://scenes/main/Bossfight.tscn")
	await esperar(0.6)
	var cena = current_scene
	var p1 = jogo.jogador_por_id(1)
	checar(is_equal_approx(p1.escala_personagem, 1.0), "no boss o Dylan volta ao tamanho normal")
	var inicio = p1.global_position
	p1.direcao_olhar = -1
	await apertar("p1_dodge")
	await esperar(0.5)
	var distancia = inicio.distance_to(p1.global_position)
	checar(distancia > 90.0 and distancia < 150.0, "dodge no boss é mais curto (%.0f px, ~1,5 corpo)" % distancia)
	p1.invencivel = true
	await apertar("p1_riff_mode")
	await esperar(0.1)
	checar(p1.sprite.animation == &"riff_inicio", "abrir o Riff saca a guitarra")
	await esperar(0.8)
	checar(p1.sprite.animation == &"riff" and p1.sprite.is_playing(), "e fica tocando em loop")
	await apertar("p1_riff_mode")
	await esperar(0.1)
	checar(p1.sprite.animation == &"idle", "fechar o Riff volta para a guarda")

	# Levantar o parceiro toca a animação de levantar
	p1.morrer()
	p1.reviver()
	checar(p1.sprite.animation == &"levantar", "ao reviver ele se levanta")
