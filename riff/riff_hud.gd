extends Control
## Modo Riff: notas descem e o jogador acerta no ritmo para ferir o boss.
##
## Co-op (revezamento): as notas vêm em blocos de NOTAS_POR_BLOCO, alternando
## entre P1 e P2. Cada nota tem a cor do dono e só o dono pode acertá-la.
## Se só um jogador estiver de pé, todas as notas são dele.
##
## Nota maldita (se o boss permitir): vermelha, machuca quem tocar. Sempre
## vem com uma nota normal junto, para existir um acerto possível.
## Com o escudo do boss ativo, as notas não ferem.

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

@onready var notas_container = $NotasContainer
@onready var label_feedback = $LabelFeedback
@onready var label_vez = $LabelVez

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


func iniciar_riff():
	if tocando:
		return

	var modelo = cena_nota.instantiate()
	viagem_nota = (posicao_acerto + 30.0) / modelo.velocidade
	modelo.free()

	tocando = true
	geracao_id += 1
	notas_no_bloco = 0
	var vivos = _ids_vivos()
	dono_bloco = vivos[0] if not vivos.is_empty() else 1
	gerar_notas(geracao_id)


func parar_riff():
	tocando = false
	label_feedback.text = ""
	label_vez.hide()

	for nota in _notas():
		nota.queue_free()


func gerar_notas(id):
	while tocando and id == geracao_id:
		await get_tree().create_timer(_tempo_ate_proxima_nota()).timeout

		if not tocando or id != geracao_id:
			return

		var dono = _proximo_dono()
		var coluna = randi_range(0, 3)
		var maldita = boss.has_method("nota_maldita_disponivel") and boss.nota_maldita_disponivel() and randf() < chance_nota_maldita

		_criar_nota(coluna, dono, maldita)

		if maldita:
			var outras = [0, 1, 2, 3]
			outras.erase(coluna)
			_criar_nota(outras.pick_random(), dono, false)


func _criar_nota(coluna: int, dono: int, maldita: bool) -> void:
	var nota = cena_nota.instantiate()
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
func _tempo_ate_proxima_nota() -> float:
	var periodo = 60.0 / bpm
	var chegada = Audio.posicao_musica() + viagem_nota - offset_batida
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


func _process(_delta: float) -> void:
	if not tocando:
		return

	for jogador in Jogo.jogadores_vivos():
		for i in range(4):
			if Input.is_action_just_pressed(Controles.acao(jogador.id_jogador, TECLAS[i])):
				verificar_nota(i, jogador.id_jogador)

	_atualizar_vez()


func _atualizar_vez():
	if not _em_dupla():
		label_vez.hide()
		return

	# Mostra o dono da próxima nota a chegar na linha
	var proxima = null
	for nota in _notas():
		if not nota.acertada and (proxima == null or nota.position.y > proxima.position.y):
			proxima = nota

	if proxima == null:
		return

	label_vez.text = "VEZ DO P%d" % proxima.dono
	label_vez.modulate = Jogo.cor(proxima.dono)
	label_vez.show()


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
