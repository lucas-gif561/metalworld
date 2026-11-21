extends CharacterBody2D
## Jogador (P1 ou P2). A mesma cena serve para os dois: muda só id_jogador.
##
## Profundidade de beat 'em up: a ORIGEM do nó fica nos pés. A colisão física
## (CollisionShape2D) é só uma faixa no chão, então dá para passar na frente ou
## atrás de outros objetos. Tiros acertam a Hurtbox (corpo), que fica na
## altura do peito: só pega quem está na mesma faixa da rua.
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
signal esquiva_iniciada
signal dano_sofrido(valor) # quanto de vida perdeu num golpe
signal poder_alterado(atual, maxima)

const ONDA_MINIRRIFF = preload("res://personagens/dylan/onda_minirriff.tscn")
const ARCO_MINIRRIFF = preload("res://personagens/dylan/arco_minirriff.tscn")
const RAIO_ENCADEADO = preload("res://personagens/dylan/harmonico.tscn")
## "impacto" é o dano do minirriff no miniboss, pelo custo: 1 -> 2, 2 -> 3,
## 3 -> 4 (o barato rende mais por poder). A postura sai dele como no soco:
## impacto x postura_por_dano (18). Nos outros inimigos vale o "dano".
const MINIRRIFFS = {
	"ABAB": {"nome": "Onda sonora", "custo": 1.0, "dano": 1, "impacto": 2, "raio": 180.0, "atordoamento": 1.5},
	"BABA": {"nome": "Acorde cortante", "custo": 3.0, "dano": 4, "impacto": 4},
	"BBAB": {"nome": "Raio Encadeado", "custo": 2.0, "dano": 1, "impacto": 3, "cena": RAIO_ENCADEADO},
}

const CAMADA_NORMAL = 1
const MASCARA_NORMAL = 3
const MASCARA_DODGE = 1 # Durante o dodge colide apenas com o cenário
# Combo de três golpes. O quadro do cross depende da animação do personagem.
const SOCOS = [
	{"animacao": &"soco_esquerdo", "quadro": 1, "dano": 1, "empurrao": 0.0, "tremor": 0.0},
	{"animacao": &"soco_direito", "dano": 1, "empurrao": 0.0, "tremor": 3.0},
	{"animacao": &"chute", "quadro": 4, "dano": 1, "empurrao": 620.0, "tremor": 4.0},
]

@export var id_jogador := 1
## Rosto mostrado no painel de vida do HUD
@export var retrato: Texture2D
## Velocidade no tamanho normal (boss). Acompanha o tamanho do personagem:
## nas ruas (1,5x) vira 249, e ele anda sempre ~2 corpos por segundo
@export var velocidade = 166.0
@export var vida = 5
@export var animar_entrada_no_riff := true

@export_group("Soco")
## Até onde o soco alcança à frente do corpo (px)
@export var alcance_soco = 80.0
## Diferença de altura aceita: só acerta quem está na mesma faixa da rua
@export var faixa_soco = 34.0
## Depois disso sem bater, a sequência volta para o soco esquerdo
@export var tempo_sequencia = 0.6
@export var quadro_cross: int = 3

@export_group("Dodge")
## Velocidade no tamanho normal (boss). Acompanha o tamanho do personagem:
## nas ruas (1,5x) fica 1,5x mais rápida, e o dodge sempre cobre ~1,5 corpo
@export var velocidade_dodge = 350.0
@export var duracao_dodge = 0.35

@export var recarga_dodge = 1.5

@export_group("Poder")
@export var poder_maximo = 3.0
@export var recarga_poder = 0.12
@export var poder_por_acerto = 0.22
@export var poder_por_dano = 0.35
@export var janela_minirriff = 3.5
@export var atordoamento_minirriff = 0.5

@export_group("Reviver")
@export var raio_reviver = 90.0
@export var tempo_reviver = 2.0
@export var invencivel_ao_reviver = 2.0

@onready var timer_invencibilidade = $TimerInvencibilidade
@onready var sprite = $AnimatedSprite2D

