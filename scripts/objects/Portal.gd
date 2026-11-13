extends Area2D
## Portal do fim da rua: qualquer jogador perto aperta "interagir"
## e todos vão para a próxima fase da sequência (Jogo.FASES).

var ativado: bool = false
var jogadores_perto: Array = []

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
	if body.is_in_group("jogador") and ativado and not body in jogadores_perto:
		jogadores_perto.append(body)
		label_interacao.show()


func _on_body_exited(body):
	jogadores_perto.erase(body)
	if jogadores_perto.is_empty():
		label_interacao.hide()


func _process(_delta):
	if not ativado:
		return

	for jogador in jogadores_perto:
		if is_instance_valid(jogador) and not jogador.caido and Input.is_action_just_pressed(jogador.acao("interagir")):
			entrar_portal()
			return


func entrar_portal():
	ativado = false
	Audio.tocar("portal", 0.0)
	Jogo.proxima_fase()
