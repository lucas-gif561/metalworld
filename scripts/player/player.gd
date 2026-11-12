extends CharacterBody2D

signal vida_alterada(atual, maxima)
signal morreu
signal stamina_alterada(atual, maxima)
signal dano_sofrido(valor)
signal arma_trocada(nome)
signal esquiva_perfeita

const CAMADA_NORMAL = 1
const MASCARA_NORMAL = 3
const MASCARA_DODGE = 1 # Durante o dodge colide apenas com o cenário

# Soco, soco e chute. Se o sprite tiver golpe1/golpe2/golpe3 elas são usadas;
# senão o ataque da guitarra gira por código.
const GOLPES = [
	{"animacao": &"golpe1", "dano": 1, "alcance": 150.0, "empurrao": 520.0, "pausa": 0.04, "duracao": 0.24, "giro": -0.5, "tremor": 0.0},
	{"animacao": &"golpe2", "dano": 1, "alcance": 150.0, "empurrao": 520.0, "pausa": 0.04, "duracao": 0.24, "giro": 0.6, "tremor": 0.0},
	{"animacao": &"golpe3", "dano": 2, "alcance": 180.0, "empurrao": 1120.0, "pausa": 0.09, "duracao": 0.34, "giro": -1.2, "tremor": 8.0},
]
const JANELA_COMBO_MS = 350
const DURACAO_ESPECIAL = 0.45
const MOMENTO_ESPECIAL = 0.18

@export var velocidade = 200.0
@export var cena_projetil: PackedScene
@export var intervalo_tiro = 0.3
@export var vida = 5
# Multiplica tamanho, colisão, alcances e saída dos tiros (o boss usa 0,5)
@export var escala_personagem = 1.0

@export_group("Dodge")
@export var velocidade_dodge = 520.0
@export var duracao_dodge = 0.35

@export_group("Stamina")
@export var stamina_maxima = 100.0
@export var custo_dodge = 33.0
@export var recarga_stamina = 25.0
@export var espera_recarga = 0.5

@export_group("Esquiva perfeita")
@export var usar_esquiva_perfeita := true
@export var janela_esquiva_perfeita = 0.2
@export var duracao_camera_lenta = 1.5

@export_group("Metralhadora")
@export var frames_metralhadora: SpriteFrames
@export var intervalo_metralhadora = 0.1
@export var dano_metralhadora = 0.5
@export var empurrao_metralhadora = 180.0
@export var espalhamento_metralhadora = 14.0
@export var lentidao_metralhadora = 0.75
@export var cena_disparo: PackedScene

@export_group("Corpo a corpo")
@export var avanco_golpe = 280.0
@export var faixa_golpe = 64.0
@export var custo_especial = 50.0
@export var raio_especial = 280.0
@export var cena_rastro: PackedScene
@export var cena_onda: PackedScene

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
var golpeando = false
var etapa_golpe = 0
var proxima_etapa = 0
var golpe_pedido = false
var golpe_aplicado = false
var tempo_golpe = 0.0
var cadeia_ate_ms = 0
var tween_golpe: Tween
var no_especial = false
var arma = "guitarra"
var escala_base = 2.5
var offset_base = Vector2.ZERO
var inicio_dodge_ms = 0
var esquiva_perfeita_usada = false
var proximo_rastro_ms = 0
var frames_guitarra: SpriteFrames
var tempo_especial = 0.0
var especial_aplicado = false


func _ready():
	vida_maxima = vida
	stamina = stamina_maxima
	frames_guitarra = sprite.sprite_frames
	timer_tiro.wait_time = intervalo_tiro
	sprite.animation_finished.connect(_ao_terminar_animacao)
	_aplicar_escala_personagem()
	escala_base = abs(sprite.scale.y)
	offset_base = sprite.offset
	sprite.animation_changed.connect(_ajustar_visual)
	sprite.sprite_frames_changed.connect(_ajustar_visual)
	_ajustar_visual()


