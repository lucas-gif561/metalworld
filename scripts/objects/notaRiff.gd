extends Control

signal perdida

# Ordem das pistas: ← ↑ ↓ →
const SETAS = [
	preload("res://assets/sprites/ui/tecla_esquerda.png"),
	preload("res://assets/sprites/ui/tecla_cima.png"),
	preload("res://assets/sprites/ui/tecla_baixo.png"),
	preload("res://assets/sprites/ui/tecla_direita.png"),
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
	seta.texture = SETAS[coluna]


func _process(delta: float) -> void:
	position.y += velocidade * delta

	if position.y >= 290 and not acertada:
		acertada = true
		if not maldita:
			perdida.emit()
		queue_free()
