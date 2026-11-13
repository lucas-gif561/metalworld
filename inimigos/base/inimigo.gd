class_name Inimigo
extends CharacterBody2D
## Modelo comum de inimigo do beat 'em up.
##
## Para criar um inimigo novo:
##   1. Crie uma cena herdada de res://inimigos/base/inimigo.tscn
##      (ou use o mesmo formato: AnimatedSprite2D, CollisionShape2D, TimerAtaque)
##   2. Crie um script com "extends Inimigo"
##   3. Escreva só o _comportamento(delta). O alvo já está em "jogador"
##      (o jogador vivo mais próximo, atualizado sozinho).
##
## Ataque justo: antes de bater, o inimigo CARREGA o golpe (congela piscando
## branco por tempo_preparo). Use carregar_ataque(funcao) para isso também nos
## ataques novos. Um soco do jogador durante a carga cancela o golpe.
##
## IA de grupo (estilo Castle Crashers), usada pelo comportamento padrão:
## cada jogador tem 2 VAGAS de ataque (uma de cada lado). Só quem pega uma vaga
## avança e bate; os outros RODEIAM o jogador à distância. Depois de
## ataques_por_vez golpes o inimigo devolve a vaga e RECUA, dando a vez a outro.
## Inimigos à distância (atirador, tanque) têm _comportamento próprio.
##
## Profundidade: a ORIGEM do inimigo fica nos pés e a colisão é só uma faixa no
## chão (veja inimigo.tscn). Distâncias e faixas comparam a posição dos pés.
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

@export_group("IA de grupo")
## Golpes seguidos antes de devolver a vaga e recuar
@export var ataques_por_vez = 2
## Distância em que os inimigos sem vaga rodeiam o jogador
@export var raio_espera = 230.0
## Quanto tempo recua depois de atacar (segundos)
@export var tempo_recuo = 0.5
## Depois de devolver a vaga, espera isso antes de pedir de novo (segundos)
@export var espera_nova_vaga = 1.2
## Se ficar preso (num barril, atrás de outro inimigo) sem conseguir bater por
## esse tempo, devolve a vaga para outro tentar (segundos)
@export var tempo_max_vaga = 3.0

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

# Vagas de ataque: id do jogador -> {-1: inimigo à esquerda, 1: inimigo à direita}
static var vagas := {}
var _lado_vaga := 0 # -1 esquerda, 1 direita, 0 sem vaga
var _dono_vaga = null
var _ataques_feitos := 0
var _recuar_ate_ms := 0
var _pedir_vaga_apos_ms := 0
var _vaga_desde_ms := 0
var _angulo_espera := 0.0
var _lado_espera := 0 # lado do jogador onde espera a vez (0 = escolher)


func _ready():
	_angulo_espera = randf() * TAU
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
	sprite.position *= razao
	Jogo.escalar_colisao($CollisionShape2D, razao)
	distancia_ataque *= razao
	faixa_ataque *= razao
	raio_espera *= razao


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


## Comportamento padrão (corpo a corpo, em grupo): pega uma vaga ao lado do
## jogador e bate; sem vaga, rodeia; depois de atacar, recua.
## Inimigos novos podem sobrescrever esta função.
func _comportamento(delta):
	if Time.get_ticks_msec() < _recuar_ate_ms:
		_recuar()
	elif _lado_vaga != 0 or _pedir_vaga():
		_atacar_pela_vaga()
		if preparando:
			return
	else:
		_rodear(delta)

	velocity += _separacao()
	_olhar_para_jogador()
	_atualizar_animacao()
	move_and_slide()


