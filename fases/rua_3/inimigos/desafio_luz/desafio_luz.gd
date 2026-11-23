extends Node2D
## O gerenciador mantém a arena fechada enquanto este desafio estiver na cena.

const ATAQUES_POR_SEQUENCIA := 4
const TEMPO_EXTRA_PERSEGUIDOR := 1.1
const MARGEM_FEIXES := preload("res://fases/rua_3/inimigos/desafio_luz/feixe_rua.gd").MARGEM_ARENA

@export var vida_maxima := 8
@export var tempo_sobrevivencia := 0.0
@export var texto_sobrevivencia := ""
@export var intervalo_ataques := 1.5
@export var intervalo_sequencias := 2.6
@export var raio_feixe_perseguidor := 60.0
@export_range(0.0, 1.0) var chance_animacao_dano := 0.35
@export var cena_feixe: PackedScene
@export var emite_feixes := true

@onready var fase = get_parent()
@onready var vida := float(vida_maxima)
@onready var _vida_maxima_atual := vida_maxima
@onready var barra = get_node_or_null("Vida")
@onready var cristal := get_node_or_null("Cristal") as AnimatedSprite2D

var morto := false
var _decorrido := 0.0
var _ate_ataque := 0.8
var _ataque := 0
var _feixe_mirado_pendente := false
var _segundos_exibidos := -1


func _ready() -> void:
	if cristal != null:
		cristal.animation_finished.connect(_ao_terminar_animacao_cristal)
	if barra != null:
		_atualizar_vida_coop()
		Jogo.jogador_entrou.connect(_atualizar_vida_coop)
		Jogo.jogador_saiu.connect(_atualizar_vida_coop)


func _atualizar_vida_coop(_jogador = null) -> void:
	if morto:
		return
	var nova_maxima := vida_maxima * (2 if Jogo.p2_ativo else 1)
	# Mantém a porcentagem de vida quando o P2 entra ou sai.
	vida *= float(nova_maxima) / _vida_maxima_atual
	_vida_maxima_atual = nova_maxima
	barra.definir(vida, _vida_maxima_atual)


func _physics_process(delta: float) -> void:
	if morto or fase.fim_de_jogo or not emite_feixes:
		return

	_decorrido += delta
	_ate_ataque -= delta
	if tempo_sobrevivencia > 0.0:
		var restante := tempo_sobrevivencia - _decorrido
		if restante <= 0.0:
			if not texto_sobrevivencia.is_empty():
				fase.hud.esconder_aviso()
			_concluir()
			return
		var segundos := ceili(restante)
		if segundos != _segundos_exibidos and not texto_sobrevivencia.is_empty():
			_segundos_exibidos = segundos
			fase.hud.mostrar_aviso(texto_sobrevivencia % segundos)
		if restante < 1.15:
			return

	if _ate_ataque <= 0.0:
		if _feixe_mirado_pendente:
			_lancar_feixes_mirados(fase.limites_arena(), true)
			_feixe_mirado_pendente = false
		else:
			_lancar_ataque()
			_feixe_mirado_pendente = cristal != null and _ataque % 2 == 0
		var fim_da_sequencia := tempo_sobrevivencia <= 0.0 and _ataque % ATAQUES_POR_SEQUENCIA == 0 and not _feixe_mirado_pendente
		_ate_ataque = intervalo_sequencias if fim_da_sequencia else intervalo_ataques
		if fim_da_sequencia and cristal != null:
			_ate_ataque += TEMPO_EXTRA_PERSEGUIDOR


func receber_dano(dano: float) -> void:
	if morto or barra == null or dano <= 0.0:
		return
	vida = maxf(0.0, vida - ceili(dano))
	Audio.tocar("dano_inimigo")
	if vida == 0:
		morrer()
		return
	barra.definir(vida, _vida_maxima_atual)
	if cristal != null and cristal.animation != &"dano" and randf() < chance_animacao_dano:
		cristal.play(&"dano")


