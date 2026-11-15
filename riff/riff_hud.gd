extends Control
## Modo Riff: notas descem e o jogador acerta no ritmo para ferir o boss.
##
## Cada jogador toca nas suas próprias pistas e tem uma trava independente.
##
## Aceleração: quanto mais tempo no Riff, mais rápido as notas caem (sempre
## chegando no tempo da música), até velocidade_maxima. Volta ao normal ao sair.
##
## Nota maldita (se o boss permitir): vermelha, machuca quem tocar. Sempre
## vem com uma nota normal junto, para existir um acerto possível.
## Com o escudo do boss ativo, as notas não ferem.
##
## Trava: sair do Riff trava ele por trava_ao_sair segundos; ser expulso por
## dano (inclusive da nota maldita), por trava_por_dano. A arena controla
## quando sair; aqui fica o tempo restante (o HUD mostra uma ampulheta).
## Aviso: com o Riff aberto e o boss fora do descanso (atacando), um "!" pisca.

## Dano por nota: jogando sozinho, 1×. Em dupla, 0,5× com só um Riff aberto
## e 1× com os dois tocando juntos.
const DANO_RIFF_SINGLEPLAYER = 1.0
const DANO_RIFF_SOLO_EM_DUPLA = 0.5
const DANO_RIFF_EM_DUPLA = 1.0
const TECLAS = ["riff_esquerda", "riff_cima", "riff_baixo", "riff_direita"]

@export var id_jogador: int = 1
@export var cena_nota: PackedScene
@export var bpm: float = 150.0
## Atraso da batida da música (segundos), para as notas chegarem no tempo
@export var offset_batida: float = 0.516
@export var chance_nota_maldita: float = 0.15
## Dano por nota (bosses com usar_fases calculam o próprio)
@export var dano_perfect: int = 3
@export var dano_good: int = 1
## Quem leva o dano. A arena (arena_boss.gd) preenche sozinha.
@export var boss: Node2D

@export_group("Trava")
## Segundos sem poder abrir o Riff depois de levar dano tocando
@export var trava_por_dano: float = 5.0
## Segundos sem poder abrir o Riff depois de fechar por conta própria
@export var trava_ao_sair: float = 1.0

@export_group("Dificuldade")
## Quanto a velocidade das notas sobe por segundo de Riff (0,03 = +3%/s)
@export var aceleracao_por_segundo: float = 0.03
## Limite da aceleração (1,6 = notas 60% mais rápidas)
@export var velocidade_maxima: float = 1.6
## Em dupla: chance de começar uma sequência de notas juntas (P1 e P2)
@export var chance_notas_juntas: float = 0.2

@onready var notas_container = $NotasContainer
@onready var label_feedback = $LabelFeedback
@onready var label_jogador = $LabelJogador
@onready var aviso = $Aviso
@onready var indicadores = [
	$NotasContainer/IndicadorEsquerda, $NotasContainer/IndicadorCima,
	$NotasContainer/IndicadorBaixo, $NotasContainer/IndicadorDireita,
]

const INDICADORES_CONTROLE = [
	preload("res://riff/sprites/botao_lt.svg"),
	preload("res://riff/sprites/botao_lb.svg"),
	preload("res://riff/sprites/botao_rb.svg"),
	preload("res://riff/sprites/botao_rt.svg"),
]
const INDICADORES_SETAS = [
	preload("res://riff/sprites/tecla_esquerda_apagada.png"),
	preload("res://riff/sprites/tecla_cima_apagada.png"),
	preload("res://riff/sprites/tecla_baixo_apagada.png"),
	preload("res://riff/sprites/tecla_direita_apagada.png"),
]
const INDICADORES_P1 = [
	preload("res://riff/sprites/tecla_a_apagada.png"),
	preload("res://riff/sprites/tecla_w_apagada.png"),
	preload("res://riff/sprites/tecla_s_apagada.png"),
	preload("res://riff/sprites/tecla_d_apagada.png"),
]

