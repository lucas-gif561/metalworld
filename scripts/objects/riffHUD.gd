extends Control

@export var cena_nota: PackedScene
@export var bpm: float = 120.0
@export var boss: Node2D

@onready var notas_container = $NotasContainer
@onready var label_feedback = $LabelFeedback

const COR_PERFECT = Color(0.35, 0.9, 1.0)
const COR_GOOD = Color(0.5, 1.0, 0.5)
const COR_MISS = Color(1.0, 0.3, 0.3)

var tocando = false
var posicao_acerto: float = 260.0
var janela_perfect: float = 12.0
var janela_good: float = 30.0
var geracao_id: int = 0
var tween_feedback: Tween


func iniciar_riff():
	if tocando:
		return

	tocando = true
	geracao_id += 1
	gerar_notas(geracao_id)


func parar_riff():
	tocando = false
	label_feedback.text = ""

	for nota in notas_container.get_children():
		if nota.has_method("atualizar_seta"):
			nota.queue_free()


func gerar_notas(id):
	while tocando and id == geracao_id:
		var nota = cena_nota.instantiate()
		notas_container.add_child(nota)

		var coluna = randi_range(0, 3)

		nota.coluna = coluna
		nota.atualizar_seta()
		nota.position = Vector2(coluna * 61 + 13, -30)
		nota.perdida.connect(_mostrar_feedback.bind("MISS", COR_MISS))

		await get_tree().create_timer(60.0 / bpm).timeout


func _process(_delta: float) -> void:
	if not tocando:
		return

	var teclas = [
		"riff_cima",
		"riff_baixo",
		"riff_esquerda",
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
		_mostrar_feedback("MISS", COR_MISS)
		return

	nota_maxima.acertada = true

	if menor_distancia <= janela_perfect:
		_mostrar_feedback("PERFECT!", COR_PERFECT)
		boss.receber_dano(3)
	else:
		_mostrar_feedback("GOOD", COR_GOOD)
		boss.receber_dano(1)

	nota_maxima.queue_free()


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