var vida_maxima = 0
var direcao_olhar = 1
var bloqueado = false
## Entrando na partida: corre sozinho da borda da tela até destino_entrada
var entrando = false
var destino_entrada := Vector2.ZERO
var invencivel = false
var em_acao = false
var caido = false
var tween_dano: Tween
var poder = 0.0
var recarga_dodge_restante = 0.0
var sequencia_minirriff := ""
## A sequência como ficou na última nota (a sequência é limpa no mesmo quadro
## em que acerta ou erra; o VisorMinirriff usa esta para mostrar o resultado)
var ultima_sequencia_minirriff := ""
var minirriff_usando_controle := false
var tempo_minirriff = 0.0
var tempo_atordoado = 0.0
var mensagem_minirriff := ""
var tempo_mensagem_minirriff = 0.0
var _especial_pendente := {}
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
@onready var _visor_minirriff = $VisorMinirriff
@onready var hurtbox = $Hurtbox


func _ready():
	vida_maxima = vida
	poder = poder_maximo
	tempo_invencivel_padrao = timer_invencibilidade.wait_time
	sprite.animation_finished.connect(_ao_terminar_animacao)
	sprite.frame_changed.connect(_ao_mudar_quadro)
	_configurar_identificacao()
	minirriff_usando_controle = Controles.usa_controle(id_jogador)
	Jogo.registrar_jogador(self)
	aplicar_escala.call_deferred(Jogo.escala_da_fase())


## Muda o tamanho do personagem (sprite, colisão, alcance do soco e marcadores).
## Fica em código porque a MESMA cena do jogador é usada na rua (1,5x) e no
## boss (1x). O tamanho normal (boss) é o que está gravado no jogador.tscn.
func aplicar_escala(fator: float) -> void:
	if is_equal_approx(fator, escala_personagem):
		return
	var razao = fator / escala_personagem
	escala_personagem = fator
	Jogo.escalar_colisao($CollisionShape2D, razao)
	Jogo.escalar_colisao($Hurtbox/CollisionShape2D, razao)
	_anel.position *= razao
	_anel.scale *= razao
	_indicador.position *= razao
	_visor_minirriff.position *= razao
	_visor_minirriff.scale *= razao
	alcance_soco *= razao
	velocidade_dodge *= razao
	velocidade *= razao
	faixa_soco *= razao
	raio_reviver *= razao
	sprite.scale *= razao
	sprite.position *= razao


## Centro do corpo (a origem do jogador fica nos pés). Use para mirar tiros nele.
func posicao_do_corpo() -> Vector2:
	return $Hurtbox/CollisionShape2D.global_position


## Liga/desliga a área onde tiros acertam (desligada no dodge e caído)
func _hurtbox_ativa(ativa: bool) -> void:
	hurtbox.set_deferred("monitorable", ativa)


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

	_alterar_poder(recarga_poder * delta)
	recarga_dodge_restante = maxf(recarga_dodge_restante - delta, 0.0)
	_anel.progresso = 1.0 - recarga_dodge_restante / recarga_dodge if recarga_dodge > 0.0 else 1.0
	if _atualizar_minirriff(delta):
		velocity = Vector2.ZERO
		return

	if esquivando:
		_continuar_dodge(delta)
		return

	if entrando:
		_correr_para_entrada()
		return

	if bloqueado and not em_riff:
		velocity = Vector2.ZERO
		_atualizar_animacao(Vector2.ZERO)
		return

	if not em_riff:
		_tentar_reviver_parceiro(delta)

	var direcao = Input.get_vector(
		acao("mover_esquerda"),
		acao("mover_direita"),
		acao("mover_cima"),
		acao("mover_baixo")
	)

	# DODGE (cancela o soco)
	if Input.is_action_just_pressed(acao("dodge")) and recarga_dodge_restante <= 0.0:
		_cancelar_soco()
		_iniciar_dodge(direcao)
		return

	if bloqueado:
		velocity = Vector2.ZERO
		_animar_riff()
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