const COR_PERFECT = Color(0.35, 0.9, 1.0)
const COR_GOOD = Color(0.5, 1.0, 0.5)
const COR_MISS = Color(1.0, 0.3, 0.3)
const COR_MALDITA = Color(1.0, 0.15, 0.15)
const COR_ESCUDO = Color(0.5, 0.8, 1.0)

var parceiro: Control
var tocando = false
var posicao_acerto: float = 260.0
var janela_perfect: float = 12.0
var janela_good: float = 30.0
var geracao_id: int = 0
var tween_feedback: Tween
var viagem_nota: float = 0.0
var velocidade_base: float = 200.0
var tempo_no_riff := 0.0
var trava_restante := 0.0
var trava_total := 0.0


func _ready() -> void:
	label_jogador.text = "P%d" % id_jogador
	label_jogador.modulate = Jogo.cor(id_jogador)
	$NotasContainer/LinhaAcerto.color = Jogo.cor(id_jogador)
	Controles.controles_mudaram.connect(_atualizar_teclas)
	_atualizar_teclas()


func iniciar_riff():
	if tocando:
		return

	var modelo = cena_nota.instantiate()
	velocidade_base = modelo.velocidade
	viagem_nota = (posicao_acerto + 30.0) / velocidade_base
	modelo.free()

	tocando = true
	tempo_no_riff = 0.0
	aviso.hide()
	geracao_id += 1
	gerar_notas(geracao_id)


func parar_riff():
	tocando = false
	label_feedback.text = ""
	aviso.hide()

	for nota in _notas():
		nota.queue_free()


func gerar_notas(id):
	while tocando and id == geracao_id:
		# A velocidade é decidida antes de esperar, para a nota cair no tempo
		var fator = fator_velocidade()
		await get_tree().create_timer(_tempo_ate_proxima_nota(fator), false).timeout

		if not is_inside_tree() or not tocando or id != geracao_id:
			return

		var coluna = randi_range(0, 3)
		var outras = [0, 1, 2, 3]
		outras.erase(coluna)

		var maldita = boss.has_method("nota_maldita_disponivel") and boss.nota_maldita_disponivel() and randf() < chance_nota_maldita

		_criar_nota(coluna, id_jogador, maldita, fator)

		if maldita:
			_criar_nota(outras.pick_random(), id_jogador, false, fator)


## Quanto mais tempo no Riff, mais rápido (1 = normal)
func fator_velocidade() -> float:
	return minf(1.0 + tempo_no_riff * aceleracao_por_segundo, velocidade_maxima)


func _criar_nota(coluna: int, dono: int, maldita: bool, fator := 1.0) -> void:
	var nota = cena_nota.instantiate()
	nota.velocidade = velocidade_base * fator
	notas_container.add_child(nota)
	nota.coluna = coluna
	nota.dono = dono
	nota.maldita = maldita
	nota.atualizar_seta()
	nota.position = Vector2(coluna * 61 + 13, -30)
	nota.perdida.connect(_registrar_miss)

	if maldita:
		nota.modulate = COR_MALDITA
	else:
		nota.modulate = Color.WHITE.lerp(Jogo.cor(dono), 0.65)


# Quanto esperar para a próxima nota chegar à linha no tempo da música
func _tempo_ate_proxima_nota(fator := 1.0) -> float:
	var periodo = 60.0 / bpm
	var chegada = Audio.posicao_musica() + viagem_nota / fator - offset_batida
	var falta = periodo - fposmod(chegada, periodo)
	# Evita duas notas coladas quando o timer acorda logo antes da batida
	return falta + periodo if falta < 0.05 else falta


func _notas() -> Array:
	return notas_container.get_children().filter(func(n): return n.has_method("atualizar_seta"))


func _process(delta: float) -> void:
	if trava_restante > 0.0:
		trava_restante = maxf(trava_restante - delta, 0.0)

	if not tocando:
		return

	tempo_no_riff += delta
	var multiplicador = str(multiplicador_de_dano()).replace(".", ",") + "×"
	label_jogador.text = "P%d  ·  %s" % [id_jogador, multiplicador]
	# "!" piscando: o boss não está descansando, ele pode atacar a qualquer hora
	aviso.visible = boss != null and not boss.get("descansando")

	for i in range(4):
		if not tocando:
			return
		if Input.is_action_just_pressed(Controles.acao(id_jogador, TECLAS[i])):
			verificar_nota(i, id_jogador)


