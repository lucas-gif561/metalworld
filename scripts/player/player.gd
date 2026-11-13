extends CharacterBody2D
## Jogador (P1 ou P2). A mesma cena serve para os dois: muda só id_jogador.
##
## Quando a vida chega a zero o jogador fica CAÍDO (não some). O parceiro
## pode levantá-lo segurando "interagir" perto dele. Se todos caírem, o
## autoload Jogo emite game_over.

signal vida_alterada(atual, maxima)
signal morreu # o jogador caiu (vida chegou a zero)
signal revivido
signal stamina_alterada(atual, maxima)

const CAMADA_NORMAL = 1
const MASCARA_NORMAL = 3
const MASCARA_DODGE = 1 # Durante o dodge colide apenas com o cenário
const SHADER_TROCA_COR = preload("res://assets/shaders/troca_cor.gdshader")

@export var id_jogador := 1
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

@export_group("Reviver")
@export var raio_reviver = 90.0
@export var tempo_reviver = 2.0
@export var invencivel_ao_reviver = 2.0

@onready var timer_invencibilidade = $TimerInvencibilidade
@onready var timer_tiro = $TimerTiro
@onready var sprite = $AnimatedSprite2D

var vida_maxima = 0
var direcao_olhar = 1
var bloqueado = false
var invencivel = false
var em_acao = false
var caido = false
var tween_dano: Tween
var stamina = 0.0
var espera_stamina = 0.0
var esquivando = false
var tempo_dodge = 0.0
var direcao_dodge = Vector2.RIGHT
var escala_base = 2.5
var offset_base = Vector2.ZERO
var progresso_reviver = 0.0
var tempo_invencivel_padrao = 1.0
var _ajudado = false
var _anel: Node2D
var _indicador: Node2D
var _etiqueta: Label


func _ready():
	vida_maxima = vida
	stamina = stamina_maxima
	timer_tiro.wait_time = intervalo_tiro
	tempo_invencivel_padrao = timer_invencibilidade.wait_time
	sprite.animation_finished.connect(_ao_terminar_animacao)
	escala_base = abs(sprite.scale.y)
	offset_base = sprite.offset
	sprite.animation_changed.connect(_ajustar_visual)
	sprite.sprite_frames_changed.connect(_ajustar_visual)
	_ajustar_visual()
	_criar_identificacao()
	Jogo.registrar_jogador(self)


## Nome da ação deste jogador: acao("atirar") -> "p1_atirar" ou "p2_atirar"
func acao(nome: String) -> StringName:
	return Controles.acao(id_jogador, nome)


# Animações desenhadas em outro tamanho guardam escala e offset próprios no SpriteFrames
# (metadado "ajustes_animacao"), para o Dylan ter sempre a mesma altura na tela
func _ajustar_visual() -> void:
	var ajustes = sprite.sprite_frames.get_meta("ajustes_animacao", {})
	var ajuste = ajustes.get(String(sprite.animation), null)
	var escala = ajuste.escala if ajuste else escala_base
	var lado = -1.0 if sprite.scale.x < 0 else 1.0
	sprite.scale = Vector2(escala * lado, escala)
	sprite.offset = ajuste.offset if ajuste else offset_base


func _physics_process(delta):
	if caido:
		velocity = Vector2.ZERO
		if not _ajudado:
			progresso_reviver = max(progresso_reviver - delta, 0.0)
		_ajudado = false
		_indicador.queue_redraw()
		return

	if esquivando:
		_continuar_dodge(delta)
		return

	_recarregar_stamina(delta)

	if bloqueado:
		velocity = Vector2.ZERO
		_atualizar_animacao(Vector2.ZERO)
		return

	_tentar_reviver_parceiro(delta)

	# MOVIMENTAÇÃO
	var direcao = Input.get_vector(
		acao("mover_esquerda"),
		acao("mover_direita"),
		acao("mover_cima"),
		acao("mover_baixo")
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
	if Input.is_action_just_pressed(acao("dodge")) and stamina >= custo_dodge:
		_iniciar_dodge(direcao)
		return

	# ATAQUE
	if Input.is_action_pressed(acao("atirar")) and timer_tiro.is_stopped():
		atirar()
		timer_tiro.start()


func _process(_delta):
	_etiqueta.visible = Jogo.p2_ativo


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
	if not caido:
		em_acao = false


func atirar():
	if cena_projetil == null:
		return

	var projetil = cena_projetil.instantiate()
	projetil.direcao = direcao_olhar

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = global_position + Vector2(40 * direcao_olhar, 0)
	_tocar_acao(_animacao_ataque(velocity))


func receber_dano(dano):
	if caido or invencivel or esquivando or not timer_invencibilidade.is_stopped():
		return

	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)

	if vida <= 0:
		morrer()
	else:
		timer_invencibilidade.start(tempo_invencivel_padrao)
		_tocar_acao("hurt")
		_piscar()


