extends Node2D
## O gerenciador mantém a arena fechada enquanto este desafio estiver na cena.

const ATAQUES_POR_SEQUENCIA := 4

@export var vida_maxima := 8
@export var tempo_sobrevivencia := 0.0
@export var intervalo_ataques := 1.45
@export var intervalo_sequencias := 2.6
@export_range(0.0, 1.0) var chance_animacao_dano := 0.35
@export var cena_feixe: PackedScene
@export var objetivo := ""

@onready var fase = get_parent()
@onready var vida := float(vida_maxima)
@onready var _vida_maxima_atual := vida_maxima
@onready var barra := get_node_or_null("Vida") as ProgressBar
@onready var cristal := get_node_or_null("Cristal") as AnimatedSprite2D

var morto := false
var _decorrido := 0.0
var _ate_ataque := 0.8
var _ataque := 0
var _segundos_exibidos := -1


func _ready() -> void:
	if cristal != null:
		cristal.animation_finished.connect(_ao_terminar_animacao_cristal)
	if barra != null:
		_atualizar_vida_coop()
		Jogo.jogador_entrou.connect(_atualizar_vida_coop)
		Jogo.jogador_saiu.connect(_atualizar_vida_coop)
		fase.hud.mostrar_aviso(objetivo, 2.5)


func _atualizar_vida_coop(_jogador = null) -> void:
	if morto:
		return
	var nova_maxima := vida_maxima * (2 if Jogo.p2_ativo else 1)
	# Mantém a porcentagem de vida quando o P2 entra ou sai.
	vida *= float(nova_maxima) / _vida_maxima_atual
	_vida_maxima_atual = nova_maxima
	barra.max_value = nova_maxima
	barra.value = vida


func _physics_process(delta: float) -> void:
	if morto or fase.fim_de_jogo:
		return

	_decorrido += delta
	_ate_ataque -= delta
	if tempo_sobrevivencia > 0.0:
		var limites: Rect2 = fase.limites_arena()
		for jogador in Jogo.jogadores_vivos():
			if not jogador.entrando and jogador.global_position.x >= limites.end.x:
				_concluir()
				return
		var restante := ceili(tempo_sobrevivencia - _decorrido)
		if restante <= 0:
			_concluir()
			return
		if restante != _segundos_exibidos:
			_segundos_exibidos = restante
			fase.hud.mostrar_aviso(objetivo % restante)
		if tempo_sobrevivencia - _decorrido < 1.15:
			return

	if _ate_ataque <= 0.0:
		_lancar_ataque()
		_ate_ataque = intervalo_sequencias if _ataque % ATAQUES_POR_SEQUENCIA == 0 else intervalo_ataques


func receber_dano(dano: float) -> void:
	if morto or barra == null or dano <= 0.0:
		return
	vida = maxf(0.0, vida - ceili(dano))
	barra.value = vida
	Audio.tocar("dano_inimigo")
	if vida == 0:
		Combate.tremer(6.0)
		_concluir()
	elif cristal != null and cristal.animation == &"parado" and randf() < chance_animacao_dano:
		cristal.play(&"dano")


func _concluir() -> void:
	morto = true
	fase.hud.esconder_aviso()
	if cristal == null:
		queue_free()
		return

	$Colisao.set_deferred("disabled", true)
	barra.hide()
	for feixe in get_children():
		if feixe is Panel:
			feixe.set_physics_process(false)
			feixe.queue_free()
	cristal.play(&"quebra")


func _ao_terminar_animacao_cristal() -> void:
	if morto:
		queue_free()
	else:
		cristal.play(&"parado")


func _lancar_ataque() -> void:
	# Inclui os pés de quem está encostado nas bordas direita e inferior.
	var limites: Rect2 = fase.limites_arena().grow(1.0)
	var invertido := _ataque % (ATAQUES_POR_SEQUENCIA * 2) >= ATAQUES_POR_SEQUENCIA
	match _ataque % ATAQUES_POR_SEQUENCIA:
		0:
			if invertido:
				_marcar_faixa(limites, Vector2(0.12, 0), Vector2(0.33, 1))
				_marcar_faixa(limites, Vector2(0.55, 0), Vector2(0.33, 1))
			else:
				var tamanho := limites.size * Vector2(0.36, 0.68)
				for jogador in Jogo.jogadores_vivos():
					if not jogador.entrando:
						var area := Rect2(jogador.global_position - tamanho / 2.0, tamanho)
						_marcar(area.intersection(limites))
		1:
			var altura_topo := 0.40 if invertido else 0.26
			var inicio_base := altura_topo + 0.34
			_marcar_faixa(limites, Vector2.ZERO, Vector2(1, altura_topo))
			_marcar_faixa(limites, Vector2(0, inicio_base), Vector2(1, 1.0 - inicio_base))
		2:
			for x in [0.12, 0.39, 0.66]:
				_marcar_faixa(limites, Vector2(x, 0), Vector2(0.22, 1))
		3:
			var x_topo := 0.50 if invertido else 0.0
			_marcar_faixa(limites, Vector2(x_topo, 0), Vector2(0.50, 0.42))
			_marcar_faixa(limites, Vector2(0.50 - x_topo, 0.56), Vector2(0.50, 0.44))
	_ataque += 1


func _marcar_faixa(limites: Rect2, inicio: Vector2, tamanho: Vector2) -> void:
	_marcar(Rect2(limites.position + inicio * limites.size, tamanho * limites.size))


func _marcar(area: Rect2) -> void:
	var feixe = cena_feixe.instantiate()
	add_child(feixe)
	feixe.global_position = area.position
	feixe.size = area.size
