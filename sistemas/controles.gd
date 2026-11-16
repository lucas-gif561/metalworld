extends Node
## Comandos de cada jogador (autoload "Controles").
##
## Cada ação existe em duas versões: "p1_<acao>" e "p2_<acao>".
## Use sempre jogador.acao("atacar") ou Controles.acao(id, "atacar"),
## nunca Input.is_action_pressed("atacar") direto.
##
## Os dois jogadores sempre têm teclado (P1 na metade esquerda: W A S D, F, G,
## Y, T; P2 na direita: setas, J, K, L, I, P) e podem ter um controle:
##   - dois controles: um para cada.
##   - um controle: é do P1 enquanto o P2 não joga. O P2 fica com ele se entrar
##     apertando START nesse controle (com o P1 no teclado) ou em "Jogar em
##     dupla" quando o P1 não estava usando o controle. O P2 saiu: volta ao P1.
## Cada jogador troca sozinho entre teclado e controle: vale o último que tocou
## (usa_controle). Telas e avisos mostram só as teclas desse dispositivo.

signal controles_mudaram

const ACOES = [
	"mover_cima", "mover_baixo", "mover_esquerda", "mover_direita",
	"atacar", "dodge", "interagir", "riff_mode",
	"riff_cima", "riff_baixo", "riff_esquerda", "riff_direita",
	"reiniciar", "entrar", "pausar",
]

# Botões no padrão Xbox (A embaixo, B direita, X esquerda, Y em cima).
# No Riff, as pistas seguem os gatilhos e os botões superiores: LT, LB, RB, RT.
const BOTOES = {
	"mover_cima": [JOY_BUTTON_DPAD_UP],
	"mover_baixo": [JOY_BUTTON_DPAD_DOWN],
	"mover_esquerda": [JOY_BUTTON_DPAD_LEFT],
	"mover_direita": [JOY_BUTTON_DPAD_RIGHT],
	"atacar": [JOY_BUTTON_X],
	"dodge": [JOY_BUTTON_B],
	"interagir": [JOY_BUTTON_RIGHT_SHOULDER],
	"riff_mode": [JOY_BUTTON_A],
	"riff_cima": [JOY_BUTTON_LEFT_SHOULDER],
	"riff_baixo": [JOY_BUTTON_RIGHT_SHOULDER],
	"reiniciar": [JOY_BUTTON_START],
	"entrar": [JOY_BUTTON_START],
	"pausar": [JOY_BUTTON_START],
}

const EIXOS = {
	"mover_cima": [JOY_AXIS_LEFT_Y, -1.0],
	"mover_baixo": [JOY_AXIS_LEFT_Y, 1.0],
	"mover_esquerda": [JOY_AXIS_LEFT_X, -1.0],
	"mover_direita": [JOY_AXIS_LEFT_X, 1.0],
	"riff_esquerda": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"riff_direita": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}

# Teclado do jogador 2: metade direita (dupla dividindo o mesmo teclado)
const TECLAS_RESERVA_P2 = {
	"mover_cima": [KEY_UP],
	"mover_baixo": [KEY_DOWN],
	"mover_esquerda": [KEY_LEFT],
	"mover_direita": [KEY_RIGHT],
	"atacar": [KEY_J],
	"dodge": [KEY_K],
	"interagir": [KEY_L],
	"riff_mode": [KEY_I],
	"riff_cima": [KEY_UP],
	"riff_baixo": [KEY_DOWN],
	"riff_esquerda": [KEY_LEFT],
	"riff_direita": [KEY_RIGHT],
	"reiniciar": [KEY_J],
	"entrar": [KEY_J],
	"pausar": [KEY_P],
}

# Ações do jogador 1 que não estão no Mapa de Entrada do projeto
const TECLAS_EXTRAS_P1 = {
	"entrar": [KEY_ENTER],
	"pausar": [KEY_ESCAPE],
}

## Nome de cada comando, para avisos e ícones que mostram só a tecla de quem joga
const NOMES_TECLADO = {
	1: {"atacar": "F", "dodge": "G", "interagir": "Y", "riff_mode": "T", "reiniciar": "R", "pausar": "Esc"},
	2: {"atacar": "J", "dodge": "K", "interagir": "L", "riff_mode": "I", "reiniciar": "J", "pausar": "P"},
}
const NOMES_CONTROLE = {
	"atacar": "X", "dodge": "B", "interagir": "RB", "riff_mode": "A", "reiniciar": "START", "pausar": "START",
}

## Avisa quando um jogador passa do teclado para o controle (ou volta)
signal dispositivo_mudou(id_jogador)

