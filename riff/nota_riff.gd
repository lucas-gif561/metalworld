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

@export var velocidade: float = 200.0

@onready var seta = $Seta

var coluna: int = 0
var maldita = false # nota vermelha: machuca quem tocar
var dono: int = 1 # jogador que deve acertar esta nota (revezamento)
var acertada = false


func _ready() -> void:
	atualizar_seta()


func atualizar_seta():
	seta.texture = (TECLAS_P1 if dono == 1 else SETAS)[coluna]


func _process(delta: float) -> void:
	position.y += velocidade * delta

	if position.y >= 290 and not acertada:
		acertada = true
		if not maldita:
			perdida.emit()
		queue_free()
