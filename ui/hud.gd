extends CanvasLayer
## HUD das fases: retrato, corações (vida) e raios (poder) de cada jogador,
## título da fase, seta de seguir, avisos e tela de fim. Conecta sozinho com os jogadores que
## existem e com quem entrar depois.
##
## Visual inteiro na cena (hud.tscn): cada coração e raio é um
## TextureProgressBar; o vazio é a mesma textura escurecida (tint_under) e o
## raio enche de baixo para cima enquanto o poder recarrega. A entrada do
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
## Onde o cadeado do Riff fica em relação aos pés do jogador
@export var deslocamento_trava := Vector2(0, 30)

var _tweens_trava: Dictionary = {}
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
	# Vaga do P2: silhueta piscando com o botão de entrar (START num controle
	# livre; sem controle livre, J no teclado). Troca se plugar um controle ou
	# se o P1 passar a usar o controle único.
	vaga_p2.visible = not Jogo.p2_ativo and not tela_fim.visible
	if vaga_p2.visible:
		var tem_controle = Controles.controle_do_jogador(2) >= 0 or Controles.controle_livre_para_p2()
		vaga_p2.get_node("Botoes/BotaoControle").visible = tem_controle
		vaga_p2.get_node("Botoes/TeclaTeclado").visible = not tem_controle


func conectar_jogador(jogador) -> void:
	if jogador in conectados or not paineis.has(jogador.id_jogador):
		return
	conectados.append(jogador)

	var painel = paineis[jogador.id_jogador]
	painel.show()
	# O rosto depende de quem cada jogador escolheu (Dylan ou Kevin), então vem
	# do personagem; o da cena (hud.tscn) é só o padrão
	if jogador.retrato:
		painel.get_node("Retrato/Rosto").texture = jogador.retrato
	jogador.vida_alterada.connect(_atualizar_vida.bind(painel))
	jogador.poder_alterado.connect(_atualizar_poder.bind(painel))
	_atualizar_vida(jogador.vida, jogador.vida_maxima, painel)
	_atualizar_poder(jogador.poder, jogador.poder_maximo, painel)
	# O Minirriff em si aparece em cima do jogador (personagens/dylan/visor_minirriff.tscn)
	painel.get_node("Icones/Raios").visible = jogador.usa_minirriff()


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


func _atualizar_poder(atual, maxima, painel) -> void:
	var raios = painel.get_node("Icones/Raios").get_children()
	var valor_raio = maxima / raios.size()
	for i in raios.size():
		var raio = raios[i]
		var antes = raio.value
		raio.value = clampf((atual - i * valor_raio) / valor_raio, 0.0, 1.0)
		if raio.value >= 1.0 and antes < 1.0:
			_pulsar(raio)


# Ícone que mudou dá um pulo rápido (efeito da partida, por isso em código)
func _pulsar(icone: Control) -> void:
	icone.pivot_offset = icone.size / 2.0
	icone.scale = Vector2(1.4, 1.4)
	icone.create_tween().tween_property(icone, "scale", Vector2.ONE, 0.2)


## Cabo de força: a vida fica na barra do cabo; aqui sobra só os indicadores de combate
func usar_vida_compartilhada() -> void:
	for painel in paineis.values():
		painel.get_node("Icones/Coracoes").hide()


## Nome da fase entrando na tela no começo (estilo Sonic)
func mostrar_titulo(texto: String) -> void:
	if texto.is_empty():
		return
	titulo_fase.get_node("Nome").text = texto
	titulo_fase.get_node("Animacao").play("entrar")


## Cadeado do Riff travado, embaixo do jogador: esvazia de cima para baixo até
## liberar (1 = liberado). Vale para a trava do Riff e para os instrumentos
## desligados pelos totens do boss. Segue o jogador, por isso a posição é em código.
func mostrar_trava_riff(progresso: float, id_jogador := 1, jogador: Node2D = null) -> void:
	var trava = $TravaRiff if id_jogador == 1 else $TravaRiffP2
	trava.visible = progresso < 1.0 and jogador != null
	# O cadeado começa cheio e esvazia até liberar
	trava.value = 1.0 - progresso
	if trava.visible:
		var pes = jogador.get_global_transform_with_canvas().origin
		# position (e não global_position): com o cadeado girando ao tremer, o
		# global_position conta a rotação em volta do pivô e o tira do lugar
		trava.position = pes + deslocamento_trava - trava.size / 2.0


## Tentou abrir o Riff travado: o cadeado treme
func recusar_riff(id_jogador := 1) -> void:
	Audio.tocar("nota_miss")
	var trava = $TravaRiff if id_jogador == 1 else $TravaRiffP2
	if _tweens_trava.has(id_jogador):
		_tweens_trava[id_jogador].kill()
	trava.rotation = 0.0
	var tween = trava.create_tween()
	_tweens_trava[id_jogador] = tween
	for angulo in [0.3, -0.3, 0.15, 0.0]:
		tween.tween_property(trava, "rotation", angulo, 0.05)


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
