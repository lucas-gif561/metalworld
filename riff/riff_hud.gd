extends Control
## Modo Riff: notas descem e o jogador acerta no ritmo para ferir o boss.
##
## Co-op (revezamento): as notas vêm em blocos de NOTAS_POR_BLOCO, alternando
## entre P1 e P2. Cada nota tem a cor do dono e só o dono pode acertá-la.
## Se só um jogador estiver de pé, todas as notas são dele.
##
## Notas juntas: em dupla, às vezes vem uma sequência de batidas com uma nota
## de cada jogador ao mesmo tempo (chance_notas_juntas).
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

const NOTAS_POR_BLOCO = 4
const TECLAS = ["riff_esquerda", "riff_cima", "riff_baixo", "riff_direita"]

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
@export var trava_por_dano: float = 30.0
## Segundos sem poder abrir o Riff depois de fechar por conta própria
@export var trava_ao_sair: float = 10.0

@export_group("Dificuldade")
## Quanto a velocidade das notas sobe por segundo de Riff (0,03 = +3%/s)
@export var aceleracao_por_segundo: float = 0.03
## Limite da aceleração (1,6 = notas 60% mais rápidas)
@export var velocidade_maxima: float = 1.6
## Em dupla: chance de começar uma sequência de notas juntas (P1 e P2)
@export var chance_notas_juntas: float = 0.2

@onready var notas_container = $NotasContainer
@onready var label_feedback = $LabelFeedback
@onready var label_vez = $LabelVez
@onready var aviso = $Aviso
@onready var indicadores = [
	$NotasContainer/IndicadorEsquerda, $NotasContainer/IndicadorCima,
	$NotasContainer/IndicadorBaixo, $NotasContainer/IndicadorDireita,
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

var tocando = false
var posicao_acerto: float = 260.0
var janela_perfect: float = 12.0
var janela_good: float = 30.0
var geracao_id: int = 0
var tween_feedback: Tween
var dono_bloco: int = 1
var notas_no_bloco: int = 0
var viagem_nota: float = 0.0
var velocidade_base: float = 200.0
var tempo_no_riff := 0.0
var juntas_restantes := 0
var trava_restante := 0.0
var trava_total := 0.0


func iniciar_riff():
	if tocando:
		return

	var modelo = cena_nota.instantiate()
	velocidade_base = modelo.velocidade
	viagem_nota = (posicao_acerto + 30.0) / velocidade_base
	modelo.free()

	tocando = true
	tempo_no_riff = 0.0
	juntas_restantes = 0
	aviso.hide()
	geracao_id += 1
	notas_no_bloco = 0
	var vivos = _ids_vivos()
	dono_bloco = vivos[0] if not vivos.is_empty() else 1
	gerar_notas(geracao_id)


func parar_riff():
	tocando = false
	label_feedback.text = ""
	label_vez.hide()
	aviso.hide()

	for nota in _notas():
		nota.queue_free()


func gerar_notas(id):
	while tocando and id == geracao_id:
		# A velocidade é decidida antes de esperar, para a nota cair no tempo
		var fator = fator_velocidade()
		await get_tree().create_timer(_tempo_ate_proxima_nota(fator)).timeout

		if not tocando or id != geracao_id:
			return

		var coluna = randi_range(0, 3)
		var outras = [0, 1, 2, 3]
		outras.erase(coluna)

		if _vem_notas_juntas():
			_criar_nota(coluna, 1, false, fator)
			_criar_nota(outras.pick_random(), 2, false, fator)
			continue

		var dono = _proximo_dono()
		var maldita = boss.has_method("nota_maldita_disponivel") and boss.nota_maldita_disponivel() and randf() < chance_nota_maldita

		_criar_nota(coluna, dono, maldita, fator)

		if maldita:
			_criar_nota(outras.pick_random(), dono, false, fator)


## Sequência de 1 a 4 batidas com uma nota de cada jogador ao mesmo tempo
func _vem_notas_juntas() -> bool:
	if _ids_vivos().size() < 2:
		juntas_restantes = 0
		return false
	if juntas_restantes == 0 and randf() < chance_notas_juntas:
		juntas_restantes = randi_range(1, 4)
	if juntas_restantes > 0:
		juntas_restantes -= 1
		return true
	return false


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
	elif _em_dupla():
		nota.modulate = Color.WHITE.lerp(Jogo.cor(dono), 0.65)


# Quanto esperar para a próxima nota chegar à linha no tempo da música
func _tempo_ate_proxima_nota(fator := 1.0) -> float:
	var periodo = 60.0 / bpm
	var chegada = Audio.posicao_musica() + viagem_nota / fator - offset_batida
	var falta = periodo - fposmod(chegada, periodo)
	# Evita duas notas coladas quando o timer acorda logo antes da batida
	return falta + periodo if falta < 0.05 else falta


func _proximo_dono() -> int:
	var vivos = _ids_vivos()
	if vivos.size() <= 1:
		return vivos[0] if vivos.size() == 1 else 1

	notas_no_bloco += 1
	if notas_no_bloco > NOTAS_POR_BLOCO:
		notas_no_bloco = 1
		dono_bloco = 2 if dono_bloco == 1 else 1
	return dono_bloco


func _ids_vivos() -> Array:
	var ids = Jogo.jogadores_vivos().map(func(j): return j.id_jogador)
	ids.sort()
	return ids


func _em_dupla() -> bool:
	return Jogo.jogadores.size() >= 2


func _notas() -> Array:
	return notas_container.get_children().filter(func(n): return n.has_method("atualizar_seta"))


func _process(delta: float) -> void:
	if trava_restante > 0.0:
		trava_restante = maxf(trava_restante - delta, 0.0)

	if not tocando:
		return

	tempo_no_riff += delta
	# "!" piscando: o boss não está descansando, ele pode atacar a qualquer hora
	aviso.visible = boss != null and not boss.get("descansando")

	for jogador in Jogo.jogadores_vivos():
		for i in range(4):
			if Input.is_action_just_pressed(Controles.acao(jogador.id_jogador, TECLAS[i])):
				verificar_nota(i, jogador.id_jogador)

	_atualizar_vez()


func _atualizar_vez():
	if not _em_dupla():
		label_vez.hide()
		_mostrar_teclas_de(1)
		return

	# Mostra o dono da próxima nota a chegar na linha
	var proxima = null
	for nota in _notas():
		if not nota.acertada and (proxima == null or nota.position.y > proxima.position.y):
			proxima = nota

	if proxima == null:
		return

	_mostrar_teclas_de(proxima.dono)
	label_vez.text = "VEZ DO P%d" % proxima.dono
	label_vez.modulate = Jogo.cor(proxima.dono)
	label_vez.show()


## As teclas na linha de acerto: A W S D do P1 ou as setas do P2
func _mostrar_teclas_de(id_jogador: int) -> void:
	var texturas = INDICADORES_P1 if id_jogador == 1 else INDICADORES_SETAS
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


func verificar_nota(coluna, id_jogador := 1):
	var nota_maxima = null
	var menor_distancia = janela_good
	var tem_nota_propria = false

	for nota in _notas():
		if nota.dono != id_jogador or nota.acertada:
			continue

		tem_nota_propria = true

		if nota.coluna != coluna:
			continue

		var distancia = abs(nota.position.y - posicao_acerto)

		if distancia <= menor_distancia:
			menor_distancia = distancia
			nota_maxima = nota

	if nota_maxima == null:
		# Apertar fora da sua vez não conta como erro
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

	boss.receber_dano(dano)


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
