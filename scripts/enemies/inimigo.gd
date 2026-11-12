extends CharacterBody2D

# Só alguns inimigos atacam por vez; os outros rodeiam o Dylan esperando a vez
const MAXIMO_ATACANTES = 2
const RAIO_ESPERA = 300.0
const DESACELERACAO_EMPURRAO = 2400.0
static var atacantes: Array = []

@export var velocidade = 100.0
@export var vida = 3
@export var distancia_ataque = 144.0
@export var dano = 1
@export var tempo_preparo = 0.4
@export var resistencia_empurrao = 1.0
@export var ataques_por_vez = 2
@export var item_ao_morrer: PackedScene
@onready var jogador = get_tree().get_first_node_in_group("jogador")
@onready var timer_ataque = $TimerAtaque
@onready var sprite = $AnimatedSprite2D

var morto = false
var em_acao = false
var empurrao := Vector2.ZERO
var atordoado_ate_ms := 0
var preparando := false
var preparo_id := 0
var ataques_feitos := 0
var proxima_vez_ms := 0
var angulo_espera := 0.0
var esperando := false


func _ready():
	add_to_group("alvos_golpe")
	angulo_espera = randf() * TAU
	sprite.animation_finished.connect(_ao_terminar_animacao)


func _exit_tree():
	atacantes.erase(self)


func _physics_process(delta):
	if jogador == null or morto:
		return

	if _processar_empurrao(delta) or _processar_atordoamento():
		return

	if jogador.vida <= 0:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	if preparando:
		velocity = Vector2.ZERO
		return

	var diferenca = jogador.global_position - global_position

	if _tem_vez():
		if abs(diferenca.y) <= 44 and abs(diferenca.x) <= distancia_ataque:
			velocity = Vector2.ZERO

			if timer_ataque.is_stopped():
				_preparar_ataque()
				return
		else:
			# Vai para o lado do Dylan, na mesma faixa da rua
			var lado = -1.0 if diferenca.x > 0 else 1.0
			_mover_para(jogador.global_position + Vector2(lado * distancia_ataque * 0.85, 0))
	else:
		_esperar_vez(delta)

	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()


# FILA DE ATAQUE

func _tem_vez() -> bool:
	atacantes = atacantes.filter(func(e): return is_instance_valid(e) and not e.morto and e.is_inside_tree())

	if self in atacantes:
		return true

	if Time.get_ticks_msec() < proxima_vez_ms or atacantes.size() >= MAXIMO_ATACANTES:
		return false

	atacantes.append(self)
	ataques_feitos = 0
	esperando = false
	return true


func _liberar_vez(espera: float) -> void:
	atacantes.erase(self)
	proxima_vez_ms = Time.get_ticks_msec() + int(espera * 1000.0)


func _esperar_vez(delta) -> void:
	var ate_jogador = global_position - jogador.global_position

	# Orbita a partir do lado onde já está, sem cruzar por cima do Dylan
	if not esperando:
		esperando = true
		angulo_espera = ate_jogador.angle()

	angulo_espera += delta * 0.3
	var alvo = jogador.global_position + Vector2.from_angle(angulo_espera) * Vector2(RAIO_ESPERA, RAIO_ESPERA * 0.6)
	alvo = _dentro_da_arena(alvo)

	if global_position.distance_to(alvo) <= 40.0:
		velocity = Vector2.ZERO
		return

	var direcao = global_position.direction_to(alvo)

	if ate_jogador.length() < RAIO_ESPERA * 0.6:
		direcao = (direcao + ate_jogador.normalized() * 1.5).normalized()

	velocity = direcao * velocidade


func _mover_para(alvo: Vector2) -> void:
	velocity = global_position.direction_to(alvo) * velocidade


func _dentro_da_arena(ponto: Vector2) -> Vector2:
	var cena = get_tree().current_scene

	if cena and cena.has_method("limites_arena"):
		var limites = cena.limites_arena()
		return ponto.clamp(limites.position, limites.end)

	return ponto


# AVISO ANTES DO GOLPE

