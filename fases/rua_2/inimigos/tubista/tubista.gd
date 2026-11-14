extends Inimigo

const BOLA_DEMONIACA = preload("res://fases/rua_2/inimigos/tubista/bola_demoniaca.tscn")

@export var alcance_ataque = 370.0
@onready var saida_tuba: Marker2D = $SaidaTuba


func _comportamento(_delta):
	_olhar_para_jogador()
	if global_position.distance_to(jogador.global_position) <= alcance_ataque:
		velocity = Vector2.ZERO
		if timer_ataque.is_stopped():
			carregar_ataque(_assoprar_tuba)
			return
	else:
		var destino = _dentro_da_arena(jogador.global_position)
		velocity = global_position.direction_to(destino) * velocidade
	_atualizar_animacao()
	move_and_slide()


func _assoprar_tuba() -> void:
	var alvo = Jogo.jogador_mais_proximo(global_position)
	if alvo == null:
		return
	var deslocamento = Vector2(saida_tuba.position.x * lado_carga, saida_tuba.position.y)
	var origem = global_position + deslocamento * escala_personagem
	var bola = BOLA_DEMONIACA.instantiate()
	bola.dano = dano
	bola.eixo = origem.direction_to(alvo.posicao_do_corpo())
	if bola.eixo == Vector2.ZERO:
		bola.eixo = Vector2(lado_carga, 0)
	get_tree().current_scene.add_child(bola)
	bola.global_position = origem
	Audio.tocar("tiro_inimigo", 0.0)
