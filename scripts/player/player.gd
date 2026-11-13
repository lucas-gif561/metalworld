extends CharacterBody2D
## Jogador (P1 ou P2). A mesma cena serve para os dois: muda só id_jogador.
##
## Ataque: socos alternados (esquerdo, direito...). O jogador para para bater
## e o dano sai no quadro do impacto, em quem estiver à frente e na mesma
## faixa da rua. Apertar durante o soco guarda o próximo golpe.
##
## Quando a vida chega a zero o jogador fica CAÍDO (não some). O parceiro
## pode levantá-lo segurando "interagir" perto dele. Se todos caírem, o
## autoload Jogo emite game_over.

signal vida_alterada(atual, maxima)
signal morreu # o jogador caiu (vida chegou a zero)
signal revivido
signal dano_sofrido(valor) # quanto de vida perdeu num golpe
signal stamina_alterada(atual, maxima)

const CAMADA_NORMAL = 1
const MASCARA_NORMAL = 3
const MASCARA_DODGE = 1 # Durante o dodge colide apenas com o cenário
const SHADER_TROCA_COR = preload("res://assets/shaders/troca_cor.gdshader")

# Socos alternados. quadro = quadro do impacto (quando o dano sai)
const SOCOS = [
	{"animacao": &"soco_esquerdo", "quadro": 1, "dano": 1, "empurrao": 260.0, "tremor": 0.0},
	{"animacao": &"soco_direito", "quadro": 3, "dano": 2, "empurrao": 520.0, "tremor": 3.0},
]

@export var id_jogador := 1
## Velocidade no tamanho normal (boss). Acompanha o tamanho do personagem:
## nas ruas (1,5x) vira 249, e ele anda sempre ~2 corpos por segundo
@export var velocidade = 166.0
@export var vida = 5

@export_group("Soco")
## Até onde o soco alcança à frente do corpo (px)
@export var alcance_soco = 80.0
## Diferença de altura aceita: só acerta quem está na mesma faixa da rua
@export var faixa_soco = 34.0
## Depois disso sem bater, a sequência volta para o soco esquerdo
@export var tempo_sequencia = 0.6

@export_group("Dodge")
## Velocidade no tamanho normal (boss). Acompanha o tamanho do personagem:
## nas ruas (1,5x) fica 1,5x mais rápida, e o dodge sempre cobre ~1,5 corpo
@export var velocidade_dodge = 350.0
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
var progresso_reviver = 0.0
var tempo_invencivel_padrao = 1.0
var _ajudado = false
var escala_personagem = 1.0 # 1,5 nas ruas (ver Jogo.escala_da_fase)
var em_riff = false # tocando guitarra no modo Riff (a arena liga/desliga)
var proximo_soco = 0
var soco_atual = -1
var soco_guardado = false
var fim_sequencia_ms = 0
@onready var _anel = $Anel
@onready var _indicador = $IndicadorReviver
@onready var _etiqueta = $Etiqueta


func _ready():
	vida_maxima = vida
	stamina = stamina_maxima
	tempo_invencivel_padrao = timer_invencibilidade.wait_time
	sprite.animation_finished.connect(_ao_terminar_animacao)
	sprite.frame_changed.connect(_ao_mudar_quadro)
	_configurar_identificacao()
	Jogo.registrar_jogador(self)
	aplicar_escala.call_deferred(Jogo.escala_da_fase())


## Muda o tamanho do personagem (sprite, colisão, alcance do soco e marcadores).
## Fica em código porque a MESMA cena do jogador é usada na rua (1,5x) e no
## boss (1x). O tamanho normal (boss) é o que está gravado no player.tscn.
func aplicar_escala(fator: float) -> void:
	if is_equal_approx(fator, escala_personagem):
		return
	var razao = fator / escala_personagem
	escala_personagem = fator
	Jogo.escalar_colisao($CollisionShape2D, razao)
	_anel.position *= razao
	_anel.scale *= razao
	_etiqueta.position.y *= razao
	_indicador.position *= razao
	alcance_soco *= razao
	velocidade_dodge *= razao
	velocidade *= razao
	faixa_soco *= razao
	raio_reviver *= razao
	sprite.scale *= razao


## Nome da ação deste jogador: acao("atacar") -> "p1_atacar" ou "p2_atacar"
func acao(nome: String) -> StringName:
	return Controles.acao(id_jogador, nome)


func _physics_process(delta):
	if caido:
		velocity = Vector2.ZERO
		if not _ajudado:
			progresso_reviver = max(progresso_reviver - delta, 0.0)
		_ajudado = false
		_indicador.progresso = progresso_reviver
		return

	if esquivando:
		_continuar_dodge(delta)
		return

	_recarregar_stamina(delta)

	if bloqueado:
		velocity = Vector2.ZERO
		if em_riff:
			_animar_riff()
		else:
			_atualizar_animacao(Vector2.ZERO)
		return

	_tentar_reviver_parceiro(delta)

	var direcao = Input.get_vector(
		acao("mover_esquerda"),
		acao("mover_direita"),
		acao("mover_cima"),
		acao("mover_baixo")
	)

	# DODGE (cancela o soco)
	if Input.is_action_just_pressed(acao("dodge")) and stamina >= custo_dodge:
		_cancelar_soco()
		_iniciar_dodge(direcao)
		return

	# SOCO: apertar durante um golpe guarda o próximo
	if Input.is_action_just_pressed(acao("atacar")):
		if _socando():
			soco_guardado = true
		elif not em_acao:
			_virar_para(direcao.x)
			_socar()

	if _socando():
		velocity = Vector2.ZERO # para para bater
		return

	# MOVIMENTAÇÃO
	velocity = direcao * velocidade
	move_and_slide()
	_virar_para(direcao.x)
	_atualizar_animacao(direcao)


