extends Node

# Sensação de impacto compartilhada: pausa no acerto, câmera lenta, tremor e aviso de acerto
signal acerto(carga_solo)
signal camera_lenta_mudou(ativa)

const ESCALA_PAUSA = 0.05
const ESCALA_LENTA = 0.35

var fim_pausa_ms := 0
var fim_lento_ms := 0
var lento_ativo := false
var tween_tremor: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Congela o jogo por um instante; pausas sobrepostas valem até a mais longa
func pausar(segundos: float) -> void:
	if segundos <= 0.0:
		return

	fim_pausa_ms = maxi(fim_pausa_ms, Time.get_ticks_msec() + int(segundos * 1000.0))
	_aplicar_escala()


# Duração em segundos reais; a pausa do impacto continua funcionando por cima
func camera_lenta(segundos: float) -> void:
	fim_lento_ms = maxi(fim_lento_ms, Time.get_ticks_msec() + int(segundos * 1000.0))
	_aplicar_escala()


func em_camera_lenta() -> bool:
	return Time.get_ticks_msec() < fim_lento_ms


# Confere pelo relógio real a cada quadro; timers comuns ficam lentos durante a pausa
func _process(_delta: float) -> void:
	_aplicar_escala()


func _aplicar_escala() -> void:
	var agora = Time.get_ticks_msec()
	var escala = 1.0

	if agora < fim_pausa_ms:
		escala = ESCALA_PAUSA
	elif agora < fim_lento_ms:
		escala = ESCALA_LENTA

	if not is_equal_approx(Engine.time_scale, escala):
		Engine.time_scale = escala

	var lento = agora < fim_lento_ms

	if lento != lento_ativo:
		lento_ativo = lento
		Audio.definir_lentidao(lento)
		camera_lenta_mudou.emit(lento)


func tremer(forca: float, duracao: float = 0.2) -> void:
	var camera = get_viewport().get_camera_2d()

	if camera == null:
		return

	if tween_tremor and tween_tremor.is_valid():
		tween_tremor.kill()

	# Preso à câmera: se a cena trocar, o tremor some junto
	tween_tremor = camera.create_tween().set_ignore_time_scale(true)
	var passos = maxi(int(duracao / 0.04), 2)

	for i in range(passos):
		var f = forca * (1.0 - float(i) / passos)
		tween_tremor.tween_property(camera, "offset", Vector2(randf_range(-f, f), randf_range(-f, f)), 0.04)

	tween_tremor.tween_property(camera, "offset", Vector2.ZERO, 0.04)


# Ataques e balas avisam quando passam raspando no Dylan durante o dodge
func ameaca_perto(posicao: Vector2, raio: float) -> void:
	var jogador = get_tree().get_first_node_in_group("jogador")

	if jogador and jogador.has_method("tentar_esquiva_perfeita") and jogador.esquivando:
		if jogador.global_position.distance_to(posicao) <= raio:
			jogador.tentar_esquiva_perfeita()


func registrar_acerto(carga_solo: float) -> void:
	acerto.emit(carga_solo)