## P2 entrando no meio da fase: nasce fora da tela e corre até o destino.
## Atravessa paredes e inimigos no caminho (sem colisão até chegar).
func entrar_correndo(destino: Vector2) -> void:
	entrando = true
	destino_entrada = destino
	collision_mask = 0
	_hurtbox_ativa(false)


func _correr_para_entrada() -> void:
	var falta = destino_entrada - global_position
	if falta.length() < 10.0:
		entrando = false
		velocity = Vector2.ZERO
		collision_mask = MASCARA_NORMAL
		_hurtbox_ativa(true)
		return
	velocity = falta.normalized() * velocidade * 1.5
	move_and_slide()
	_virar_para(falta.x)
	_atualizar_animacao(falta)


func _iniciar_dodge(direcao):
	esquivando = true
	tempo_dodge = duracao_dodge
	direcao_dodge = direcao.normalized() if direcao != Vector2.ZERO else Vector2(direcao_olhar, 0)
	recarga_dodge_restante = recarga_dodge

	# Sem camada e sem hurtbox, balas e inimigos passam pelo jogador
	collision_layer = 0
	collision_mask = MASCARA_DODGE
	_hurtbox_ativa(false)
	Audio.tocar("dodge")
	_tocar_acao("dodge")
	esquiva_iniciada.emit()


func _continuar_dodge(delta):
	velocity = direcao_dodge * velocidade_dodge
	move_and_slide()
	tempo_dodge -= delta

	if tempo_dodge <= 0.0:
		_encerrar_dodge()


func _encerrar_dodge() -> void:
	esquivando = false
	em_acao = false
	collision_layer = CAMADA_NORMAL
	collision_mask = MASCARA_NORMAL
	_hurtbox_ativa(true)


func _alterar_poder(valor: float) -> void:
	var novo = clampf(poder + valor, 0.0, poder_maximo)
	if novo != poder:
		poder = novo
		poder_alterado.emit(poder, poder_maximo)


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
	if sprite.animation == golpe.animacao and sprite.frame == golpe.get("quadro", quadro_cross):
		_aplicar_soco(golpe)


## Acerta quem estiver à frente, dentro do alcance e na mesma faixa da rua
func _aplicar_soco(golpe: Dictionary):
	var acertou = false
	var acertou_inimigo = false

	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not is_instance_valid(alvo) or alvo.get("morto"):
			continue

		var distancia = alvo.global_position - global_position
		var frente = distancia.x * direcao_olhar

		if frente >= -10.0 and frente <= alcance_soco and abs(distancia.y) <= faixa_soco:
			if golpe.empurrao > 0.0 and alvo.has_method("empurrar"):
				alvo.empurrar(Vector2(direcao_olhar * golpe.empurrao, 0))
			# Quem trata soco diferente de outros danos (o miniboss) tem receber_golpe
			if alvo.has_method("receber_golpe"):
				alvo.receber_golpe(golpe.dano)
			else:
				alvo.receber_dano(golpe.dano)
			acertou = true
			acertou_inimigo = acertou_inimigo or alvo.is_in_group("inimigos")

	if acertou_inimigo and usa_minirriff():
		_alterar_poder(poder_por_acerto)
	if acertou and golpe.tremor > 0.0:
		Combate.tremer(golpe.tremor)


# ---------------------------------------------------------------- Minirriff

func usa_minirriff() -> bool:
	var fase = get_tree().current_scene
	return fase != null and fase.has_node("Spawns") and fase.has_node("Portal")


func _input(evento: InputEvent) -> void:
	if caido or entrando or bloqueado or esquivando or tempo_atordoado > 0.0:
		return
	if not _especial_pendente.is_empty() or not usa_minirriff():
		return
	if evento is InputEventJoypadButton and evento.device != Controles.controle_do_jogador(id_jogador):
		return

	var usando_controle = evento is InputEventJoypadButton
	# O LB toca a segunda pista no Riff dos chefes e a nota grave nas ruas.
	var comando_grave = "riff_cima" if usando_controle else "riff_mode"
	if evento.is_action_pressed(acao(comando_grave)):
		_registrar_nota_minirriff("A", usando_controle)
	elif evento.is_action_pressed(acao("interagir")):
		var portal = get_tree().current_scene.get_node("Portal")
		if portal.pode_interagir(self) or _parceiro_para_reviver() != null:
			_limpar_sequencia_minirriff()
			return
		_registrar_nota_minirriff("B", usando_controle)


