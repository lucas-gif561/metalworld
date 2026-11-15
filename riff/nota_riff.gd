extends Control

signal perdida

# Ordem das pistas: ← ↑ ↓ →. O P2 toca nas setas; o P1, em A W S D.
const SETAS = [
	preload("res://riff/sprites/tecla_esquerda.png"),
	preload("res://riff/sprites/tecla_cima.png"),
	preload("res://riff/sprites/tecla_baixo.png"),
	preload("res://riff/sprites/tecla_direita.png"),
]
const TECLAS_P1 = [
	preload("res://riff/sprites/tecla_a.png"),
	preload("res://riff/sprites/tecla_w.png"),
	preload("res://riff/sprites/tecla_s.png"),
	preload("res://riff/sprites/tecla_d.png"),
]
# No controle (qualquer jogador): gatilhos e botões superiores, LT LB RB RT
const BOTOES_CONTROLE = [
	preload("res://riff/sprites/botao_lt.svg"),
	preload("res://riff/sprites/botao_lb.svg"),
	preload("res://riff/sprites/botao_rb.svg"),
	preload("res://riff/sprites/botao_rt.svg"),
]

@export var velocidade: float = 200.0

@onready var seta = $Seta

var coluna: int = 0
var maldita = false # nota vermelha: machuca quem tocar
var dono: int = 1 # jogador que deve acertar esta nota
var acertada = false


func _ready() -> void:
	# Mesmo dispositivo das pistas (riff_hud.gd): troca até no meio da queda
	Controles.dispositivo_mudou.connect(_ao_mudar_dispositivo)
	atualizar_seta()


func _ao_mudar_dispositivo(id_jogador: int) -> void:
	if id_jogador == dono:
		atualizar_seta()


func atualizar_seta():
	if Controles.usa_controle(dono):
		seta.texture = BOTOES_CONTROLE[coluna]
	else:
		seta.texture = (TECLAS_P1 if dono == 1 else SETAS)[coluna]


func _process(delta: float) -> void:
	position.y += velocidade * delta

	if position.y >= 290 and not acertada:
		acertada = true
		if not maldita:
			perdida.emit()
		queue_free()