var controle_p1 := -1
var controle_p2 := -1
## Último dispositivo que cada jogador usou (true = controle). Os dois têm
## teclado; quem tem controle começa no controle e troca ao apertar uma tecla.
var _usando_controle := {1: false, 2: false}
## Com um controle só: de quem ele é (1 ou 2)
var _dono_controle_unico := 1
## Só para os testes: finge que estes controles estão plugados (null = os reais)
var _controles_de_teste = null


func _ready() -> void:
	# Recebe o F11 / Alt+Enter mesmo com o jogo pausado (menu de pause)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(func(_id, _conectado): _montar())
	# A janela avisa de TODA tecla/botão antes das telas (que às vezes "consomem"
	# o botão do controle); assim o dispositivo de cada um nunca fica errado.
	get_tree().root.window_input.connect(_ao_receber_entrada)
	# O autoload Jogo carrega depois deste
	(func(): Jogo.jogador_saiu.connect(_ao_jogador_sair)).call_deferred()
	_montar()


## Começo da partida (tela inicial): sozinho, o controle é do P1. Em dupla com um
## controle só, fica com o P1 se ele estava usando o controle no menu; senão, P2.
func preparar_partida(em_dupla: bool) -> void:
	_dar_controle_unico(1 if not em_dupla or _usando_controle[1] else 2)


## O P2 saiu da partida: o controle único volta para o P1
func _ao_jogador_sair(id_jogador: int) -> void:
	if id_jogador == 2:
		_dar_controle_unico(1)


func _dar_controle_unico(id_jogador: int) -> void:
	if _dono_controle_unico != id_jogador:
		_dono_controle_unico = id_jogador
		_montar()


## Com um controle só e o P1 no teclado, START nesse controle chama o P2 para a
## partida com o controle (em vez de pausar o jogo do P1).
func controle_livre_para_p2() -> bool:
	return _controles_conectados().size() == 1 and _dono_controle_unico == 1 and not _usando_controle[1]


## F11 ou Alt+Enter alternam entre tela cheia e janela. O jogo abre em tela
## cheia (project.godot); em telas que não são 16:9 aparecem barras pretas.
## Fica no _input para o Enter do Alt+Enter não confirmar o botão dos menus.
func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey and evento.pressed and not evento.echo):
		return
	var alt_enter = evento.alt_pressed and evento.keycode in [KEY_ENTER, KEY_KP_ENTER]
	# Dentro da aba Game do editor o jogo só roda em janela (o Godot recusa e avisa)
	if (evento.keycode == KEY_F11 or alt_enter) and not Engine.is_embedded_in_editor():
		alternar_tela_cheia()
		get_viewport().set_input_as_handled()


func alternar_tela_cheia() -> void:
	var cheia = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	if not cheia:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	# Volta para a janela no tamanho do jogo (project.godot), no centro da tela
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var tamanho = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var tela = DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_size(tamanho)
	DisplayServer.window_set_position(tela.position + (tela.size - tamanho) / 2)


func _ao_receber_entrada(evento: InputEvent) -> void:
	if evento is InputEventJoypadButton and evento.pressed and evento.button_index == JOY_BUTTON_START \
			and not Jogo.p2_ativo and Jogo.esta_em_fase() and controle_livre_para_p2():
		_dar_controle_unico(2)
		_usando_controle[2] = true
		# Depois deste evento: assim o START não pausa o jogo do P1
		Jogo.entrar_p2.call_deferred()
		return
	_registrar_dispositivo(evento)


## Registra o dispositivo que cada jogador usou por último
func _registrar_dispositivo(evento: InputEvent) -> void:
	var de_controle = evento is InputEventJoypadButton or evento is InputEventJoypadMotion
	if evento is InputEventJoypadMotion:
		if absf(evento.axis_value) < 0.5:
			return
	elif not (de_controle or evento is InputEventKey) or not evento.is_pressed():
		return

	for id_jogador in [1, 2]:
		if de_controle and evento.device != controle_do_jogador(id_jogador):
			continue
		if not _evento_do_jogador(evento, id_jogador):
			continue
		if _usando_controle[id_jogador] != de_controle:
			_usando_controle[id_jogador] = de_controle
			dispositivo_mudou.emit(id_jogador)


func _evento_do_jogador(evento: InputEvent, id_jogador: int) -> bool:
	for nome in ACOES:
		if evento.is_action(acao(id_jogador, nome)):
			return true
	return false


