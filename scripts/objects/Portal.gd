extends Area2D

var player_nearby: bool = false
var ativado: bool = false

@onready var label_interacao = $LabelInteracao


func _ready():
	hide()
	monitoring = false
	label_interacao.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func ativar_portal():
	ativado = true
	show()
	monitoring = true


func _on_body_entered(body):
	if body.is_in_group("jogador") and ativado:
		player_nearby = true
		label_interacao.show()


func _on_body_exited(body):
	if body.is_in_group("jogador"):
		player_nearby = false
		label_interacao.hide()


func _process(_delta):
	if player_nearby and ativado:
		if Input.is_action_just_pressed("interagir"):
			entrar_portal()


func entrar_portal():
	get_tree().change_scene_to_file("res://scenes/main/Bossfight.tscn")
