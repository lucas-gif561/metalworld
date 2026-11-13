extends Control
## Menu principal (tema "Palco de show").
##
## Visual inteiro na cena (tela_inicial.tscn) e no tema dos botões
## (tema_menu.tres): placa do título, botões apagado/aceso e janela de
## Controles/Créditos. Aqui fica só o comportamento.
##
## Navegação: setas, WASD, direcional ou analógico de qualquer jogador.
## Confirmar: Enter, Espaço, J, A ou START.

const TEXTO_CONTROLES = """P1 (teclado): WASD mover · J socar · K dodge · E interagir e levantar
Espaço abre o Riff · Setas tocam as notas · R reinicia depois do game over

P2 (controle): analógico mover · X socar · A dodge · B interagir e levantar
LB abre o Riff · X Y A B tocam as notas · START entra na partida e reinicia

ESC / START pausa (e permite remover o P2).
Caído? O parceiro segura E / B perto para levantar.
No boss, só as notas do Riff ferem: abra o Riff quando o boss se ajoelhar."""

const TEXTO_CREDITOS = """MetalWorld — projeto da disciplina

Dylan e interface: gerados pela equipe no PixelLab
Ícones do HUD: Critters Pixel UI (Foozle), CC0
Inimigos: Streets of Fight (ansimuz) e Business of Rage (DidiGameB), CC0
Boss: Doom Scribe (CC BY 4.0)
Barris e caixotes: Elthen · Comida: Pixel Coder
Músicas: MintoDog (CC0) · Efeitos sonoros: Bfxr
Teclas do Riff: Kenney

Lista completa com licenças no arquivo CREDITS.md"""

const ESPERA_NAVEGACAO = 0.18

@onready var menu = $Menu
@onready var placa = $Placa
@onready var janela = $Janela
@onready var titulo_janela = $Janela/Moldura/Titulo
@onready var texto_janela = $Janela/Moldura/Texto

var _proxima_navegacao := 0.0
var _iniciando := false


func _ready() -> void:
	Audio.tocar_musica("ruas")
	$Menu/JogarSozinho.pressed.connect(_jogar.bind(false))
	$Menu/JogarDupla.pressed.connect(_jogar.bind(true))
	$Menu/Controles.pressed.connect(_abrir_janela.bind("Controles", TEXTO_CONTROLES))
	$Menu/Creditos.pressed.connect(_abrir_janela.bind("Créditos", TEXTO_CREDITOS))
	for botao in menu.get_children():
		botao.focus_entered.connect(_ao_focar)
		botao.mouse_entered.connect(botao.grab_focus)
	janela.hide()
	$Menu/JogarSozinho.grab_focus.call_deferred()
	_animar_placa()


# A placa "respira" devagar, como letreiro de palco
func _animar_placa() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(placa, "scale", Vector2(1.03, 1.03), 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(placa, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE)


func _ao_focar() -> void:
	Audio.tocar("nota_good", 0.0)


func _jogar(em_dupla: bool) -> void:
	if _iniciando:
		return
	_iniciando = true
	Jogo.p2_ativo = em_dupla
	Audio.tocar("ui_confirma", 0.0)
	Jogo.iniciar_jogo()


func _abrir_janela(titulo: String, texto: String) -> void:
	Audio.tocar("ui_confirma", 0.0)
	titulo_janela.text = titulo
	texto_janela.text = texto
	janela.show()


func _fechar_janela() -> void:
	janela.hide()
	var focado = get_viewport().gui_get_focus_owner()
	if focado == null:
		$Menu/JogarSozinho.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if janela.visible:
		if event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion and not event is InputEventJoypadMotion:
			_fechar_janela()
			get_viewport().set_input_as_handled()
		return

	# WASD do P1 e controles: as setas e o direcional já navegam sozinhos (ui_up/ui_down)
	if _apertou(event, "mover_cima"):
		_navegar(-1)
	elif _apertou(event, "mover_baixo"):
		_navegar(1)
	elif _apertou(event, "atacar") or _apertou(event, "entrar"):
		var focado = get_viewport().gui_get_focus_owner()
		if focado is Button:
			focado.pressed.emit()
			get_viewport().set_input_as_handled()


func _apertou(event: InputEvent, nome: String) -> bool:
	for id_jogador in [1, 2]:
		if event.is_action_pressed(Controles.acao(id_jogador, nome), false):
			return true
	return false


func _navegar(passo: int) -> void:
	var agora = Time.get_ticks_msec() / 1000.0
	if agora < _proxima_navegacao:
		return
	_proxima_navegacao = agora + ESPERA_NAVEGACAO
	var botoes = menu.get_children()
	var atual = botoes.find(get_viewport().gui_get_focus_owner())
	botoes[wrapi(atual + passo, 0, botoes.size())].grab_focus()
	get_viewport().set_input_as_handled()
