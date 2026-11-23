extends "res://inimigos/base/miniboss_base.gd"

const SALTO := &"salto"
const CADEIA := &"cadeia"
const SOCO := &"attack"
const AUREOLA := &"aureola"
const SEQUENCIA := [SALTO, CADEIA, SOCO, AUREOLA]
const MARGEM_FEIXES := preload("res://fases/rua_3/inimigos/desafio_luz/feixe_rua.gd").MARGEM_ARENA
const DISTANCIA_ENTRADA := 72.0

@export var cena_explosao: PackedScene
@export var cena_feixe: PackedScene
@export var distancia_minima_salto_solo := 220.0
@export var raio_pouso := 112.0
@export var raio_aureola := 205.0
@export var preparo_aureola := 1.15
@export var raio_explosao := 75.0
@export var distancia_entre_explosoes := 90.0
@export var abertura_cadeia_dupla := 100.0

@onready var _ataques: Node2D = $Ataques
@onready var _aviso_soco: Polygon2D = $AvisoSoco
@onready var _timer_feixes: Timer = $TimerFeixes
@onready var _camada_no_chao := collision_layer
@onready var _mascara_no_chao := collision_mask

var _proximo_ataque := 0
var _trajetoria_salto: Tween
var _feixes_nas_bordas := false
var _entrando_pela_direita := false


func _comportamento(_delta) -> void:
	if em_acao or _entrar_na_arena():
		return

	_olhar_para_jogador()
	var diferenca := jogador.global_position - global_position
	var ataque: StringName = SEQUENCIA[_proximo_ataque]
	var perto := absf(diferenca.x) <= distancia_ataque and absf(diferenca.y) <= faixa_ataque
	if timer_ataque.is_stopped():
		var alvo_salto: Node2D
		if ataque == SALTO:
			alvo_salto = _alvo_do_salto()
			if alvo_salto == null:
				_proximo_ataque = (_proximo_ataque + 1) % SEQUENCIA.size()
				ataque = SEQUENCIA[_proximo_ataque]
		match ataque:
			SALTO:
				_preparar_salto(alvo_salto)
			CADEIA:
				_preparar(CADEIA, 2, _disparar_cadeia, tempo_preparo)
			SOCO:
				if perto:
					_preparar_soco()
			AUREOLA:
				if diferenca.length() <= raio_aureola + 15.0:
					_preparar_aureola()
		if preparando:
			_proximo_ataque = (_proximo_ataque + 1) % SEQUENCIA.size()
			return

	velocity = Vector2.ZERO if perto else diferenca.normalized() * velocidade
	_atualizar_animacao()
	move_and_slide()


func _entrar_na_arena() -> bool:
	var limites := _limites_da_rua()
	if not limites.has_area():
		return false
	if not _entrando_pela_direita:
		if global_position.x <= limites.end.x:
			return _andar_para_dentro_da_arena()
		_entrando_pela_direita = true
		# A entrada não pode ficar travada por um jogador encostado na borda.
		collision_layer = 32
		collision_mask = 0
	if global_position.x <= limites.end.x - DISTANCIA_ENTRADA:
		_entrando_pela_direita = false
		collision_layer = _camada_no_chao
		collision_mask = _mascara_no_chao
		return false
	sprite.scale.x = -absf(sprite.scale.x)
	velocity = Vector2.LEFT * velocidade
	_atualizar_animacao()
	move_and_slide()
	return true


func _preparar(animacao: StringName, quadro: int, impacto: Callable, preparo: float) -> void:
	quadro_impacto = quadro
	carregar_ataque(impacto, preparo)
	sprite.animation = animacao
	sprite.frame = 0


func _alvo_do_salto() -> Node2D:
	var mais_distante: Node2D
	var maior_distancia := -1.0
	var alvos_validos := 0
	for alvo in Jogo.jogadores_vivos():
		if alvo.entrando:
			continue
		alvos_validos += 1
		var distancia := global_position.distance_squared_to(alvo.global_position)
		if distancia > maior_distancia:
			mais_distante = alvo
			maior_distancia = distancia
	if alvos_validos == 1 and maior_distancia < distancia_minima_salto_solo * distancia_minima_salto_solo:
		return null
	return mais_distante


func _preparar_salto(alvo: Node2D) -> void:
	var destino := _dentro_da_arena(alvo.global_position)
	sprite.scale.x = absf(sprite.scale.x) * (-1.0 if destino.x < global_position.x else 1.0)
	var fps: float = sprite.sprite_frames.get_animation_speed(SALTO)
	_criar_explosao(destino, raio_pouso, tempo_preparo + 6.0 / fps)
	_preparar(SALTO, 3, _saltar.bind(destino, 3.0 / fps), tempo_preparo)


func _saltar(destino: Vector2, duracao: float) -> void:
	# Durante o salto, a camada 6 mantém o alvo dos miniriffs sem bloquear os pés.
	collision_layer = 32
	collision_mask = 0
	_trajetoria_salto = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_trajetoria_salto.tween_property(self, "global_position", destino, duracao)
	_trajetoria_salto.tween_callback(_pousar)


func _pousar() -> void:
	_trajetoria_salto = null
	collision_layer = _camada_no_chao
	collision_mask = _mascara_no_chao
	Combate.tremer(5.0)


