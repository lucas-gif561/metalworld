extends CharacterBody2D
## O corpo bate no teto e no piso. A área interna detecta a Hurtbox do jogador.

signal alcancou_lateral

@export var dano: int = 1
@export var tempo_vida: float = 2.0
@export_range(0, 4) var maximo_quiques: int = 2

var direcao: Vector2
var velocidade: float
var limite_lateral: float

var _tempo_restante: float
var _quiques := 0

@onready var faiscas: CPUParticles2D = $Faiscas


func _ready() -> void:
	_tempo_restante = tempo_vida


func direcao_com_ricochetes(origem: Vector2, destino: Vector2, paredes: Array[CollisionShape2D]) -> Vector2:
	return calcular_direcao_com_ricochetes(origem, destino, paredes, raio_ricochete())


func raio_ricochete() -> float:
	return ($ColisaoRicochete.shape as CircleShape2D).radius


static func altura_ricochete(origem_y: float, parede: CollisionShape2D, raio: float) -> float:
	var retangulo = parede.shape as RectangleShape2D
	var lado = 1.0 if origem_y > parede.global_position.y else -1.0
	var borda_y = parede.to_global(Vector2(0.0, lado * retangulo.size.y * 0.5)).y
	return borda_y + lado * raio


static func calcular_direcao_com_ricochetes(
	origem: Vector2, destino: Vector2, paredes: Array[CollisionShape2D], raio: float
) -> Vector2:
	# Espelha o alvo a partir do último quique para achar a direção de saída.
	for i in range(paredes.size() - 1, -1, -1):
		var ponto_de_rebate_y = altura_ricochete(origem.y, paredes[i], raio)
		destino.y = 2.0 * ponto_de_rebate_y - destino.y
	return origem.direction_to(destino)


func _physics_process(delta: float) -> void:
	var distancia_lateral = (limite_lateral - global_position.x) / direcao.x
	var distancia = minf(velocidade * minf(delta, _tempo_restante), distancia_lateral)
	var movimento = _calcular_movimento(maxf(0.0, distancia))
	_tempo_restante -= delta

	while not movimento.is_zero_approx():
		var colisao = move_and_collide(movimento)
		if colisao == null:
			break
		if _quiques >= maximo_quiques:
			_dissipar()
			return

		_quiques += 1
		var normal = colisao.get_normal()
		direcao = direcao.bounce(normal)
		movimento = colisao.get_remainder().bounce(normal)

	if distancia >= distancia_lateral:
		alcancou_lateral.emit()
		_dissipar()
	elif _tempo_restante <= 0.0:
		_dissipar()


func _calcular_movimento(distancia: float) -> Vector2:
	return direcao * distancia


func _ao_entrar_na_area(area: Area2D) -> void:
	if is_queued_for_deletion() or not area.is_in_group("hurtbox_jogador"):
		return
	area.get_parent().receber_dano(dano)
	queue_free()


func _dissipar() -> void:
	# As faíscas terminam de tocar depois que o projétil deixa a árvore.
	faiscas.reparent(get_parent().get_parent())
	faiscas.modulate = modulate
	faiscas.finished.connect(faiscas.queue_free)
	faiscas.emitting = true
	queue_free()
