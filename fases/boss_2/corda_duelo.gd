extends Area2D
## A faixa avisa primeiro e causa dano só no instante do pulso.
## O Fio é a corda do violino: treme de leve no aviso e vibra forte no pulso.

@export var dano: int = 1

@export_group("Vibração do fio")
## Comprimento do fio (a largura da faixa)
@export var comprimento: float = 792.0
## Quanto o fio balança enquanto avisa e no instante do pulso (px)
@export var amplitude_aviso: float = 2.5
@export var amplitude_pulso: float = 16.0
## Velocidade da vibração (oscilações por segundo × 2π)
@export var frequencia: float = 38.0
## Espessura do fio no aviso e no pulso
@export var largura_aviso: float = 2.0
@export var largura_pulso: float = 7.0

const PONTOS_DO_FIO = 41

@onready var aviso: Panel = $Aviso
@onready var pulso: Panel = $Pulso
@onready var fio: Line2D = $Fio

var _amplitude := 0.0
var _tempo := 0.0


func avisar() -> void:
	aviso.show()
	pulso.hide()
	# A espessura e o balanço mudam conforme o estado da corda, por isso ficam no código
	fio.width = largura_aviso
	_amplitude = amplitude_aviso
	show()


func pulsar() -> void:
	aviso.hide()
	pulso.show()
	fio.width = largura_pulso
	_amplitude = amplitude_pulso
	for corpo in get_overlapping_bodies():
		if corpo.is_in_group("jogador"):
			corpo.receber_dano(dano)


func _process(delta: float) -> void:
	if not visible:
		return
	_tempo += delta
	if pulso.visible:
		# A corda tangida perde força até voltar ao tremor do aviso
		_amplitude = move_toward(_amplitude, amplitude_aviso, amplitude_pulso * 3.0 * delta)
	var meio = comprimento * 0.5
	var pontos := PackedVector2Array()
	for i in PONTOS_DO_FIO:
		var fracao = float(i) / (PONTOS_DO_FIO - 1)
		# Pontas presas e barriga no meio, como uma corda de verdade
		var y = sin(fracao * PI) * sin(_tempo * frequencia) * _amplitude
		pontos.append(Vector2(lerpf(-meio, meio, fracao), y))
	fio.points = pontos