func morrer() -> void:
	if morto:
		return
	vida = 0.0
	if barra != null:
		barra.definir(vida, _vida_maxima_atual)
	Combate.tremer(6.0)
	_concluir()


func _concluir() -> void:
	morto = true
	if cristal == null:
		queue_free()
		return

	$Colisao.set_deferred("disabled", true)
	barra.hide()
	var sucessor := _buscar_pilar_para_feixes()
	if sucessor != null:
		sucessor.emite_feixes = true
		sucessor._ate_ataque = _ate_ataque
		sucessor._ataque = _ataque
		sucessor._feixe_mirado_pendente = _feixe_mirado_pendente
	for feixe in get_children():
		if feixe is Panel:
			if sucessor != null:
				feixe.reparent(sucessor)
			else:
				feixe.set_physics_process(false)
				feixe.queue_free()
	cristal.play(&"quebra")


func _buscar_pilar_para_feixes() -> Node2D:
	if emite_feixes:
		for pilar in get_tree().get_nodes_in_group("pilares_luz"):
			if pilar.get_parent() == fase and not pilar.morto and not pilar.emite_feixes:
				return pilar
	return null


func _ao_terminar_animacao_cristal() -> void:
	if morto:
		queue_free()
	else:
		cristal.play(&"parado")


func _lancar_ataque() -> void:
	var limites: Rect2 = fase.limites_arena().grow(MARGEM_FEIXES)
	var invertido := _ataque % (ATAQUES_POR_SEQUENCIA * 2) >= ATAQUES_POR_SEQUENCIA
	match _ataque % ATAQUES_POR_SEQUENCIA:
		0:
			if invertido:
				_marcar_faixa(limites, Vector2.ZERO, Vector2(0.33, 1))
				_marcar_faixa(limites, Vector2(0.67, 0), Vector2(0.33, 1))
			else:
				_lancar_feixes_mirados(limites)
		1:
			var altura_topo := 0.40 if invertido else 0.26
			var inicio_base := altura_topo + 0.34
			_marcar_faixa(limites, Vector2.ZERO, Vector2(1, altura_topo))
			_marcar_faixa(limites, Vector2(0, inicio_base), Vector2(1, 1.0 - inicio_base))
		2:
			for x in [0.0, 0.39, 0.78]:
				_marcar_faixa(limites, Vector2(x, 0), Vector2(0.22, 1))
		3:
			var x_topo := 0.50 if invertido else 0.0
			var x_oposto := 0.50 - x_topo
			_marcar_faixa(limites, Vector2(x_topo, 0), Vector2(0.50, 0.42))
			_marcar_faixa(limites, Vector2(x_oposto, 0), Vector2(0.50, 0.20))
			_marcar_faixa(limites, Vector2(x_oposto, 0.56), Vector2(0.50, 0.44))
	_ataque += 1


func _lancar_feixes_mirados(limites: Rect2, perseguir := false) -> void:
	var tamanho := Vector2.ONE * raio_feixe_perseguidor * 2.0 if perseguir else limites.size * Vector2(0.36, 0.68)
	for jogador in Jogo.jogadores_vivos():
		if not jogador.entrando:
			var area := Rect2(jogador.global_position - tamanho / 2.0, tamanho)
			var feixe = _marcar(area if perseguir else area.intersection(limites))
			if perseguir:
				feixe.tempo_aviso += TEMPO_EXTRA_PERSEGUIDOR
				feixe.seguir(jogador, raio_feixe_perseguidor)


func _marcar_faixa(limites: Rect2, inicio: Vector2, tamanho: Vector2) -> void:
	_marcar(Rect2(limites.position + inicio * limites.size, tamanho * limites.size))


func _marcar(area: Rect2) -> Panel:
	if cristal != null and cristal.animation == &"parado":
		cristal.play(&"pulso")
	var feixe = cena_feixe.instantiate()
	add_child(feixe)
	feixe.global_position = area.position
	feixe.size = area.size
	return feixe
