extends Node
## Comandos de cada jogador (autoload "Controles").
##
## Cada ação existe em duas versões: "p1_<acao>" e "p2_<acao>".
## Use sempre jogador.acao("atirar") ou Controles.acao(id, "atirar"),
## nunca Input.is_action_pressed("atirar") direto.
##
## Jogador 1: teclado (teclas definidas no Mapa de Entrada do projeto) e,
##            se houver dois controles, o primeiro controle.
## Jogador 2: o controle que sobrar. Sem controle, usa o teclado reserva
##            (setas, Ctrl direito, Shift direito, Enter, Backspace),
##            pensado só para testar sozinho no computador.

signal controles_mudaram

const ACOES = [
	"mover_cima", "mover_baixo", "mover_esquerda", "mover_direita",
	"atirar", "dodge", "interagir", "riff_mode",
	"riff_cima", "riff_baixo", "riff_esquerda", "riff_direita",
	"reiniciar", "entrar",
]

# Botões no padrão Xbox (A embaixo, B direita, X esquerda, Y em cima).
# No Riff os botões de face seguem a posição da seta: X ←, Y ↑, A ↓, B →.
const BOTOES = {
	"mover_cima": [JOY_BUTTON_DPAD_UP],
	"mover_baixo": [JOY_BUTTON_DPAD_DOWN],
	"mover_esquerda": [JOY_BUTTON_DPAD_LEFT],
	"mover_direita": [JOY_BUTTON_DPAD_RIGHT],
	"atirar": [JOY_BUTTON_X],
	"dodge": [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER],
	"interagir": [JOY_BUTTON_B],
	"riff_mode": [JOY_BUTTON_LEFT_SHOULDER],
	"riff_cima": [JOY_BUTTON_Y, JOY_BUTTON_DPAD_UP],
	"riff_baixo": [JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN],
	"riff_esquerda": [JOY_BUTTON_X, JOY_BUTTON_DPAD_LEFT],
	"riff_direita": [JOY_BUTTON_B, JOY_BUTTON_DPAD_RIGHT],
	"reiniciar": [JOY_BUTTON_START],
	"entrar": [JOY_BUTTON_START, JOY_BUTTON_A],
}

const EIXOS = {
	"mover_cima": [JOY_AXIS_LEFT_Y, -1.0],
	"mover_baixo": [JOY_AXIS_LEFT_Y, 1.0],
	"mover_esquerda": [JOY_AXIS_LEFT_X, -1.0],
	"mover_direita": [JOY_AXIS_LEFT_X, 1.0],
}

# Teclado reserva do jogador 2 (só para testes sem controle)
const TECLAS_RESERVA_P2 = {
	"mover_cima": [KEY_UP],
	"mover_baixo": [KEY_DOWN],
	"mover_esquerda": [KEY_LEFT],
	"mover_direita": [KEY_RIGHT],
	"atirar": [KEY_CTRL],
	"dodge": [KEY_SHIFT],
	"interagir": [KEY_ENTER],
	"riff_mode": [KEY_BACKSPACE],
	"riff_cima": [KEY_UP],
	"riff_baixo": [KEY_DOWN],
	"riff_esquerda": [KEY_LEFT],
	"riff_direita": [KEY_RIGHT],
	"reiniciar": [KEY_BACKSPACE],
	"entrar": [KEY_CTRL],
}

# Ações do jogador 1 que não estão no Mapa de Entrada do projeto
const TECLAS_EXTRAS_P1 = {
	"entrar": [KEY_ENTER],
}

var controle_p1 := -1
var controle_p2 := -1


func _ready() -> void:
	Input.joy_connection_changed.connect(func(_id, _conectado): _montar())
	_montar()


func acao(id_jogador: int, nome: String) -> StringName:
	return StringName("p%d_%s" % [id_jogador, nome])


func controle_do_jogador(id_jogador: int) -> int:
	return controle_p1 if id_jogador == 1 else controle_p2


func _montar() -> void:
	var controles = Input.get_connected_joypads()
	controle_p1 = controles[0] if controles.size() >= 2 else -1
	controle_p2 = controles[1] if controles.size() >= 2 else (controles[0] if controles.size() == 1 else -1)

	for nome in ACOES:
		_montar_acao(1, nome, controle_p1)
		_montar_acao(2, nome, controle_p2)

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