func _aplicar_escala_personagem() -> void:
	var k = escala_personagem

	if is_equal_approx(k, 1.0):
		return

	sprite.scale *= k
	var colisao = $CollisionShape2D
	colisao.shape = colisao.shape.duplicate()
	colisao.shape.size *= k
	var sombra = get_node_or_null("Sombra")

	if sombra:
		sombra.position *= k
		sombra.tamanho *= k

	avanco_golpe *= k
	faixa_golpe *= k
	raio_especial *= k
	espalhamento_metralhadora *= k
	empurrao_metralhadora *= k


# Animações desenhadas em outro tamanho guardam escala e offset próprios no SpriteFrames
# (metadado "ajustes_animacao"), para o Dylan ter sempre a mesma altura na tela
func _ajustar_visual() -> void:
	var ajustes = sprite.sprite_frames.get_meta("ajustes_animacao", {})
	var ajuste = ajustes.get(String(sprite.animation), null)
	var escala = ajuste.escala * escala_personagem if ajuste else escala_base
	var lado = -1.0 if sprite.scale.x < 0 else 1.0
	sprite.scale = Vector2(escala * lado, escala)
	sprite.offset = ajuste.offset if ajuste else offset_base


func _physics_process(delta):
	if vida <= 0:
		velocity = Vector2.ZERO
		return

	if Combate.em_camera_lenta() and Time.get_ticks_msec() >= proximo_rastro_ms:
		proximo_rastro_ms = Time.get_ticks_msec() + 60
		_criar_rastro()

	if esquivando:
		_continuar_dodge(delta)
		return

	_recarregar_stamina(delta)

	if bloqueado:
		velocity = Vector2.ZERO
		_atualizar_animacao(Vector2.ZERO)
		return

	if golpeando:
		_continuar_golpe(delta)
		return

	if no_especial:
		_continuar_especial(delta)
		return

	# MOVIMENTAÇÃO
	var direcao = Input.get_vector(
		"mover_esquerda",
		"mover_direita",
		"mover_cima",
		"mover_baixo"
	)
	# Segurar a metralhadora disparando deixa o Dylan mais pesado
	var fator = lentidao_metralhadora if arma == "metralhadora" and Input.is_action_pressed("atirar") else 1.0
	velocity = direcao * velocidade * fator
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

	# TROCA DE ARMA
	if Input.is_action_just_pressed("trocar_arma"):
		trocar_arma()

	# CORPO A CORPO
	if Input.is_action_just_pressed("golpe"):
		var etapa = proxima_etapa if Time.get_ticks_msec() <= cadeia_ate_ms else 0
		_iniciar_golpe(etapa)
		return

	if Input.is_action_just_pressed("especial") and stamina >= custo_especial:
		_iniciar_especial()
		return

	# ATAQUE
	if Input.is_action_pressed("atirar") and timer_tiro.is_stopped():
		atirar()
		timer_tiro.start()


func _iniciar_dodge(direcao):
	esquivando = true
	inicio_dodge_ms = Time.get_ticks_msec()
	esquiva_perfeita_usada = false
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


# COMBO CORPO A CORPO

func _iniciar_golpe(etapa: int):
	golpeando = true
	etapa_golpe = etapa
	tempo_golpe = 0.0
	golpe_aplicado = false
	golpe_pedido = false
	var golpe = GOLPES[etapa]

	if tween_golpe:
		tween_golpe.kill()
	sprite.rotation = 0.0

	if sprite.sprite_frames.has_animation(golpe.animacao):
		_tocar_acao(golpe.animacao)
	else:
		_tocar_acao("attack")
		tween_golpe = create_tween()
		tween_golpe.tween_property(sprite, "rotation", golpe.giro * direcao_olhar, golpe.duracao * 0.4)
		tween_golpe.tween_property(sprite, "rotation", 0.0, golpe.duracao * 0.6)

	Audio.tocar("dodge", 0.15)