func _disparar_cadeia() -> void:
	var origem := global_position
	var destinos: Array[Vector2] = []
	for alvo in Jogo.jogadores_vivos():
		if not alvo.entrando:
			destinos.append(_dentro_da_arena(alvo.global_position))
	if destinos.is_empty():
		return

	var abertura := Vector2.ZERO
	if destinos.size() == 2:
		var direcao_p1 := origem.direction_to(destinos[0])
		var direcao_p2 := origem.direction_to(destinos[1])
		# Abre dois caminhos quando as trajetórias retas ficariam sobrepostas.
		if direcao_p1.dot(direcao_p2) > 0.85 or destinos[0].distance_to(destinos[1]) < distancia_entre_explosoes:
			var eixo := (direcao_p1 + direcao_p2).normalized()
			if eixo == Vector2.ZERO:
				eixo = Vector2.RIGHT
			abertura = eixo.orthogonal() * abertura_cadeia_dupla

	_criar_explosao(origem, raio_explosao, 0.35)
	for indice in destinos.size():
		var destino := destinos[indice]
		var inicio := origem
		var aviso := 0.35
		if abertura != Vector2.ZERO:
			var meio := _dentro_da_arena(origem.lerp(destino, 0.5) + abertura)
			aviso = _lancar_trecho_cadeia(inicio, meio, aviso)
			inicio = meio
			abertura = -abertura
		_lancar_trecho_cadeia(inicio, destino, aviso)


func _lancar_trecho_cadeia(inicio: Vector2, destino: Vector2, aviso: float) -> float:
	var passos := maxi(1, ceili(inicio.distance_to(destino) / distancia_entre_explosoes))
	for passo in range(1, passos + 1):
		aviso += 0.11
		_criar_explosao(inicio.lerp(destino, float(passo) / passos), raio_explosao, aviso)
	return aviso


func _preparar_soco() -> void:
	if _ataques.get_children().any(func(efeito): return efeito is Panel):
		return
	_timer_feixes.paused = true
	_preparar(SOCO, 5, _acertar_soco, 0.4)
	var inicio: float = -8.0 * lado_carga
	var fim: float = distancia_ataque * lado_carga
	_aviso_soco.polygon = PackedVector2Array([
		Vector2(inicio, -faixa_ataque), Vector2(fim, -faixa_ataque),
		Vector2(fim, faixa_ataque), Vector2(inicio, faixa_ataque),
	])
	_aviso_soco.show()


func _acertar_soco() -> void:
	_aviso_soco.hide()
	for alvo in Jogo.jogadores_vivos():
		var diferenca: Vector2 = alvo.global_position - global_position
		if not alvo.entrando and diferenca.x * lado_carga >= -8.0 and absf(diferenca.x) <= distancia_ataque and absf(diferenca.y) <= faixa_ataque:
			alvo.receber_dano(dano)


func _preparar_aureola() -> void:
	var fps: float = sprite.sprite_frames.get_animation_speed(AUREOLA)
	_criar_explosao(global_position, raio_aureola, preparo_aureola + 3.0 / fps)
	_preparar(AUREOLA, 3, _estourar_aureola, preparo_aureola)


func _estourar_aureola() -> void:
	Combate.tremer(4.0)


func _quebrar_postura() -> void:
	super._quebrar_postura()
	# De joelhos é a hora de bater: os feixes param até ele levantar
	_timer_feixes.paused = true
	var quadros: SpriteFrames = sprite.sprite_frames
	# Reserva tempo para a auréola sem encurtar a janela de postura quebrada.
	tempo_postura_quebrada += preparo_aureola + quadros.get_frame_count(AUREOLA) / quadros.get_animation_speed(AUREOLA)
	_preparar_aureola()


func _levantar() -> void:
	super._levantar()
	_timer_feixes.paused = false


func _ao_terminar_animacao_postura() -> void:
	if sprite.animation == SOCO:
		_timer_feixes.paused = false
	if not morto and tempo_postura_quebrada > 0.0 and sprite.animation == AUREOLA:
		_tocar_acao(&"ajoelhar")
		return
	super._ao_terminar_animacao_postura()


func _criar_explosao(posicao: Vector2, raio: float, aviso: float) -> void:
	var explosao = cena_explosao.instantiate()
	explosao.top_level = true
	explosao.position = posicao
	explosao.raio = raio
	explosao.tempo_aviso = aviso
	explosao.dano = dano
	_ataques.add_child(explosao)


func _lancar_feixe() -> void:
	var alvo = Jogo.jogador_aleatorio()
	if morto or alvo == null or alvo.entrando:
		return
	var limites := _limites_da_rua().grow(MARGEM_FEIXES)
	if _feixes_nas_bordas:
		var tamanho := limites.size * Vector2(0.22, 1.0)
		_criar_feixe(Rect2(limites.position, tamanho))
		_criar_feixe(Rect2(Vector2(limites.end.x - tamanho.x, limites.position.y), tamanho))
	else:
		var tamanho := limites.size * Vector2(0.22, 0.5)
		var area := Rect2(alvo.global_position - tamanho * 0.5, tamanho).intersection(limites)
		_criar_feixe(area)
	_feixes_nas_bordas = not _feixes_nas_bordas


func _criar_feixe(area: Rect2) -> void:
	var feixe = cena_feixe.instantiate()
	feixe.top_level = true
	feixe.position = area.position
	feixe.size = area.size
	_ataques.add_child(feixe)


func _cancelar_carga() -> void:
	super._cancelar_carga()
	_aviso_soco.hide()
	_timer_feixes.paused = false
	if _trajetoria_salto != null:
		_trajetoria_salto.kill()
		_trajetoria_salto = null
		collision_layer = _camada_no_chao
		collision_mask = _mascara_no_chao
	for efeito in _ataques.get_children():
		if efeito is Area2D:
			efeito.process_mode = Node.PROCESS_MODE_DISABLED
			efeito.queue_free()


func morrer() -> void:
	_timer_feixes.stop()
	for efeito in _ataques.get_children():
		efeito.process_mode = Node.PROCESS_MODE_DISABLED
		efeito.queue_free()
	super.morrer()
