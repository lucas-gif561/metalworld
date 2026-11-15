extends SceneTree
## Teste dos controles: P1 também joga no controle, cada um troca sozinho entre
## teclado e controle (vale o último que tocou) e o controle único passa para o
## P2 quando ele entra pelo START. Os controles são simulados
## (Controles.simular_controles). Rode com: tests/rodar_testes.sh

const CONTROLE = 0
const OUTRO_CONTROLE = 1

var jogo: Node
var controles: Node
var falhas := 0


func checar(condicao: bool, texto: String) -> void:
	if condicao:
		print("  ok    ", texto)
	else:
		falhas += 1
		print("  FALHOU ", texto)


func esperar(segundos: float) -> void:
	await create_timer(segundos).timeout


## Aperta e solta um botão de um controle
func botao(dispositivo: int, indice: JoyButton) -> void:
	for pressionado in [true, false]:
		var evento = InputEventJoypadButton.new()
		evento.device = dispositivo
		evento.button_index = indice
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await esperar(0.05)


## Aperta e solta uma tecla
func tecla(codigo: Key) -> void:
	for pressionado in [true, false]:
		var evento = InputEventKey.new()
		evento.physical_keycode = codigo
		evento.pressed = pressionado
		Input.parse_input_event(evento)
		await esperar(0.05)


func _initialize() -> void:
	_rodar()


func _rodar() -> void:
	jogo = root.get_node("Jogo")
	controles = root.get_node("Controles")
	await _teste_p1_no_controle()
	await _teste_p2_pega_o_controle()
	await _teste_p1_no_controle_pausa()
	await _teste_dois_controles()
	await _teste_inicio_em_dupla()
	controles.simular_controles([])
	print("RESULTADO: ", "PASSOU" if falhas == 0 else "FALHOU (%d)" % falhas)
	quit(1 if falhas > 0 else 0)


func _abrir_rua() -> void:
	jogo.p2_ativo = false
	controles.preparar_partida(false)
	change_scene_to_file("res://fases/rua_1/rua_1.tscn")
	await esperar(0.6)


func _teste_p1_no_controle() -> void:
	print("== Um controle: é do P1 e ele troca entre teclado e controle")
	controles.simular_controles([CONTROLE])
	await _abrir_rua()
	checar(controles.controle_do_jogador(1) == CONTROLE and controles.controle_do_jogador(2) == -1,
		"sozinho, o único controle é do P1")
	checar(not controles.usa_controle(1), "P1 começa no teclado")

	await botao(CONTROLE, JOY_BUTTON_X)
	checar(controles.usa_controle(1), "tocou no controle: P1 no controle")
	checar(controles.texto_comando("riff_mode") == "A", "aviso do Riff mostra só o A")

	await tecla(KEY_F)
	checar(not controles.usa_controle(1), "tocou no teclado: P1 volta ao teclado")
	checar(controles.texto_comando("riff_mode") == "T", "aviso do Riff mostra só o T")


func _teste_p2_pega_o_controle() -> void:
	print("== P1 no teclado: START no controle chama o P2 com o controle")
	checar(current_scene.hud.vaga_p2.get_node("Botoes/BotaoControle").visible, "vaga do P2 mostra o START")
	await botao(CONTROLE, JOY_BUTTON_START)
	await esperar(0.2)
	checar(jogo.p2_ativo and jogo.jogador_por_id(2) != null, "P2 entrou")
	checar(not paused, "o START não pausou o jogo do P1")
	checar(controles.controle_do_jogador(2) == CONTROLE and controles.controle_do_jogador(1) == -1,
		"o controle passou para o P2")
	checar(controles.texto_comando("riff_mode") == "T / A", "aviso mostra T do P1 e A do P2")

	jogo.remover_p2()
	await esperar(0.2)
	checar(controles.controle_do_jogador(1) == CONTROLE, "P2 saiu: o controle volta para o P1")


func _teste_p1_no_controle_pausa() -> void:
	print("== P1 no controle: START pausa, não chama o P2")
	await botao(CONTROLE, JOY_BUTTON_X)
	checar(not current_scene.hud.vaga_p2.get_node("Botoes/BotaoControle").visible, "vaga do P2 mostra o J")
	await botao(CONTROLE, JOY_BUTTON_START)
	await esperar(0.1)
	checar(paused and not jogo.p2_ativo, "START pausou e o P2 não entrou")
	await botao(CONTROLE, JOY_BUTTON_START)
	await esperar(0.1)
	checar(not paused, "START de novo continua")

	await tecla(KEY_J)
	await esperar(0.2)
	checar(jogo.p2_ativo and controles.controle_do_jogador(1) == CONTROLE,
		"P2 entrou pelo J e o P1 continua com o controle")
	checar(controles.texto_comando("riff_mode") == "A / I", "aviso mostra A do P1 e I do P2")
	jogo.remover_p2()
	await esperar(0.2)


func _teste_dois_controles() -> void:
	print("== Dois controles: um para cada")
	controles.simular_controles([CONTROLE, OUTRO_CONTROLE])
	checar(controles.controle_do_jogador(1) == CONTROLE and controles.controle_do_jogador(2) == OUTRO_CONTROLE,
		"P1 com o primeiro, P2 com o segundo")
	await botao(OUTRO_CONTROLE, JOY_BUTTON_START)
	await esperar(0.2)
	checar(jogo.p2_ativo, "START no controle do P2 chama o P2")
	jogo.remover_p2()
	await esperar(0.2)


func _teste_inicio_em_dupla() -> void:
	print("== Jogar em dupla com um controle só")
	controles.simular_controles([CONTROLE])
	await botao(CONTROLE, JOY_BUTTON_X)
	controles.preparar_partida(true)
	checar(controles.controle_do_jogador(1) == CONTROLE, "P1 estava no controle: fica com ele")
	controles.preparar_partida(false)
	await tecla(KEY_F)
	controles.preparar_partida(true)
	checar(controles.controle_do_jogador(2) == CONTROLE, "P1 estava no teclado: o controle vai para o P2")
	controles.preparar_partida(false)