func _atualizar_teclas() -> void:
	_mostrar_teclas_de(id_jogador)


func _mostrar_teclas_de(id_jogador: int) -> void:
	var texturas = INDICADORES_P1 if id_jogador == 1 else INDICADORES_SETAS
	if Controles.controle_do_jogador(id_jogador) >= 0:
		texturas = INDICADORES_CONTROLE
	for i in indicadores.size():
		indicadores[i].texture = texturas[i]


# ---------------------------------------------------------------- Trava e aviso

func travar(segundos: float) -> void:
	trava_total = segundos
	trava_restante = segundos


func travado() -> bool:
	return trava_restante > 0.0


## 0 = acabou de travar, 1 = liberado (para a ampulheta do HUD)
func progresso_trava() -> float:
	return 1.0 if trava_total <= 0.0 else 1.0 - trava_restante / trava_total


func verificar_nota(coluna, dono := 1):
	if not tocando or dono != id_jogador:
		return
	var nota_maxima = null
	var menor_distancia = janela_good
	var tem_nota_propria = false

	for nota in _notas():
		if nota.dono != id_jogador or nota.acertada or nota.is_queued_for_deletion():
			continue

		tem_nota_propria = true

		if nota.coluna != coluna:
			continue

		var distancia = abs(nota.position.y - posicao_acerto)

		if distancia <= menor_distancia:
			menor_distancia = distancia
			nota_maxima = nota

	if nota_maxima == null:
		# Sem notas nas pistas, apertar uma tecla não conta como erro
		if tem_nota_propria:
			_registrar_miss()
		return

	nota_maxima.acertada = true
	nota_maxima.queue_free()

	if nota_maxima.maldita:
		Audio.tocar("nota_maldita")
		_mostrar_feedback("MALDITA!", COR_MALDITA)
		var jogador = Jogo.jogador_por_id(id_jogador)
		if jogador:
			jogador.receber_dano(1)
		return

	if boss.get("escudo_ativo"):
		Audio.tocar("escudo", 0.0)
		_mostrar_feedback("ESCUDO", COR_ESCUDO)
		return

	var perfect = menor_distancia <= janela_perfect
	# Boss com fases calcula o próprio dano (um Riff bom = uma fase)
	var dano = boss.dano_da_nota(perfect) if boss.get("usar_fases") else (dano_perfect if perfect else dano_good)

	if perfect:
		Audio.tocar("nota_perfect", 0.0)
		_mostrar_feedback("PERFECT!", COR_PERFECT)
	else:
		Audio.tocar("nota_good", 0.0)
		_mostrar_feedback("GOOD", COR_GOOD)

	boss.receber_dano(dano * multiplicador_de_dano())


func multiplicador_de_dano() -> float:
	if Jogo.jogadores.size() < 2:
		return DANO_RIFF_SINGLEPLAYER
	return DANO_RIFF_EM_DUPLA if _tocando_em_dupla() else DANO_RIFF_SOLO_EM_DUPLA


func _tocando_em_dupla() -> bool:
	return is_instance_valid(parceiro) and parceiro.tocando


func _registrar_miss():
	Audio.tocar("nota_miss")
	_mostrar_feedback("MISS", COR_MISS)


func _mostrar_feedback(texto, cor):
	label_feedback.text = texto
	label_feedback.modulate = cor
	label_feedback.scale = Vector2(1.3, 1.3)

	if tween_feedback:
		tween_feedback.kill()

	tween_feedback = create_tween()
	tween_feedback.tween_property(label_feedback, "scale", Vector2.ONE, 0.12)
	tween_feedback.tween_interval(0.25)
	tween_feedback.tween_property(label_feedback, "modulate:a", 0.0, 0.2)