func _piscar(vezes := 5):
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color(1, 0.4, 0.4)
	tween_dano = create_tween().set_loops(vezes)
	tween_dano.tween_property(sprite, "modulate", Color(1, 1, 1, 0.3), 0.1)
	tween_dano.tween_property(sprite, "modulate", Color.WHITE, 0.1)


## O jogador cai e espera o parceiro (ou o game over, se ninguém sobrar)
func morrer():
	vida = 0
	caido = true
	esquivando = false
	progresso_reviver = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0 # inimigos e balas passam por quem está caído
	collision_mask = MASCARA_DODGE
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color.WHITE
	_tocar_acao("death")
	_indicador.show()
	morreu.emit()


# ---------------------------------------------------------------- Reviver

func _tentar_reviver_parceiro(delta):
	if not Input.is_action_pressed(acao("interagir")):
		return

	for outro in Jogo.jogadores:
		if outro == self or not is_instance_valid(outro) or not outro.caido:
			continue
		if global_position.distance_to(outro.global_position) <= raio_reviver:
			outro.ajudar_a_levantar(delta)
			return


func ajudar_a_levantar(delta):
	if not caido:
		return
	_ajudado = true
	progresso_reviver += delta / tempo_reviver
	if progresso_reviver >= 1.0:
		reviver()


func reviver():
	caido = false
	em_acao = false
	progresso_reviver = 0.0
	vida = max(1, ceili(vida_maxima / 2.0))
	collision_layer = CAMADA_NORMAL
	collision_mask = MASCARA_NORMAL
	_indicador.hide()
	sprite.play("idle")
	vida_alterada.emit(vida, vida_maxima)
	timer_invencibilidade.start(invencivel_ao_reviver)
	_piscar(int(invencivel_ao_reviver / 0.2))
	revivido.emit()


# ---------------------------------------------------------------- Visual

func _criar_identificacao():
	var cor = Jogo.cor(id_jogador)

	if id_jogador == 2:
		var material = ShaderMaterial.new()
		material.shader = SHADER_TROCA_COR
		material.set_shader_parameter("cor_destaque", cor)
		sprite.material = material

	# Anel colorido no pé (fica atrás do sprite)
	_anel = Node2D.new()
	_anel.position = Vector2(0, 40)
	_anel.scale = Vector2(1.0, 0.35)
	_anel.draw.connect(func():
		_anel.draw_arc(Vector2.ZERO, 26.0, 0.0, TAU, 32, Color(cor, 0.85), 3.0)
	)
	add_child(_anel)
	move_child(_anel, 0)

	# "P1" / "P2" em cima da cabeça
	_etiqueta = Label.new()
	_etiqueta.text = "P%d" % id_jogador
	_etiqueta.position = Vector2(-20, -84)
	_etiqueta.size = Vector2(40, 20)
	_etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etiqueta.add_theme_color_override("font_color", cor)
	_etiqueta.add_theme_color_override("font_outline_color", Color.BLACK)
	_etiqueta.add_theme_constant_override("outline_size", 5)
	_etiqueta.add_theme_font_size_override("font_size", 16)
	add_child(_etiqueta)

	# Círculo de "segure para levantar" quando caído
	_indicador = Node2D.new()
	_indicador.z_index = 10
	_indicador.position = Vector2(0, -36)
	_indicador.draw.connect(_desenhar_indicador)
	_indicador.hide()
	add_child(_indicador)

	var texto = Label.new()
	texto.text = "SEGURE E / B"
	texto.position = Vector2(-60, 20)
	texto.size = Vector2(120, 20)
	texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	texto.add_theme_color_override("font_outline_color", Color.BLACK)
	texto.add_theme_constant_override("outline_size", 5)
	texto.add_theme_font_size_override("font_size", 14)
	_indicador.add_child(texto)


func _desenhar_indicador():
	var cor = Jogo.cor(id_jogador)
	_indicador.draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(0, 0, 0, 0.6), 5.0)
	if progresso_reviver > 0.0:
		_indicador.draw_arc(Vector2.ZERO, 16.0, -PI / 2, -PI / 2 + TAU * progresso_reviver, 32, cor, 5.0)
