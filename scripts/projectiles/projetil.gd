extends Area2D

@export var velocidade = 500.0
@export var alcance = 600.0
@export var dano = 1
@export var empurrao = 440.0
@export var carga_solo = 5.0

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
		# Empurra antes do dano: se for o golpe final, o corpo é arremessado
		if corpo.has_method("empurrar"):
			corpo.empurrar(Vector2(direcao * empurrao, 0))
		corpo.receber_dano(dano)

		if corpo.is_in_group("alvos_golpe"):
			Combate.registrar_acerto(carga_solo)

		queue_free()
