extends "res://inimigos/base/miniboss_base.gd"

const NOTA_FLUTUANTE = preload("res://fases/rua_2/inimigos/maestro/nota_flutuante.tscn")
const NOTA_VIOLINO = preload("res://fases/rua_2/inimigos/maestro/nota_regida.tscn")
const BOLA_TUBA = preload("res://fases/rua_2/inimigos/tubista/bola_demoniaca.tscn")
const TROMBONISTA = preload("res://fases/rua_2/inimigos/trombonista/trombonista.tscn")
const EFEITO_TELEPORTE = preload("res://fases/rua_2/inimigos/maestro/efeito_teleporte.tscn")
const EFEITO_INVOCACAO = preload("res://fases/rua_2/inimigos/maestro/efeito_invocacao.tscn")
const MARGEM_DISTANCIA = 45.0
const ABERTURA_TUBA = PI / 18.0
const ABERTURA_VIOLINO = PI / 22.5

@export var distancia_ideal = 245.0
@export var alcance_ataque = 420.0
@export var pausa_regencia = 0.55
@export var intervalo_notas = 0.24

@export_group("Recuo e teleporte")
## Foge do jogador por no máximo este tempo seguido (segundos)...
@export var tempo_max_recuo = 3.0
## ...e depois fica este tempo sem recuar: segura a posição e ataca
@export var tempo_sem_recuar = 3.0
## Encurralado na parede, some e reaparece do outro lado do jogador
@export var recarga_teleporte = 4.0
## Distância da borda esquerda/direita da arena que já conta como encurralado
@export var margem_parede = 80.0
## Duração de cada metade do teleporte (sumir / aparecer)
@export var duracao_teleporte = 0.25
## Primeira aparição: surge no meio da arena em vez de entrar andando
@export var aparecer_no_meio := true
## Os trombonistas nascem nas bordas esquerda e direita da arena, no meio da
## altura; esta é a distância para dentro da borda
@export var recuo_invocacao_da_borda = 40.0

@onready var saida_batuta: Marker2D = $SaidaBatuta

var _proximo_ataque = 0
var _regencia: Array[Callable] = []
## Trombonista vivo de cada lado (-1 esquerda, 1 direita)
var _invocados := {}
## Encurralado e teleportado: o próximo ataque é a invocação
var _forcar_invocacao = false
var _pausa_regencia_restante = 0.0
var _notas_restantes = 0
var _tempo_proxima_nota = 0.0
var _eixo_notas := Vector2.ZERO
var _tempo_recuando = 0.0
var _cansado_restante = 0.0
var _recarga_teleporte_restante = 0.0
var _teleportando = false
var _apareceu = false


func _processar_miniboss(delta) -> void:
	if not morto:
		if _pausa_regencia_restante > 0.0:
			_pausa_regencia_restante -= delta
			if _pausa_regencia_restante <= 0.0:
				_preparar_regencia()
			return
		if _notas_restantes > 0:
			_tempo_proxima_nota -= delta
			if _tempo_proxima_nota <= 0.0:
				_lancar_proxima_nota()
			return
	super._processar_miniboss(delta)


func _comportamento(delta):
	if _teleportando:
		velocity = Vector2.ZERO
		return
	if aparecer_no_meio and not _apareceu:
		_apareceu = true
		var cena = get_tree().current_scene
		if cena and cena.has_method("limites_arena"):
			_teleportar(cena.limites_arena().get_center(), true)
			return
	_apareceu = true
	_recarga_teleporte_restante = maxf(_recarga_teleporte_restante - delta, 0.0)
	_cansado_restante = maxf(_cansado_restante - delta, 0.0)

	_olhar_para_jogador()
	var distancia = global_position.distance_to(jogador.global_position)
	var destino = _dentro_da_arena(global_position)
	var entrando = not is_equal_approx(destino.x, global_position.x)
	# Recua só por tempo_max_recuo seguidos; depois fica tempo_sem_recuar parado
	# (dá para alcançar e bater). Encurralado, teleporta para o outro lado.
	var quer_recuar = not entrando and distancia < distancia_ideal - MARGEM_DISTANCIA
	if not quer_recuar:
		_tempo_recuando = 0.0
	elif _cansado_restante <= 0.0:
		_tempo_recuando += delta
		if _tempo_recuando >= tempo_max_recuo:
			_tempo_recuando = 0.0
			_cansado_restante = tempo_sem_recuar
		else:
			destino = _destino_recuo(jogador.global_position)
			var preso = destino == global_position or _encostado_na_parede()
			if preso and _recarga_teleporte_restante <= 0.0:
				var saida = _ponto_de_teleporte(jogador.global_position)
				if saida != global_position:
					# Escapou da parede: o próximo ataque chama os trombonistas
					_proximo_ataque = 2
					_forcar_invocacao = true
					_teleportar(saida)
					return
	var recuando = not entrando and destino != global_position

	if not entrando and not recuando and distancia <= alcance_ataque and timer_ataque.is_stopped():
		match _proximo_ataque:
			0:
				carregar_ataque(_lancar_notas)
			1:
				_regencia = [_nota_violinista, _bola_tubista]
				_regencia.shuffle()
				_preparar_regencia()
			2:
				if _forcar_invocacao or _lados_livres().size() == 2:
					_forcar_invocacao = false
					carregar_ataque(_invocar_trombonistas)
					sprite.animation = &"invocar"
				else:
					carregar_ataque(_lancar_notas)
		_proximo_ataque = (_proximo_ataque + 1) % 3
		return

	if not entrando and distancia > distancia_ideal + MARGEM_DISTANCIA:
		var lado = global_position.direction_to(jogador.global_position)
		destino = _dentro_da_arena(jogador.global_position - lado * distancia_ideal)
	velocity = global_position.direction_to(destino) * velocidade
	_atualizar_animacao()
	move_and_slide()


