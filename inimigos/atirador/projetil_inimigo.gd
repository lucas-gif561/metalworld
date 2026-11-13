extends Area2D

@export var velocidade = 350.0
@export var alcance = 550.0
@export var dano = 2

var direcao = 1
var distancia = 0.0


func _ready():
	$Sprite2D.flip_h = direcao < 0
	area_entered.connect(atingir)


func _physics_process(delta):
	var movimento = velocidade * delta

	position.x += movimento * direcao
	distancia += movimento

	if distancia >= alcance:
		queue_free()


# Acerta a Hurtbox (corpo) do jogador, na altura do peito: só pega quem está na faixa
func atingir(area):
	if area.is_in_group("hurtbox_jogador"):
		area.get_parent().receber_dano(dano)
		queue_free()