## Vai até o seu lado do jogador, na mesma faixa, e bate
func _atacar_pela_vaga():
	if Time.get_ticks_msec() - _vaga_desde_ms > int(tempo_max_vaga * 1000.0):
		_liberar_vaga()
		velocity = Vector2.ZERO
		return
	var diferenca = jogador.global_position - global_position
	var destino = jogador.global_position + Vector2(_lado_vaga * distancia_ataque * 0.8, 0)

	# Está do lado errado (flanqueando): contorna por cima/baixo em vez de atravessar o jogador
	var lado_atual = signf(global_position.x - jogador.global_position.x)
	# (só volta para a faixa do jogador depois de chegar ao lado certo)
	if lado_atual != _lado_vaga and abs(diferenca.x) < distancia_ataque * 2.0:
		destino = _contornar(jogador.global_position.x + _lado_vaga * distancia_ataque, faixa_ataque * 3.5)

	if abs(diferenca.y) <= faixa_ataque and abs(diferenca.x) <= distancia_ataque and lado_atual == _lado_vaga:
		velocity = Vector2.ZERO
		if timer_ataque.is_stopped():
			_olhar_para_jogador()
			carregar_ataque(_golpe_da_vaga)
	else:
		velocity = global_position.direction_to(destino) * velocidade


func _golpe_da_vaga():
	_golpe_de_perto()
	_ataques_feitos += 1
	_vaga_desde_ms = Time.get_ticks_msec()
	if _ataques_feitos >= ataques_por_vez:
		_liberar_vaga()
		_recuar_ate_ms = Time.get_ticks_msec() + int(tempo_recuo * 1000.0)


## Golpe de perto: acerta quem ainda estiver na frente e na mesma faixa
func _golpe_de_perto():
	for alvo in Jogo.jogadores_vivos():
		var diferenca = alvo.global_position - global_position
		if abs(diferenca.x) <= distancia_ataque * 1.25 and abs(diferenca.y) <= faixa_ataque * 1.5:
			alvo.receber_dano(dano)


# ---------------------------------------------------------------- IA de grupo

## Tenta reservar a vaga do lado em que está esperando.
func _pedir_vaga() -> bool:
	if Time.get_ticks_msec() < _pedir_vaga_apos_ms or not Jogo.esta_vivo(jogador):
		return false
	var chave = jogador.get_instance_id()
	var lados = vagas.get(chave, {})
	for lado in lados.keys():
		var ocupante = lados[lado]
		if not is_instance_valid(ocupante) or ocupante.morto or ocupante.jogador != jogador:
			lados.erase(lado)
	var lado_atual = 1 if global_position.x >= jogador.global_position.x else -1
	var lado = _lado_espera if _lado_espera != 0 else lado_atual
	# Só pega a vaga do lado em que espera, e depois de chegar nele
	if lados.has(lado) or lado != lado_atual:
		return false
	lados[lado] = self
	vagas[chave] = lados
	_lado_vaga = lado
	_lado_espera = 0
	_dono_vaga = jogador
	_ataques_feitos = 0
	_vaga_desde_ms = Time.get_ticks_msec()
	return true


func _liberar_vaga() -> void:
	if _lado_vaga == 0:
		return
	if is_instance_valid(_dono_vaga):
		var lados = vagas.get(_dono_vaga.get_instance_id(), {})
		if lados.get(_lado_vaga) == self:
			lados.erase(_lado_vaga)
	_lado_vaga = 0
	_dono_vaga = null
	_pedir_vaga_apos_ms = Time.get_ticks_msec() + int(espera_nova_vaga * 1000.0)


## Sem vaga: circula o jogador numa meia elipse (achatada, como a rua) do
## lado em que espera a vez. Para trocar de lado, contorna por cima ou por baixo.
func _rodear(delta) -> void:
	if _lado_espera == 0:
		_lado_espera = _escolher_lado_espera()
	_angulo_espera = wrapf(_angulo_espera + delta * 0.35, 0.0, TAU)
	var centro = jogador.global_position
	var ponto = centro + Vector2(abs(cos(_angulo_espera)) * _lado_espera, sin(_angulo_espera) * 0.45) * raio_espera
	var lado_atual = signf(global_position.x - centro.x)
	if lado_atual != _lado_espera and abs(global_position.x - centro.x) < raio_espera:
		ponto = _contornar(centro.x + _lado_espera * raio_espera * 0.6, raio_espera * 0.45)
	ponto = _dentro_da_arena(ponto)
	if global_position.distance_to(ponto) > 24.0 * escala_personagem:
		velocity = global_position.direction_to(ponto) * velocidade * 0.7
	else:
		velocity = Vector2.ZERO