func _registrar_nota_minirriff(nota: String, usando_controle: bool) -> void:
	minirriff_usando_controle = usando_controle
	if sequencia_minirriff.is_empty():
		tempo_minirriff = janela_minirriff
		tempo_mensagem_minirriff = 0.0
	Audio.tocar("minirriff_grave" if nota == "A" else "minirriff_agudo", 0.0, 0)
	sequencia_minirriff += nota
	ultima_sequencia_minirriff = sequencia_minirriff

	var minirriffs = _minirriffs_disponiveis()
	for codigo in minirriffs:
		if not codigo.begins_with(sequencia_minirriff):
			continue
		if codigo == sequencia_minirriff:
			_preparar_especial(minirriffs[codigo])
		return
	_errar_minirriff("Sequência errada")


func _minirriffs_disponiveis() -> Dictionary:
	return MINIRRIFFS


func _atualizar_minirriff(delta: float) -> bool:
	tempo_mensagem_minirriff = maxf(tempo_mensagem_minirriff - delta, 0.0)
	if not sequencia_minirriff.is_empty():
		if bloqueado:
			_limpar_sequencia_minirriff()
		else:
			tempo_minirriff = maxf(tempo_minirriff - delta, 0.0)
			if tempo_minirriff <= 0.0:
				_errar_minirriff("Tempo esgotado")
				return true

	if tempo_atordoado > 0.0:
		tempo_atordoado = maxf(tempo_atordoado - delta, 0.0)
		return true

	if _especial_pendente.is_empty():
		return false
	if bloqueado:
		_cancelar_especial()
		em_acao = false
		return false
	return true


func _limpar_sequencia_minirriff() -> void:
	sequencia_minirriff = ""
	tempo_minirriff = 0.0


func _avisar_minirriff(texto: String) -> void:
	mensagem_minirriff = texto
	tempo_mensagem_minirriff = 0.8


func _errar_minirriff(texto: String) -> void:
	Audio.tocar("minirriff_falha", 0.0, 0)
	_limpar_sequencia_minirriff()
	_alterar_poder(-1.0)
	tempo_atordoado = atordoamento_minirriff
	_cancelar_soco()
	if esquivando:
		_encerrar_dodge()
	_tocar_acao("hurt")
	_avisar_minirriff(texto)


func _preparar_especial(especial: Dictionary) -> void:
	_limpar_sequencia_minirriff()
	if poder < especial.custo:
		Audio.tocar("minirriff_falha", 0.0, 0)
		_avisar_minirriff("Poder insuficiente")
		return
	_cancelar_soco()
	_especial_pendente = especial
	Audio.tocar("minirriff_sucesso", 0.0, 0)
	_avisar_minirriff(especial.nome)
	_tocar_acao("riff_inicio")


func _cancelar_especial() -> void:
	_especial_pendente = {}


func _soltar_especial() -> void:
	var especial = _especial_pendente
	_cancelar_especial()
	em_acao = false
	sprite.play("idle")
	_alterar_poder(-especial.custo)
	Audio.tocar("tiro_dylan")
	Combate.tremer(4.0)
	if especial.has("cena"):
		var nota = especial.cena.instantiate()
		get_tree().current_scene.add_child(nota)
		nota.global_position = global_position
		nota.disparar(direcao_olhar, especial.dano, escala_personagem, especial.get("impacto", especial.dano))
		return

	if not especial.has("raio"):
		var arco = ARCO_MINIRRIFF.instantiate()
		get_tree().current_scene.add_child(arco)
		arco.global_position = global_position + Vector2(direcao_olhar * 28.0 * escala_personagem, 0)
		arco.disparar(direcao_olhar, especial.dano, escala_personagem, especial.get("impacto", especial.dano))
		return

	_soltar_onda(especial)