func _continuar_golpe(delta):
	tempo_golpe += delta
	var golpe = GOLPES[etapa_golpe]

	# Avança um pouco no começo do golpe
	var avanco = maxf(avanco_golpe * (1.0 - tempo_golpe / golpe.duracao), 0.0)
	velocity = Vector2(direcao_olhar * avanco, 0)
	move_and_slide()

	if Input.is_action_just_pressed("golpe"):
		golpe_pedido = true

	# O dodge cancela o golpe a qualquer momento
	if Input.is_action_just_pressed("dodge") and stamina >= custo_dodge:
		_encerrar_golpe()
		_iniciar_dodge(Input.get_vector("mover_esquerda", "mover_direita", "mover_cima", "mover_baixo"))
		return

	if not golpe_aplicado and tempo_golpe >= golpe.duracao * 0.45:
		golpe_aplicado = true
		_aplicar_golpe(golpe)

	if tempo_golpe >= golpe.duracao:
		_encerrar_golpe()
		var ultima = etapa_golpe >= GOLPES.size() - 1

		if golpe_pedido and not ultima:
			_iniciar_golpe(etapa_golpe + 1)
		else:
			proxima_etapa = 0 if ultima else etapa_golpe + 1
			cadeia_ate_ms = Time.get_ticks_msec() + JANELA_COMBO_MS


func _encerrar_golpe():
	golpeando = false
	em_acao = false

	if tween_golpe:
		tween_golpe.kill()
	sprite.rotation = 0.0


func _aplicar_golpe(golpe):
	_criar_efeito(cena_rastro, global_position + Vector2(direcao_olhar * 100.0, -12.0) * escala_personagem, 0.0 if direcao_olhar > 0 else PI)
	var acertos = 0

	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not is_instance_valid(alvo) or alvo.get("morto"):
			continue

		# Só acerta na frente e na mesma faixa da rua
		var distancia = alvo.global_position - global_position
		var frente = distancia.x * direcao_olhar

		if frente >= -10.0 and frente <= golpe.alcance * escala_personagem and abs(distancia.y) <= faixa_golpe:
			if alvo.has_method("empurrar"):
				alvo.empurrar(Vector2(direcao_olhar * golpe.empurrao * escala_personagem, 0))
			alvo.receber_dano(golpe.dano)
			Combate.registrar_acerto(10.0)
			acertos += 1

	if acertos > 0:
		Combate.pausar(golpe.pausa)

		if golpe.tremor > 0.0:
			Combate.tremer(golpe.tremor)


# GOLPE ESPECIAL: onda que empurra tudo em volta

func _iniciar_especial():
	no_especial = true
	tempo_especial = 0.0
	especial_aplicado = false
	stamina -= custo_especial
	espera_stamina = espera_recarga
	stamina_alterada.emit(stamina, stamina_maxima)
	_tocar_acao(&"especial" if sprite.sprite_frames.has_animation(&"especial") else &"dodge")


func _continuar_especial(delta):
	velocity = Vector2.ZERO
	move_and_slide()
	tempo_especial += delta

	if not especial_aplicado and tempo_especial >= MOMENTO_ESPECIAL:
		especial_aplicado = true
		_aplicar_especial()

	if tempo_especial >= DURACAO_ESPECIAL:
		no_especial = false
		em_acao = false


func _aplicar_especial():
	_criar_efeito(cena_onda, global_position, 0.0)
	Audio.tocar("escudo", 0.0)
	Combate.tremer(10.0)
	Combate.pausar(0.06)

	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not is_instance_valid(alvo) or alvo.get("morto"):
			continue

		var distancia = alvo.global_position - global_position

		if abs(distancia.x) <= raio_especial and abs(distancia.y) <= raio_especial * 0.5:
			if alvo.has_method("empurrar"):
				var direcao = distancia.normalized() if distancia != Vector2.ZERO else Vector2(direcao_olhar, 0)
				alvo.empurrar(direcao * 1240.0 * escala_personagem)
			alvo.receber_dano(1)
			Combate.registrar_acerto(10.0)


func _criar_efeito(cena: PackedScene, posicao: Vector2, rotacao: float):
	if cena == null:
		return

	var efeito = cena.instantiate()
	efeito.position = posicao
	efeito.rotation = rotacao
	efeito.finished.connect(efeito.queue_free)
	get_tree().current_scene.add_child(efeito)


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


