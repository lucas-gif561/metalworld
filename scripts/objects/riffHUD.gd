extends Control

@export var cena_nota: PackedScene
@export var bpm: float = 150.0
@export var offset_batida: float = 0.516
@export var boss: Node2D

@onready var notas_container = $NotasContainer
@onready var label_feedback = $LabelFeedback

const COR_PERFECT = Color(0.35, 0.9, 1.0)
const COR_GOOD = Color(0.5, 1.0, 0.5)
const COR_MISS = Color(1.0, 0.3, 0.3)
const COR_DESAFINO = Color(0.75, 0.5, 1.0)
const COR_MALDITA = Color(1.0, 0.15, 0.15)
const COR_ESCUDO = Color(0.5, 0.8, 1.0)

@export var chance_nota_maldita: float = 0.15

var viagem_nota: float = 0.0
var modo_desafino = ""
var desafino_id: int = 0
var tocando = false
var posicao_acerto: float = 260.0
var janela_perfect: float = 12.0
var janela_good: float = 30.0
var geracao_id: int = 0
var tween_feedback: Tween


func iniciar_riff():
	if tocando:
		return

	var modelo = cena_nota.instantiate()
	viagem_nota = (posicao_acerto + 30.0) / modelo.velocidade
	modelo.free()

	tocando = true
	geracao_id += 1
	gerar_notas(geracao_id)


func parar_riff():
	tocando = false
	desafino_id += 1
	modo_desafino = ""
	label_feedback.text = ""

	for nota in notas_container.get_children():
		if nota.has_method("atualizar_seta"):
			nota.queue_free()


func gerar_notas(id):
	while tocando and id == geracao_id:
		await get_tree().create_timer(_tempo_ate_proxima_nota()).timeout

		if not tocando or id != geracao_id:
			return

		var coluna = randi_range(0, 3)
		var pista = _escolher_pista(coluna, -1)
		var maldita = boss.nota_maldita_disponivel() and randf() < chance_nota_maldita

		_criar_nota(coluna, pista, maldita)

		if maldita:
			# A nota vermelha sempre vem com uma normal, para garantir um acerto possível
			var outras_teclas = [0, 1, 2, 3]
			outras_teclas.erase(coluna)
			var coluna_par = outras_teclas.pick_random()
			_criar_nota(coluna_par, _escolher_pista(coluna_par, pista), false)


func _escolher_pista(coluna: int, pista_ocupada: int) -> int:
	if modo_desafino != "trocadas":
		return coluna

	# A seta continua indicando a tecla, mas desce em outra pista
	var pistas = [0, 1, 2, 3]
	pistas.erase(coluna)
	pistas.erase(pista_ocupada)
	return pistas.pick_random()


func _criar_nota(coluna: int, pista: int, maldita: bool) -> void:
	var nota = cena_nota.instantiate()
	notas_container.add_child(nota)

	if modo_desafino != "":
		nota.modulate = COR_DESAFINO

	if modo_desafino == "rapidas":
		nota.velocidade *= 1.5

	if maldita:
		nota.maldita = true
		nota.modulate = COR_MALDITA

	nota.coluna = coluna
	nota.atualizar_seta()
	nota.position = Vector2(pista * 61 + 13, -30)
	nota.perdida.connect(_registrar_miss)


# Calcula quanto esperar para a nota chegar à linha exatamente no tempo da música
func _tempo_ate_proxima_nota() -> float:
	var periodo = 60.0 / bpm
	var chegada = Audio.posicao_musica() + viagem_nota - offset_batida
	var falta = periodo - fposmod(chegada, periodo)

	# Evita duas notas coladas quando o timer acorda logo antes da batida
	return falta + periodo if falta < 0.05 else falta


func _process(_delta: float) -> void:
	if not tocando:
		return

	var teclas = [
		"riff_esquerda",
		"riff_cima",
		"riff_baixo",
		"riff_direita"
	]

	for i in range(4):
		if Input.is_action_just_pressed(teclas[i]):
			verificar_nota(i)


func verificar_nota(coluna):
	var nota_maxima = null
	var menor_distancia = janela_good

	for nota in notas_container.get_children():
		if not nota is Control or not nota.has_method("atualizar_seta"):
			continue

		if nota.coluna != coluna or nota.acertada:
			continue

		var distancia = abs(nota.position.y - posicao_acerto)

		if distancia <= menor_distancia:
			menor_distancia = distancia
			nota_maxima = nota

	if nota_maxima == null:
		_registrar_miss()
		return

	nota_maxima.acertada = true

	if nota_maxima.maldita:
		Audio.tocar("nota_maldita")
		_mostrar_feedback("MALDITA!", COR_MALDITA)
		boss.jogador.receber_dano(1)
		nota_maxima.queue_free()
		return

	if boss.escudo_ativo:
		Audio.tocar("escudo", 0.0)
		_mostrar_feedback("ESCUDO", COR_ESCUDO)
		nota_maxima.queue_free()
		return

	if menor_distancia <= janela_perfect:
		Audio.tocar("nota_perfect", 0.0)
		_mostrar_feedback("PERFECT!", COR_PERFECT)
		boss.receber_dano(boss.dano_da_nota(true))
	else:
		Audio.tocar("nota_good", 0.0)
		_mostrar_feedback("GOOD", COR_GOOD)
		boss.receber_dano(boss.dano_da_nota(false))

	nota_maxima.queue_free()


func _registrar_miss():
	Audio.tocar("nota_miss")
	_mostrar_feedback("MISS", COR_MISS)
	boss.punir_miss()


func desafinar(duracao: float):
	if not tocando:
		return

	desafino_id += 1
	var id = desafino_id
	modo_desafino = ["trocadas", "rapidas"].pick_random()
	Audio.tocar("teleporte")
	_mostrar_feedback("DESAFINADO!", COR_DESAFINO)

	await get_tree().create_timer(duracao).timeout

	if id == desafino_id:
		modo_desafino = ""


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