func _encostado_na_parede() -> bool:
	var cena = get_tree().current_scene
	if not cena or not cena.has_method("limites_arena"):
		return false
	var limites: Rect2 = cena.limites_arena()
	return global_position.x - limites.position.x < margem_parede or limites.end.x - global_position.x < margem_parede


## Ponto na distancia_ideal do jogador, longe de onde ele está agora (o outro
## lado do jogador, de preferência), dentro da arena
func _ponto_de_teleporte(posicao_alvo: Vector2) -> Vector2:
	var melhor = global_position
	var melhor_distancia = 0.0
	for i in 8:
		var ponto = _dentro_da_arena(posicao_alvo + Vector2.from_angle(TAU * i / 8.0) * distancia_ideal)
		if ponto.distance_to(posicao_alvo) < distancia_ideal * 0.8:
			continue
		var longe = ponto.distance_to(global_position)
		if longe > melhor_distancia:
			melhor = ponto
			melhor_distancia = longe
	return melhor


## Some, muda de lugar e aparece. "so_aparecer": já começa invisível (entrada)
func _teleportar(destino: Vector2, so_aparecer := false) -> void:
	_teleportando = true
	velocity = Vector2.ZERO
	_recarga_teleporte_restante = recarga_teleporte
	Audio.tocar("teleporte")
	var tween: Tween
	if so_aparecer:
		modulate.a = 0.0
	else:
		_soltar_efeito(EFEITO_TELEPORTE, global_position)
		tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, duracao_teleporte)
		await tween.finished
	if morto or not is_inside_tree():
		return
	global_position = destino
	_olhar_para_jogador()
	_soltar_efeito(EFEITO_TELEPORTE, global_position)
	tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, duracao_teleporte)
	await tween.finished
	_teleportando = false


func _destino_recuo(posicao_alvo: Vector2) -> Vector2:
	var ideal = posicao_alvo + posicao_alvo.direction_to(global_position) * distancia_ideal
	var destino = global_position
	# Na borda, procura uma saída lateral que também aumente a distância.
	for candidato in [ideal, global_position + Vector2.UP * 100.0,
			global_position + Vector2.DOWN * 100.0, global_position + Vector2.LEFT * 100.0,
			global_position + Vector2.RIGHT * 100.0]:
		var ponto = _dentro_da_arena(candidato)
		if global_position.distance_to(ponto) <= 12.0:
			continue
		if ponto.distance_squared_to(posicao_alvo) <= destino.distance_squared_to(posicao_alvo):
			continue
		if not test_move(global_transform, global_position.direction_to(ponto) * 6.0):
			destino = ponto
	return destino


func _lancar_notas() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	_eixo_notas = _mira_do_tiro(origem, mira.posicao_do_corpo())
	_notas_restantes = 3
	_lancar_proxima_nota()


func _lancar_proxima_nota() -> void:
	if Jogo.todos_caidos():
		_notas_restantes = 0
		return
	var nota = NOTA_FLUTUANTE.instantiate()
	nota.eixo = _eixo_notas
	_lancar_projetil(nota, _origem_tiro())
	Audio.tocar("tiro_inimigo")
	_notas_restantes -= 1
	_tempo_proxima_nota = intervalo_notas


