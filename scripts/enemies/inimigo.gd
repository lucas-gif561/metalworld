class_name Inimigo
extends CharacterBody2D
## Modelo comum de inimigo do beat 'em up.
##
## Para criar um inimigo novo:
##   1. Crie uma cena herdada de res://scenes/enemies/inimigo.tscn
##      (ou use o mesmo formato: AnimatedSprite2D, CollisionShape2D, TimerAtaque)
##   2. Crie um script com "extends Inimigo"
##   3. Escreva só o _comportamento(delta). O alvo já está em "jogador"
##      (o jogador vivo mais próximo, atualizado sozinho).
##
## Ataque justo: antes de bater, o inimigo CARREGA o golpe (congela piscando
## branco por tempo_preparo). Use carregar_ataque(funcao) para isso também nos
## ataques novos. Um soco do jogador durante a carga cancela o golpe.
##
## Animações esperadas no SpriteFrames: idle, walk, attack, hurt, death.

signal morreu(inimigo)

const DESACELERACAO_EMPURRAO = 2400.0
const COR_CARGA = Color(1.8, 1.8, 1.8)

@export var velocidade = 100.0
@export var vida = 3
## Distância (na horizontal) em que ele para e bate
@export var distancia_ataque = 64.0
## Diferença de altura aceita: precisa estar na mesma faixa da rua para acertar
@export var faixa_ataque = 30.0
@export var dano = 1
@export var intervalo_troca_alvo = 0.5

@export_group("Carga do ataque")
## Quanto tempo o inimigo avisa (congelado e piscando) antes de atacar
@export var tempo_preparo = 0.45
## 1 = voa longe com o soco; 0,3 = pesado; 0 = não se mexe
@export var resistencia_empurrao = 1.0

@export_group("Impacto")
## Pausa curta no jogo quando o inimigo apanha (segundos)
@export var pausa_ao_acertar = 0.03
@export var pausa_ao_morrer = 0.07
@export var tremor_ao_morrer = 5.0

@onready var timer_ataque = $TimerAtaque
@onready var sprite = $AnimatedSprite2D

## Alvo atual: o jogador vivo mais próximo (null se todos caíram)
var jogador: Node2D = null
var morto = false
var em_acao = false
var preparando = false
## Lado para onde ele olhava ao começar a carga (1 = direita, -1 = esquerda).
## Fica travado durante a carga: o golpe sai para esse lado.
var lado_carga = 1
var empurrao := Vector2.ZERO
var escala_personagem = 1.0 # 1,5 nas ruas (ver Jogo.escala_da_fase)
var _preparo_id = 0
var _tempo_troca_alvo = 0.0


func _ready():
	add_to_group("inimigos")
	add_to_group("alvos_golpe")
	sprite.animation_finished.connect(_ao_terminar_animacao)
	aplicar_escala.call_deferred(Jogo.escala_da_fase())


## Muda o tamanho do inimigo (sprite, colisão e distâncias de ataque).
## Fica em código porque a mesma cena de inimigo serve na rua (1,5x) e no
## boss (capangas, 1x). O tamanho normal é o que está gravado na cena.
func aplicar_escala(fator: float) -> void:
	if is_equal_approx(fator, escala_personagem) or not is_inside_tree():
		return
	var razao = fator / escala_personagem
	escala_personagem = fator
	sprite.scale *= razao
	Jogo.escalar_colisao($CollisionShape2D, razao)
	distancia_ataque *= razao
	faixa_ataque *= razao


func _physics_process(delta):
	# O empurrão vale até para o corpo caindo
	if _processar_empurrao(delta) or morto:
		return

	if preparando:
		velocity = Vector2.ZERO
		return

	_atualizar_alvo(delta)

	if jogador == null:
		velocity = Vector2.ZERO
		_atualizar_animacao()
		return

	_comportamento(delta)


## Comportamento padrão: vai para o lado do jogador, na mesma faixa da rua,
## e bate de perto (carregando o golpe antes). Inimigos novos sobrescrevem.
func _comportamento(_delta):
	var diferenca = jogador.global_position - global_position

	if abs(diferenca.y) <= faixa_ataque and abs(diferenca.x) <= distancia_ataque:
		velocity = Vector2.ZERO
		_olhar_para_jogador()
		if timer_ataque.is_stopped():
			carregar_ataque(_golpe_de_perto)
			return
	else:
		var lado = -1.0 if diferenca.x > 0 else 1.0
		var destino = jogador.global_position + Vector2(lado * distancia_ataque * 0.8, 0)
		velocity = global_position.direction_to(destino) * velocidade
		_olhar_para_jogador()

	_atualizar_animacao()
	move_and_slide()


## Golpe de perto: acerta quem ainda estiver na frente e na mesma faixa
func _golpe_de_perto():
	for alvo in Jogo.jogadores_vivos():
		var diferenca = alvo.global_position - global_position
		if abs(diferenca.x) <= distancia_ataque * 1.25 and abs(diferenca.y) <= faixa_ataque * 1.5:
			alvo.receber_dano(dano)


## Avisa o ataque (congela no 1º quadro do "attack", piscando branco) e depois
## chama "golpe". Se o inimigo apanhar durante a carga, o golpe é cancelado.
func carregar_ataque(golpe: Callable) -> void:
	preparando = true
	_preparo_id += 1
	var id = _preparo_id
	lado_carga = -1 if sprite.scale.x < 0 else 1
	velocity = Vector2.ZERO
	_tocar_acao("attack")
	sprite.pause()
	sprite.modulate = COR_CARGA

	await get_tree().create_timer(tempo_preparo).timeout

	if id != _preparo_id or morto or not is_inside_tree():
		return

	preparando = false
	sprite.modulate = Color.WHITE
	sprite.play()
	timer_ataque.start()
	golpe.call()


func _cancelar_carga() -> void:
	if preparando:
		preparando = false
		sprite.modulate = Color.WHITE
		em_acao = false
	_preparo_id += 1


func empurrar(forca: Vector2) -> void:
	empurrao = forca * resistencia_empurrao
	_cancelar_carga()


func _processar_empurrao(delta) -> bool:
	if empurrao.length_squared() < 100.0:
		empurrao = Vector2.ZERO
		return false

	velocity = empurrao
	move_and_slide()
	empurrao = empurrao.move_toward(Vector2.ZERO, DESACELERACAO_EMPURRAO * delta)
	return true


func _atualizar_alvo(delta):
	_tempo_troca_alvo -= delta
	if _tempo_troca_alvo <= 0.0 or not Jogo.esta_vivo(jogador):
		jogador = Jogo.jogador_mais_proximo(global_position)
		_tempo_troca_alvo = intervalo_troca_alvo


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


func receber_dano(valor):
	if morto:
		return

	vida -= valor
	_cancelar_carga()

	if vida <= 0:
		morrer()
	else:
		Audio.tocar("dano_inimigo")
		Combate.pausar(pausa_ao_acertar)
		_tocar_acao("hurt")
		sprite.modulate = Color(1, 0.4, 0.4)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.2)


func morrer():
	morto = true
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	morreu.emit(self)
	Audio.tocar("morte_inimigo")
	Combate.pausar(pausa_ao_morrer)
	Combate.tremer(tremor_ao_morrer)
	_tocar_acao("death")
	await sprite.animation_finished
	queue_free()
