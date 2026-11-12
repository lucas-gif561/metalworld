extends Area2D

@export var velocidade = 350.0
@export var alcance = 550.0
@export var dano = 2

var direcao = 1
var distancia = 0.0


func _ready():
	$Sprite2D.flip_h = direcao < 0
	body_entered.connect(atingir)


func _physics_process(delta):
	var movimento = velocidade * delta

	position.x += movimento * direcao
	distancia += movimento
	Combate.ameaca_perto(global_position, 90.0)

	if distancia >= alcance:
		queue_free()


func atingir(corpo):
	if corpo.is_in_group("jogador"):
		corpo.receber_dano(dano)
		queue_free()