func _preparar_ataque():
	preparando = true
	preparo_id += 1
	var id = preparo_id
	velocity = Vector2.ZERO
	_olhar_para_jogador()
	_tocar_acao("attack")
	sprite.pause()
	sprite.modulate = Color(1.8, 1.8, 1.8)

	await get_tree().create_timer(tempo_preparo).timeout

	if id != preparo_id or morto or not is_inside_tree():
		return

	preparando = false
	sprite.modulate = Color.WHITE
	sprite.play()
	timer_ataque.start()

	# Só acerta se o Dylan continuar perto e na mesma faixa
	var diferenca = jogador.global_position - global_position

	# Golpe mirado no Dylan: se ele acabou de esquivar, vale esquiva perfeita
	if abs(diferenca.x) <= distancia_ataque * 2.5 and abs(diferenca.y) <= 120:
		jogador.tentar_esquiva_perfeita()

	if abs(diferenca.x) <= distancia_ataque * 1.25 and abs(diferenca.y) <= 60:
		jogador.receber_dano(dano)

	ataques_feitos += 1

	if ataques_feitos >= ataques_por_vez:
		_liberar_vez(1.5)


func _cancelar_preparo() -> void:
	if preparando:
		preparando = false
		sprite.modulate = Color.WHITE
	preparo_id += 1


# EMPURRÃO E ATORDOAMENTO

func empurrar(forca: Vector2) -> void:
	empurrao = forca * resistencia_empurrao
	_cancelar_preparo()


func _processar_empurrao(delta) -> bool:
	if empurrao.length_squared() < 100.0:
		empurrao = Vector2.ZERO
		return false

	velocity = empurrao
	move_and_slide()
	empurrao = empurrao.move_toward(Vector2.ZERO, DESACELERACAO_EMPURRAO * delta)
	return true


func atordoar(segundos: float) -> void:
	if morto:
		return

	atordoado_ate_ms = Time.get_ticks_msec() + int(segundos * 1000.0)
	_cancelar_preparo()
	sprite.modulate = Color(1, 1, 0.5)


func _processar_atordoamento() -> bool:
	if atordoado_ate_ms == 0:
		return false

	if Time.get_ticks_msec() < atordoado_ate_ms:
		velocity = Vector2.ZERO
		sprite.play("hurt")
		return true

	atordoado_ate_ms = 0
	sprite.modulate = Color.WHITE
	return false


# ANIMAÇÃO

func _olhar_para_jogador():
	var lado = -1.0 if jogador.global_position.x < global_position.x else 1.0
	sprite.scale.x = abs(sprite.scale.x) * lado


func _atualizar_animacao():
	if em_acao:
		return
	sprite.play("walk" if velocity != Vector2.ZERO else "idle")


func _tocar_acao(nome):
	em_acao = true
	sprite.stop()
	sprite.play(nome)


func _ao_terminar_animacao():
	if not morto:
		em_acao = false


# DANO E MORTE

func receber_dano(valor):
	if morto:
		return

	vida -= valor
	_cancelar_preparo()

	if vida <= 0:
		morrer()
	else:
		Audio.tocar("dano_inimigo")
		_tocar_acao("hurt")
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func morrer():
	morto = true
	velocity = Vector2.ZERO
	atacantes.erase(self)
	_cancelar_preparo()
	atordoado_ate_ms = 0
	sprite.modulate = Color.WHITE
	$CollisionShape2D.set_deferred("disabled", true)
	Audio.tocar("morte_inimigo")
	_tocar_acao("death")

	# Golpe final arremessa o corpo
	if empurrao.length() > 50.0:
		var tween = create_tween()
		tween.tween_property(self, "position", position + Vector2(empurrao.x * 0.25, 0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		var pulo = create_tween()
		pulo.tween_property(sprite, "position:y", -60.0, 0.15).set_ease(Tween.EASE_OUT)
		pulo.tween_property(sprite, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)

	if item_ao_morrer:
		var item = item_ao_morrer.instantiate()
		item.position = position
		get_parent().add_child.call_deferred(item)

	await sprite.animation_finished
	queue_free()
