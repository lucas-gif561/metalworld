extends CharacterBody2D

signal vida_alterada(atual, maxima)
signal morreu
signal stamina_alterada(atual, maxima)
signal dano_sofrido(valor)

const CAMADA_NORMAL = 1
const MASCARA_NORMAL = 3
const MASCARA_DODGE = 1 # Durante o dodge colide apenas com o cenário

@export var velocidade = 200.0
@export var cena_projetil: PackedScene
@export var intervalo_tiro = 0.3
@export var vida = 5

@export_group("Dodge")
@export var velocidade_dodge = 520.0
@export var duracao_dodge = 0.35

@export_group("Stamina")
@export var stamina_maxima = 100.0
@export var custo_dodge = 33.0
@export var recarga_stamina = 25.0
@export var espera_recarga = 0.5

@onready var timer_invencibilidade = $TimerInvencibilidade
@onready var timer_tiro = $TimerTiro
@onready var sprite = $AnimatedSprite2D

var vida_maxima = 0
var direcao_olhar = 1
var bloqueado = false
var invencivel = false
var em_acao = false
var tween_dano: Tween
var stamina = 0.0
var espera_stamina = 0.0
var esquivando = false
var tempo_dodge = 0.0
var direcao_dodge = Vector2.RIGHT


func _ready():
	vida_maxima = vida
	stamina = stamina_maxima
	timer_tiro.wait_time = intervalo_tiro
	sprite.animation_finished.connect(_ao_terminar_animacao)


func _physics_process(delta):
	if vida <= 0:
		velocity = Vector2.ZERO
		return

	if esquivando:
		_continuar_dodge(delta)
		return

	_recarregar_stamina(delta)

	if bloqueado:
		velocity = Vector2.ZERO
		_atualizar_animacao(Vector2.ZERO)
		return

	# MOVIMENTAÇÃO
	var direcao = Input.get_vector(
		"mover_esquerda",
		"mover_direita",
		"mover_cima",
		"mover_baixo"
	)
	velocity = direcao * velocidade
	move_and_slide()

	# DIREÇÃO DO PERSONAGEM
	if direcao.x > 0:
		direcao_olhar = 1
	elif direcao.x < 0:
		direcao_olhar = -1
	sprite.scale.x = abs(sprite.scale.x) * direcao_olhar

	_atualizar_animacao(direcao)

	# DODGE
	if Input.is_action_just_pressed("dodge") and stamina >= custo_dodge:
		_iniciar_dodge(direcao)
		return

	# ATAQUE
	if Input.is_action_pressed("atirar") and timer_tiro.is_stopped():
		atirar()
		timer_tiro.start()


func _iniciar_dodge(direcao):
	esquivando = true
	tempo_dodge = duracao_dodge
	direcao_dodge = direcao.normalized() if direcao != Vector2.ZERO else Vector2(direcao_olhar, 0)
	stamina -= custo_dodge
	espera_stamina = espera_recarga
	stamina_alterada.emit(stamina, stamina_maxima)

	# Sem camada, balas e inimigos não detectam o jogador
	collision_layer = 0
	collision_mask = MASCARA_DODGE
	Audio.tocar("dodge")
	_tocar_acao("dodge")


func _continuar_dodge(delta):
	velocity = direcao_dodge * velocidade_dodge
	move_and_slide()
	tempo_dodge -= delta

	if tempo_dodge <= 0.0:
		esquivando = false
		em_acao = false
		collision_layer = CAMADA_NORMAL
		collision_mask = MASCARA_NORMAL


func _recarregar_stamina(delta):
	if espera_stamina > 0.0:
		espera_stamina -= delta
		return

	if stamina < stamina_maxima:
		stamina = min(stamina + recarga_stamina * delta, stamina_maxima)
		stamina_alterada.emit(stamina, stamina_maxima)


func _atualizar_animacao(direcao):
	if em_acao:
		_sincronizar_ataque(direcao)
		return
	sprite.play("run" if direcao != Vector2.ZERO else "idle")


# Troca entre ataque parado e correndo sem reiniciar o golpe
func _sincronizar_ataque(direcao):
	if sprite.animation != &"attack" and sprite.animation != &"run_attack":
		return

	var animacao = _animacao_ataque(direcao)

	if sprite.animation != animacao:
		var quadro = sprite.frame
		var progresso = sprite.frame_progress
		sprite.play(animacao)
		sprite.set_frame_and_progress(quadro, progresso)


func _animacao_ataque(direcao) -> StringName:
	return &"run_attack" if direcao != Vector2.ZERO else &"attack"


func _tocar_acao(nome):
	em_acao = true
	sprite.stop()
	sprite.play(nome)


func _ao_terminar_animacao():
	if vida > 0:
		em_acao = false


func atirar():
	if cena_projetil == null:
		return

	var projetil = cena_projetil.instantiate()
	projetil.direcao = direcao_olhar

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = global_position + Vector2(40 * direcao_olhar, 0)
	_tocar_acao(_animacao_ataque(velocity))
	Audio.tocar("tiro_dylan")


func receber_dano(dano):
	if vida <= 0 or invencivel or esquivando or not timer_invencibilidade.is_stopped():
		return

	var vida_antes = vida
	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	dano_sofrido.emit(vida_antes - vida)

	if vida <= 0:
		morrer()
	else:
		timer_invencibilidade.start()
		Audio.tocar("dano_dylan")
		_tocar_acao("hurt")
		_piscar()


func curar(valor):
	if vida <= 0:
		return

	vida = min(vida + valor, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)


func _piscar():
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color(1, 0.4, 0.4)
	tween_dano = create_tween().set_loops(5)
	tween_dano.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.1)
	tween_dano.tween_property(sprite, "modulate", Color.WHITE, 0.1)


func morrer():
	vida = 0
	velocity = Vector2.ZERO
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color.WHITE
	Audio.tocar("morte_dylan", 0.0)
	_tocar_acao("death")
	morreu.emit()
