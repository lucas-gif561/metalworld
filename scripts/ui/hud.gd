extends CanvasLayer
## HUD das fases: vida e stamina de cada jogador, progresso, avisos e tela de fim.
## Conecta sozinho com os jogadores que existem e com quem entrar depois.

@export var deslocamento_vida := Vector2.ZERO
@export var distancia_paineis := 240.0

@onready var painel_vida = $PainelVida
@onready var progresso = $Progresso
@onready var aviso = $Aviso
@onready var tela_fim = $TelaFim
@onready var titulo_fim = $TelaFim/Conteudo/Titulo
@onready var subtitulo_fim = $TelaFim/Conteudo/Subtitulo

var aviso_id := 0
var paineis := {}
var conectados := []
var dica_p2: Label


func _ready() -> void:
	painel_vida.position += deslocamento_vida
	progresso.position += deslocamento_vida
	aviso.hide()
	tela_fim.hide()

	var painel_p2 = painel_vida.duplicate()
	painel_p2.name = "PainelVidaP2"
	painel_p2.position = painel_vida.position + Vector2(distancia_paineis, 0)
	add_child(painel_p2)
	painel_p2.hide()

	paineis = {1: painel_vida, 2: painel_p2}
	for id_jogador in paineis:
		_marcar_painel(paineis[id_jogador], id_jogador)

	dica_p2 = Label.new()
	dica_p2.text = "P2: aperte START / A\nno controle para entrar"
	dica_p2.position = painel_p2.position
	dica_p2.add_theme_color_override("font_color", Jogo.cor(2))
	dica_p2.add_theme_color_override("font_outline_color", Color.BLACK)
	dica_p2.add_theme_constant_override("outline_size", 5)
	dica_p2.add_theme_font_size_override("font_size", 15)
	add_child(dica_p2)

	for jogador in Jogo.jogadores:
		conectar_jogador(jogador)
	Jogo.jogador_entrou.connect(conectar_jogador)


func _process(_delta: float) -> void:
	dica_p2.visible = not Jogo.p2_ativo and not tela_fim.visible


func _marcar_painel(painel: Control, id_jogador: int) -> void:
	var marca = ColorRect.new()
	marca.color = Jogo.cor(id_jogador)
	marca.position = Vector2(-6, 0)
	marca.size = Vector2(4, 43)
	painel.add_child(marca)


func conectar_jogador(jogador) -> void:
	if jogador in conectados or not paineis.has(jogador.id_jogador):
		return
	conectados.append(jogador)

	var painel = paineis[jogador.id_jogador]
	painel.show()
	jogador.vida_alterada.connect(_atualizar_vida.bind(painel, jogador.id_jogador))
	jogador.stamina_alterada.connect(_atualizar_stamina.bind(painel))
	_atualizar_vida(jogador.vida, jogador.vida_maxima, painel, jogador.id_jogador)
	_atualizar_stamina(jogador.stamina, jogador.stamina_maxima, painel)


func _atualizar_stamina(atual, maxima, painel) -> void:
	var barra = painel.get_node("BarraStamina")
	barra.max_value = maxima
	barra.value = atual


func _atualizar_vida(atual, maxima, painel, id_jogador) -> void:
	var barra = painel.get_node("BarraVida")
	barra.max_value = maxima
	barra.value = atual
	var texto = "CAÍDO" if atual <= 0 else "VIDA %d/%d" % [atual, maxima]
	painel.get_node("TextoVida").text = "P%d  %s" % [id_jogador, texto]


func definir_progresso(texto: String) -> void:
	progresso.text = texto


func mostrar_aviso(texto: String, duracao := 0.0) -> void:
	aviso_id += 1
	var id := aviso_id
	aviso.text = texto
	aviso.show()

	if duracao > 0.0:
		await get_tree().create_timer(duracao).timeout
		if id == aviso_id:
			aviso.hide()


func esconder_aviso() -> void:
	aviso_id += 1
	aviso.hide()


func mostrar_fim(titulo: String, subtitulo: String, cor: Color) -> void:
	esconder_aviso()
	titulo_fim.text = titulo
	titulo_fim.modulate = cor
	subtitulo_fim.text = subtitulo
	tela_fim.show()