## Lado do jogador com menos inimigos (atacando ou esperando): assim o grupo
## cerca o jogador pelos dois lados em vez de se amontoar num só.
func _escolher_lado_espera() -> int:
	var carga = {-1: 0, 1: 0}
	for outro in get_tree().get_nodes_in_group("inimigos"):
		if outro == self or not outro is Inimigo or outro.morto or outro.jogador != jogador:
			continue
		var lado = outro._lado_vaga if outro._lado_vaga != 0 else outro._lado_espera
		if lado != 0:
			carga[lado] += 1
	var atual = 1 if global_position.x >= jogador.global_position.x else -1
	return -atual if carga[-atual] < carga[atual] else atual


## Ponto para passar por cima ou por baixo do jogador (sem atravessá-lo),
## pelo lado da rua que tiver espaço.
func _contornar(x: float, distancia_y: float) -> Vector2:
	var centro_y = jogador.global_position.y
	var desvio = -1.0 if global_position.y < centro_y else 1.0
	var ponto = _dentro_da_arena(Vector2(x, centro_y + desvio * distancia_y))
	if abs(ponto.y - centro_y) < distancia_y * 0.4:
		ponto = _dentro_da_arena(Vector2(x, centro_y - desvio * distancia_y))
	return ponto


## Depois de atacar: se afasta do jogador por um instante
func _recuar() -> void:
	var fuga = jogador.global_position.direction_to(global_position)
	if fuga == Vector2.ZERO:
		fuga = Vector2(randf_range(-1, 1), 0).normalized()
	velocity = fuga * velocidade * 0.9


## Empurra para longe de outros inimigos muito perto (não se empilham)
func _separacao() -> Vector2:
	var forca = Vector2.ZERO
	var raio = 44.0 * escala_personagem
	for outro in get_tree().get_nodes_in_group("inimigos"):
		if outro == self or outro.morto:
			continue
		var d = global_position - outro.global_position
		var dist = d.length()
		if dist > 0.01 and dist < raio:
			forca += d / dist * (raio - dist) / raio * velocidade * 0.8
	return forca


func _dentro_da_arena(ponto: Vector2) -> Vector2:
	var cena = get_tree().current_scene
	if cena and cena.has_method("limites_arena"):
		var limites = cena.limites_arena()
		return ponto.clamp(limites.position, limites.end)
	return ponto


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
	# Com vaga reservada, só troca de alvo se o dele cair ou se o outro
	# jogador estiver bem mais perto (menos da metade da distância)
	if _lado_vaga != 0 and Jogo.esta_vivo(jogador):
		var mais_perto = Jogo.jogador_mais_proximo(global_position)
		var distancia = global_position.distance_to(jogador.global_position)
		if mais_perto == jogador or global_position.distance_to(mais_perto.global_position) > distancia * 0.5:
			return
		_tempo_troca_alvo = 0.0
	if _tempo_troca_alvo <= 0.0 or not Jogo.esta_vivo(jogador):
		var novo = Jogo.jogador_mais_proximo(global_position)
		if novo != jogador:
			_liberar_vaga()
			_lado_espera = 0
		jogador = novo
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


func _exit_tree():
	_liberar_vaga()


func morrer():
	morto = true
	_liberar_vaga()
	velocity = Vector2.ZERO
	$CollisionShape2D.set_deferred("disabled", true)
	morreu.emit(self)
	Audio.tocar("morte_inimigo")
	Combate.pausar(pausa_ao_morrer)
	Combate.tremer(tremor_ao_morrer)
	_tocar_acao("death")
	await sprite.animation_finished
	# Some esmaecendo (serve também para inimigos sem animação de queda)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)
	await tween.finished
	queue_free()
