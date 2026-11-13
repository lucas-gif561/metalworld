extends CanvasLayer
## HUD das fases: retrato, corações (vida) e raios (stamina) de cada jogador,
## título da fase, seta de seguir, avisos e tela de fim. Conecta sozinho com os jogadores que
## existem e com quem entrar depois.
##
## Visual inteiro na cena (hud.tscn): cada coração e raio é um
## TextureProgressBar; o vazio é a mesma textura escurecida (tint_under) e o
## raio enche de baixo para cima enquanto a stamina recarrega. A entrada do
## título e o pisca da seta são AnimationPlayers.

const COR_CAIDO = Color(0.3, 0.3, 0.35, 1)

## Desloca os painéis de vida (ex.: para baixo da barra do boss)
@export var deslocamento_vida := Vector2.ZERO

@onready var painel_vida = $PainelVida
@onready var painel_p2 = $PainelVidaP2
@onready var vaga_p2 = $VagaP2
@onready var siga = $Siga
@onready var aviso = $Aviso
@onready var titulo_fase = $TituloFase
@onready var tela_fim = $TelaFim
@onready var titulo_fim = $TelaFim/Conteudo/Titulo
@onready var subtitulo_fim = $TelaFim/Conteudo/Subtitulo

var aviso_id := 0
var paineis := {}
var conectados := []


func _ready() -> void:
	for no in [painel_vida, painel_p2, vaga_p2]:
		no.position += deslocamento_vida
	aviso.hide()
	siga.hide()
	titulo_fase.hide()
	tela_fim.hide()
	painel_p2.hide()
	paineis = {1: painel_vida, 2: painel_p2}

	for jogador in Jogo.jogadores:
		conectar_jogador(jogador)
	Jogo.jogador_entrou.connect(_ao_jogador_entrar)
	Jogo.jogador_saiu.connect(_ao_jogador_sair)


func _process(_delta: float) -> void:
	# Vaga do P2: silhueta piscando com o botão de entrar (A no controle;
	# sem controle, a tecla do teclado reserva). Troca se plugar um controle.
	vaga_p2.visible = not Jogo.p2_ativo and not tela_fim.visible
	if vaga_p2.visible:
		var tem_controle = Controles.controle_do_jogador(2) >= 0
		vaga_p2.get_node("Botoes/BotaoControle").visible = tem_controle
		vaga_p2.get_node("Botoes/TeclaTeclado").visible = not tem_controle


func conectar_jogador(jogador) -> void:
	if jogador in conectados or not paineis.has(jogador.id_jogador):
		return
	conectados.append(jogador)

	var painel = paineis[jogador.id_jogador]
	painel.show()
	jogador.vida_alterada.connect(_atualizar_vida.bind(painel))
	jogador.stamina_alterada.connect(_atualizar_stamina.bind(painel, jogador.custo_dodge))
	_atualizar_vida(jogador.vida, jogador.vida_maxima, painel)
	_atualizar_stamina(jogador.stamina, jogador.stamina_maxima, painel, jogador.custo_dodge)


# Quem entra no meio da fase ganha uma entrada com flash
func _ao_jogador_entrar(jogador) -> void:
	conectar_jogador(jogador)
	if jogador.entrando and paineis.has(jogador.id_jogador):
		_animar_entrada(paineis[jogador.id_jogador], jogador.vida)


## Retrato acende com um flash e os corações enchem um por um
func _animar_entrada(painel: Control, vida: int) -> void:
	var retrato = painel.get_node("Retrato")
	var coracoes = painel.get_node("Icones/Coracoes").get_children()
	for coracao in coracoes:
		coracao.value = 0.0
	retrato.modulate = Color(4, 4, 4)
	var tween = create_tween()
	tween.tween_property(retrato, "modulate", Color.WHITE, 0.4)
	for i in mini(vida, coracoes.size()):
		tween.tween_callback(func():
			coracoes[i].value = 1.0
			_pulsar(coracoes[i]))
		tween.tween_interval(0.1)


func _ao_jogador_sair(id_jogador: int) -> void:
	if paineis.has(id_jogador):
		paineis[id_jogador].hide()
	conectados = conectados.filter(func(j): return is_instance_valid(j) and j.id_jogador != id_jogador)


## Um coração por ponto de vida (a cena tem 5; vida maior que isso não aparece)
func _atualizar_vida(atual, maxima, painel) -> void:
	var coracoes = painel.get_node("Icones/Coracoes").get_children()
	for i in coracoes.size():
		var coracao = coracoes[i]
		coracao.visible = i < maxima
		var cheio = 1.0 if i < atual else 0.0
		if coracao.value != cheio:
			coracao.value = cheio
			_pulsar(coracao)
	# Caído: retrato apagado (o parceiro pode levantar)
	painel.get_node("Retrato").modulate = COR_CAIDO if atual <= 0 else Color.WHITE


## Um raio por dodge: cada raio vale custo_dodge de stamina
func _atualizar_stamina(atual, maxima, painel, custo) -> void:
	var raios = painel.get_node("Icones/Raios").get_children()
	for i in raios.size():
		var raio = raios[i]
		raio.visible = (i + 1) * custo <= maxima
		var antes = raio.value
		raio.value = clampf((atual - i * custo) / custo, 0.0, 1.0)
		if raio.value >= 1.0 and antes < 1.0:
			_pulsar(raio)


# Ícone que mudou dá um pulo rápido (efeito da partida, por isso em código)
func _pulsar(icone: Control) -> void:
	icone.pivot_offset = icone.size / 2.0
	icone.scale = Vector2(1.4, 1.4)
	icone.create_tween().tween_property(icone, "scale", Vector2.ONE, 0.2)


## Cabo de força: a vida fica na barra do cabo; aqui sobra só a stamina
func usar_vida_compartilhada() -> void:
	for painel in paineis.values():
		painel.get_node("Icones/Coracoes").hide()


## Nome da fase entrando na tela no começo (estilo Sonic)
func mostrar_titulo(texto: String) -> void:
	if texto.is_empty():
		return
	titulo_fase.get_node("Nome").text = texto
	titulo_fase.get_node("Animacao").play("entrar")


## Seta piscando para a direita quando a área foi limpa
func mostrar_siga(mostrar: bool) -> void:
	siga.visible = mostrar


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
	siga.hide()
	titulo_fim.text = titulo
	titulo_fim.modulate = cor
	subtitulo_fim.text = subtitulo
	tela_fim.show()