func trocar_arma():
	arma = "guitarra" if arma == "metralhadora" else "metralhadora"
	timer_tiro.wait_time = intervalo_metralhadora if arma == "metralhadora" else intervalo_tiro
	var novos = frames_metralhadora if arma == "metralhadora" else frames_guitarra

	if novos != null and novos != sprite.sprite_frames:
		var animacao = sprite.animation
		var quadro = sprite.frame
		sprite.sprite_frames = novos

		if novos.has_animation(animacao):
			sprite.play(animacao)
			sprite.frame = mini(quadro, novos.get_frame_count(animacao) - 1)
		else:
			em_acao = false
			sprite.play("idle")

	Audio.tocar("ui_confirma", 0.0)
	arma_trocada.emit(arma)


func atirar():
	if cena_projetil == null:
		return

	var projetil = cena_projetil.instantiate()
	projetil.direcao = direcao_olhar
	var saida = Vector2(80 * direcao_olhar, 0) * escala_personagem

	if arma == "metralhadora":
		saida = Vector2(84 * direcao_olhar, -10) * escala_personagem + Vector2(0, randf_range(-espalhamento_metralhadora, espalhamento_metralhadora))
		projetil.dano = dano_metralhadora
		projetil.empurrao = empurrao_metralhadora
		projetil.carga_solo = 2.5
		projetil.get_node("Sprite2D").scale = Vector2(1.4, 1.4)
		_disparo_metralhadora()

	get_tree().current_scene.add_child(projetil)

	projetil.global_position = global_position + saida

	# Na rajada a animação segue sem reiniciar a cada bala
	var ja_atirando = em_acao and (sprite.animation == &"attack" or sprite.animation == &"run_attack")

	if not (arma == "metralhadora" and ja_atirando):
		_tocar_acao(_animacao_ataque(velocity))

	Audio.tocar("tiro_dylan", 0.12 if arma == "metralhadora" else 0.05)


func _disparo_metralhadora():
	if cena_disparo == null:
		return

	var efeito = cena_disparo.instantiate()
	efeito.position = global_position + Vector2(88 * direcao_olhar, -10) * escala_personagem
	efeito.scale.x = direcao_olhar
	efeito.finished.connect(efeito.queue_free)
	get_tree().current_scene.add_child(efeito)


# ESQUIVA PERFEITA: dodge no último instante deixa o tempo lento

func tentar_esquiva_perfeita() -> bool:
	if not usar_esquiva_perfeita or not esquivando or esquiva_perfeita_usada or vida <= 0:
		return false

	if Time.get_ticks_msec() - inicio_dodge_ms > int(janela_esquiva_perfeita * 1000.0):
		return false

	esquiva_perfeita_usada = true
	Combate.camera_lenta(duracao_camera_lenta)
	Combate.tremer(4.0)
	Combate.registrar_acerto(15.0)
	Audio.tocar("nota_perfect", 0.0)

	# O dodge sai de graça
	stamina = minf(stamina + custo_dodge, stamina_maxima)
	stamina_alterada.emit(stamina, stamina_maxima)
	esquiva_perfeita.emit()
	return true


func _criar_rastro():
	var textura = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)

	if textura == null:
		return

	var rastro = Sprite2D.new()
	rastro.texture = textura
	rastro.global_position = sprite.global_position
	rastro.scale = sprite.scale
	rastro.offset = sprite.offset
	rastro.rotation = sprite.rotation
	rastro.modulate = Color(0.7, 0.4, 1.0, 0.55)
	rastro.z_index = -1
	get_tree().current_scene.add_child(rastro)

	var tween = rastro.create_tween().set_ignore_time_scale(true)
	tween.tween_property(rastro, "modulate:a", 0.0, 0.35)
	tween.tween_callback(rastro.queue_free)


func receber_dano(dano):
	tentar_esquiva_perfeita()

	if vida <= 0 or invencivel or esquivando or no_especial or not timer_invencibilidade.is_stopped():
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