## O jogador está no controle? (último dispositivo usado; sem controle, false)
func usa_controle(id_jogador: int) -> bool:
	return controle_do_jogador(id_jogador) >= 0 and _usando_controle[id_jogador]


## Nome da tecla ou botão do comando para este jogador: "T", "I", "A", "RB"...
func nome_comando(id_jogador: int, comando: String) -> String:
	if usa_controle(id_jogador):
		return NOMES_CONTROLE.get(comando, "?")
	return NOMES_TECLADO[id_jogador].get(comando, "?")


## Teclas do comando só de quem está jogando, sem repetir:
## sozinho no teclado "T"; dupla no controle "A"; misturado "T / A".
func texto_comando(comando: String) -> String:
	var nomes := PackedStringArray()
	for id_jogador in ids_jogando():
		var nome = nome_comando(id_jogador, comando)
		if not nome in nomes:
			nomes.append(nome)
	return " / ".join(nomes)


## Ids dos jogadores na partida (pelo menos o P1)
func ids_jogando() -> Array:
	var ids := []
	for jogador in Jogo.jogadores:
		if is_instance_valid(jogador) and not jogador.id_jogador in ids:
			ids.append(jogador.id_jogador)
	if ids.is_empty():
		ids.append(1)
	ids.sort()
	return ids


func acao(id_jogador: int, nome: String) -> StringName:
	return StringName("p%d_%s" % [id_jogador, nome])


func controle_do_jogador(id_jogador: int) -> int:
	return controle_p1 if id_jogador == 1 else controle_p2


## Só para os testes: simula controles plugados (ids de dispositivo)
func simular_controles(ids: Array) -> void:
	_controles_de_teste = ids
	_montar()


func _controles_conectados() -> Array:
	return Input.get_connected_joypads() if _controles_de_teste == null else _controles_de_teste


func _montar() -> void:
	var controles = _controles_conectados()
	var antes = {1: controle_p1, 2: controle_p2}
	if controles.size() >= 2:
		controle_p1 = controles[0]
		controle_p2 = controles[1]
	elif controles.size() == 1:
		controle_p1 = controles[0] if _dono_controle_unico == 1 else -1
		controle_p2 = controles[0] if _dono_controle_unico == 2 else -1
	else:
		controle_p1 = -1
		controle_p2 = -1

	for nome in ACOES:
		_montar_acao(1, nome, controle_p1)
		_montar_acao(2, nome, controle_p2)

	# Só muda o dispositivo de quem ganhou ou perdeu um controle: o P2 com
	# controle novo começa nele; o P1 continua no que estava usando.
	for id_jogador in [1, 2]:
		var agora = controle_do_jogador(id_jogador)
		if agora != antes[id_jogador]:
			_usando_controle[id_jogador] = agora >= 0 and (id_jogador == 2 or _usando_controle[id_jogador])
	controles_mudaram.emit()


func _montar_acao(id_jogador: int, nome: String, controle: int) -> void:
	var acao_jogador = acao(id_jogador, nome)

	if InputMap.has_action(acao_jogador):
		InputMap.action_erase_events(acao_jogador)
	else:
		InputMap.add_action(acao_jogador, 0.3)

	# Teclado
	if id_jogador == 1:
		if InputMap.has_action(nome):
			for evento in InputMap.action_get_events(nome):
				if evento is InputEventKey:
					InputMap.action_add_event(acao_jogador, evento)
		for tecla in TECLAS_EXTRAS_P1.get(nome, []):
			_adicionar_tecla(acao_jogador, tecla)
	else:
		for tecla in TECLAS_RESERVA_P2.get(nome, []):
			_adicionar_tecla(acao_jogador, tecla, true)

	# Controle
	if controle < 0:
		return

	for botao in BOTOES.get(nome, []):
		var evento = InputEventJoypadButton.new()
		evento.device = controle
		evento.button_index = botao
		InputMap.action_add_event(acao_jogador, evento)

	if EIXOS.has(nome):
		var eixo = InputEventJoypadMotion.new()
		eixo.device = controle
		eixo.axis = EIXOS[nome][0]
		eixo.axis_value = EIXOS[nome][1]
		InputMap.action_add_event(acao_jogador, eixo)


func _adicionar_tecla(acao_jogador: StringName, tecla: Key, lado_direito := false) -> void:
	var evento = InputEventKey.new()
	evento.device = -1 # qualquer teclado
	evento.physical_keycode = tecla
	if lado_direito and tecla in [KEY_CTRL, KEY_SHIFT]:
		evento.location = KEY_LOCATION_RIGHT
	InputMap.action_add_event(acao_jogador, evento)