func _process(_delta):
	_etiqueta.visible = Jogo.p2_ativo and not caido


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


func _virar_para(x: float):
	if x > 0:
		direcao_olhar = 1
	elif x < 0:
		direcao_olhar = -1
	sprite.scale.x = abs(sprite.scale.x) * direcao_olhar


func _atualizar_animacao(direcao):
	if em_acao:
		return
	sprite.play("run" if direcao != Vector2.ZERO else "idle")


# ---------------------------------------------------------------- Soco

func _socando() -> bool:
	return soco_atual >= 0


func _socar():
	if Time.get_ticks_msec() > fim_sequencia_ms:
		proximo_soco = 0
	soco_atual = proximo_soco
	proximo_soco = (proximo_soco + 1) % SOCOS.size()
	soco_guardado = false
	Audio.tocar("dodge", 0.15)
	_tocar_acao(SOCOS[soco_atual].animacao)


func _cancelar_soco():
	soco_atual = -1
	soco_guardado = false


func _ao_mudar_quadro():
	if not _socando():
		return
	var golpe = SOCOS[soco_atual]
	if sprite.animation == golpe.animacao and sprite.frame == golpe.quadro:
		_aplicar_soco(golpe)


## Acerta quem estiver à frente, dentro do alcance e na mesma faixa da rua
func _aplicar_soco(golpe: Dictionary):
	var acertou = false

	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not is_instance_valid(alvo) or alvo.get("morto"):
			continue

		var distancia = alvo.global_position - global_position
		var frente = distancia.x * direcao_olhar

		if frente >= -10.0 and frente <= alcance_soco and abs(distancia.y) <= faixa_soco:
			if alvo.has_method("empurrar"):
				alvo.empurrar(Vector2(direcao_olhar * golpe.empurrao, 0))
			alvo.receber_dano(golpe.dano)
			acertou = true

	if acertou and golpe.tremor > 0.0:
		Combate.tremer(golpe.tremor)


# ---------------------------------------------------------------- Riff

func _animar_riff():
	if sprite.animation != &"riff_inicio" and sprite.animation != &"riff":
		_cancelar_soco()
		em_acao = false
		sprite.play("riff_inicio")


func _tocar_acao(nome):
	em_acao = true
	sprite.stop()
	sprite.play(nome)


func _ao_terminar_animacao():
	if caido:
		return

	if sprite.animation == &"riff_inicio":
		sprite.play("riff" if em_riff else "idle")
		return

	em_acao = false

	if _socando() and sprite.animation == SOCOS[soco_atual].animacao:
		fim_sequencia_ms = Time.get_ticks_msec() + int(tempo_sequencia * 1000.0)
		var emendar = soco_guardado
		_cancelar_soco()
		if emendar:
			_socar()


func receber_dano(dano):
	if caido or invencivel or esquivando or not timer_invencibilidade.is_stopped():
		return

	_cancelar_soco()

	var vida_antes = vida
	vida = max(vida - dano, 0)
	vida_alterada.emit(vida, vida_maxima)
	dano_sofrido.emit(vida_antes - vida)

	if vida <= 0:
		if not caido:
			morrer()
	else:
		Audio.tocar("dano_dylan")
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


func curar(valor):
	if caido:
		return
	vida = min(vida + valor, vida_maxima)
	vida_alterada.emit(vida, vida_maxima)


## Usado pela vida compartilhada do boss: iguala a vida deste jogador à da dupla
func sincronizar_vida(nova_vida: int, nova_maxima: int) -> void:
	vida_maxima = nova_maxima
	vida = clampi(nova_vida, 0, nova_maxima)
	vida_alterada.emit(vida, vida_maxima)
	if vida <= 0 and not caido:
		morrer()


## O jogador cai e espera o parceiro (ou o game over, se ninguém sobrar)
func morrer():
	vida = 0
	caido = true
	em_riff = false
	_cancelar_soco()
	esquivando = false
	progresso_reviver = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0 # inimigos e balas passam por quem está caído
	collision_mask = MASCARA_DODGE
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color.WHITE
	Audio.tocar("morte_dylan", 0.0)
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
	_tocar_acao("levantar")
	vida_alterada.emit(vida, vida_maxima)
	timer_invencibilidade.start(invencivel_ao_reviver)
	_piscar(int(invencivel_ao_reviver / 0.2))
	revivido.emit()


# ---------------------------------------------------------------- Visual

## Cores do P1/P2 nos marcadores da cena (Anel, Etiqueta, IndicadorReviver).
## A cor do P2 fica em código porque P1 e P2 usam a mesma cena.
func _configurar_identificacao():
	var cor = Jogo.cor(id_jogador)

	if id_jogador == 2:
		var material = ShaderMaterial.new()
		material.shader = SHADER_TROCA_COR
		material.set_shader_parameter("cor_destaque", cor)
		sprite.material = material

	_anel.cor = Color(cor, 0.85)
	_etiqueta.text = "P%d" % id_jogador
	_etiqueta.add_theme_color_override("font_color", cor)
	_indicador.cor = cor
	_indicador.hide()