func _preparar_regencia() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		_regencia.clear()
		return
	# Cada golpe da regência é um ataque: vira para o jogador antes de carregar
	# (o segundo também); durante a carga e o golpe, o lado fica travado
	jogador = mira
	sprite.scale.x = absf(sprite.scale.x) * (-1.0 if mira.global_position.x < global_position.x else 1.0)
	carregar_ataque(_bater_batuta)
	sprite.animation = &"regencia"


func _bater_batuta() -> void:
	var ataque: Callable = _regencia.pop_front()
	ataque.call()
	if not _regencia.is_empty():
		_pausa_regencia_restante = pausa_regencia


func _nota_violinista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	for lado in [-1.0, 1.0]:
		var nota = NOTA_VIOLINO.instantiate()
		nota.eixo = eixo.rotated(ABERTURA_VIOLINO * lado)
		_apontar(nota, nota.eixo)
		_lancar_projetil(nota, origem)
	Audio.tocar("tiro_inimigo")


func _bola_tubista() -> void:
	var mira = Jogo.jogador_mais_proximo(global_position)
	if mira == null:
		return
	var origem = _origem_tiro()
	var eixo = _mira_do_tiro(origem, mira.posicao_do_corpo())
	for lado in [-1.0, 1.0]:
		var bola = BOLA_TUBA.instantiate()
		bola.eixo = eixo.rotated(ABERTURA_TUBA * lado)
		# Gira em volta da linha de tiro como a do tubista, cada lado do leque
		# num sentido; o sprite aponta para onde a linha vai
		bola.velocidade_angular *= lado
		_apontar(bola, bola.eixo)
		_lancar_projetil(bola, origem)
	Audio.tocar("tiro_inimigo")


## Gira o projétil para apontar a direção do voo; para a esquerda, espelha em
## vez de virar de cabeça para baixo
func _apontar(projetil: Node2D, eixo: Vector2) -> void:
	var lado = -1 if eixo.x < 0.0 else 1
	projetil.direcao = lado
	projetil.rotation = (eixo * lado).angle()


func _origem_tiro() -> Vector2:
	var deslocamento = Vector2(saida_batuta.position.x * lado_carga, saida_batuta.position.y)
	return global_position + deslocamento * escala_personagem


## Mira no jogador, mas só para a frente (o lado em que a carga começou): se
## ele passou para trás durante a carga, o tiro sai reto para a frente
func _mira_do_tiro(origem: Vector2, destino: Vector2) -> Vector2:
	var eixo = origem.direction_to(destino)
	if eixo == Vector2.ZERO or eixo.x * lado_carga <= 0.0:
		return Vector2(lado_carga, 0.0)
	return eixo


func _lancar_projetil(projetil, origem: Vector2) -> void:
	projetil.dano = dano
	get_tree().current_scene.add_child(projetil)
	projetil.global_position = origem


func _invocar_trombonistas() -> void:
	if Jogo.todos_caidos():
		return
	var cena = get_tree().current_scene
	if not cena.has_method("limites_arena"):
		return
	var limites: Rect2 = cena.limites_arena()
	var ondas = cena.gerenciador_ondas
	for lado in _lados_livres():
		var x = limites.position.x + recuo_invocacao_da_borda if lado < 0 else limites.end.x - recuo_invocacao_da_borda
		var posicao = Vector2(x, limites.get_center().y)
		var trombonista = ondas.invocar_inimigo(TROMBONISTA, posicao)
		if trombonista != null:
			_invocados[lado] = trombonista
			_soltar_efeito(EFEITO_INVOCACAO, posicao)
	Audio.tocar("boss_conjura")


## Os trombonistas que ele chamou caem junto com ele
func morrer():
	for trombonista in _invocados.values():
		if is_instance_valid(trombonista) and not trombonista.morto:
			trombonista.morrer()
	_invocados.clear()
	super.morrer()


## Lados (-1 esquerda, 1 direita) sem trombonista vivo
func _lados_livres() -> Array:
	return [-1, 1].filter(func(lado): return not is_instance_valid(_invocados.get(lado)) or _invocados[lado].morto)


func _soltar_efeito(cena_efeito: PackedScene, posicao: Vector2) -> void:
	var efeito = cena_efeito.instantiate()
	get_tree().current_scene.add_child(efeito)
	efeito.global_position = posicao
	efeito.finished.connect(efeito.queue_free)
	efeito.restart()


func _cancelar_carga() -> void:
	super._cancelar_carga()
	_regencia.clear()
	_pausa_regencia_restante = 0.0
	_notas_restantes = 0
