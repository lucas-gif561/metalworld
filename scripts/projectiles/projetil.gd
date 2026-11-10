extends Area2D

@export var velocidade = 500.0
@export var alcance = 600.0
@export var dano = 1

var direcao = 1
var distancia = 0.0


func _ready():
	$Sprite2D.flip_h = direcao < 0
	body_entered.connect(_ao_atingir_corpo)


func _physics_process(delta):

	var movimento = velocidade * delta

	position.x += movimento * direcao
	distancia += movimento

	if distancia >= alcance:
		queue_free()


func _ao_atingir_corpo(corpo):

	if corpo.has_method("receber_dano"):
		corpo.receber_dano(dano)
		queue_free()