func _soltar_onda(especial: Dictionary) -> void:
	var centro = global_position
	var raio = especial.raio * escala_personagem
	var onda = ONDA_MINIRRIFF.instantiate()
	get_tree().current_scene.add_child(onda)
	onda.global_position = centro
	onda.expandir(raio)
	for alvo in get_tree().get_nodes_in_group("alvos_golpe"):
		if not is_instance_valid(alvo) or alvo.get("morto"):
			continue
		if alvo.global_position.distance_to(centro) <= raio:
			var direcao = centro.direction_to(alvo.global_position)
			if alvo.has_method("empurrar"):
				alvo.empurrar(direcao * especial.get("empurrao", 360.0))
			_acertar_minirriff(alvo, especial.dano, especial.get("impacto", especial.dano))
			if alvo is Inimigo and especial.has("atordoamento"):
				alvo.atordoar(especial.atordoamento)


## Minirriff: o miniboss (receber_minirriff) leva o impacto; os outros, o dano
static func _acertar_minirriff(alvo: Node, dano, impacto) -> void:
	if alvo.has_method("receber_minirriff"):
		alvo.receber_minirriff(dano, impacto)
	else:
		alvo.receber_dano(dano)


# ---------------------------------------------------------------- Riff

func _animar_riff():
	if sprite.animation != &"riff_inicio" and sprite.animation != &"riff":
		_cancelar_soco()
		em_acao = false
		sprite.play("riff_inicio" if animar_entrada_no_riff else "riff")


func _tocar_acao(nome):
	em_acao = true
	sprite.stop()
	sprite.play(nome)


func _ao_terminar_animacao():
	if caido:
		return

	if sprite.animation == &"riff_inicio":
		if not _especial_pendente.is_empty():
			sprite.play("minirriff")
			return
		sprite.play("riff" if em_riff else "idle")
		return

	if sprite.animation == &"minirriff" and not _especial_pendente.is_empty() and not bloqueado:
		_soltar_especial()
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
	if vida < vida_antes and usa_minirriff():
		_alterar_poder(poder_por_dano)
	_cancelar_especial()
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
	_limpar_sequencia_minirriff()
	_cancelar_especial()
	tempo_atordoado = 0.0
	tempo_mensagem_minirriff = 0.0
	em_riff = false
	_cancelar_soco()
	esquivando = false
	progresso_reviver = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0 # inimigos e balas passam por quem está caído
	collision_mask = MASCARA_DODGE
	_hurtbox_ativa(false)
	if tween_dano:
		tween_dano.kill()
	sprite.modulate = Color.WHITE
	Audio.tocar("morte_dylan", 0.0)
	_tocar_acao("death")
	# Só pede ajuda se ainda houver alguém de pé para levantar
	if not Jogo.todos_caidos():
		_indicador.mostrar_para(2 if id_jogador == 1 else 1)
	morreu.emit()


func esconder_indicador_reviver() -> void:
	_indicador.hide()


# ---------------------------------------------------------------- Reviver

func _tentar_reviver_parceiro(delta):
	if not Input.is_action_pressed(acao("interagir")):
		return

	var parceiro = _parceiro_para_reviver()
	if parceiro != null:
		parceiro.ajudar_a_levantar(delta)


func _parceiro_para_reviver() -> Node2D:
	for outro in Jogo.jogadores:
		if is_instance_valid(outro) and outro != self and outro.caido:
			if global_position.distance_to(outro.global_position) <= raio_reviver:
				return outro
	return null


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
	_hurtbox_ativa(true)
	_indicador.hide()
	_tocar_acao("levantar")
	vida_alterada.emit(vida, vida_maxima)
	timer_invencibilidade.start(invencivel_ao_reviver)
	_piscar(int(invencivel_ao_reviver / 0.2))
	revivido.emit()


# ---------------------------------------------------------------- Visual

## Cores do P1/P2 nos marcadores da cena (Anel e IndicadorReviver).
func _configurar_identificacao():
	var cor = Jogo.cor(id_jogador)

	_anel.cor = Color(cor, 0.85)
	_indicador.cor = cor
	_indicador.hide()
