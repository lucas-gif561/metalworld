extends Area2D

const QUANTIDADE_BALAS = 8

@export var velocidade: float = 320.0
@export var distancia_saida_balas: float = 30.0
@export var distancia_saida_jogador: float = 60.0
@export var tempo_vida_balas: float = 2.5
@export var cena_particulas: PackedScene
@export var cena_bala: PackedScene

var direcao: Vector2 = Vector2.RIGHT
var dano: int = 3
var estourou = false
var alcance: float = INF
var percorrido: float = 0.0


func _ready() -> void:
	body_entered.connect(_ao_colidir)


func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta
	percorrido += velocidade * delta

	if percorrido >= alcance or not get_tree().current_scene.limites_arena().has_point(global_position):
		estourar(global_position, distancia_saida_balas)


func _ao_colidir(corpo) -> void:
	if corpo.is_in_group("jogador") and not estourou:
		corpo.receber_dano(dano)
		# As balas nascem em volta do corpo para nao serem consumidas por ele
		estourar(corpo.global_position, distancia_saida_jogador)


func estourar(centro: Vector2, distancia_saida: float) -> void:
	if estourou:
		return

	estourou = true
	Audio.tocar("granada")

	var cena_atual = get_tree().current_scene

	var particulas = cena_particulas.instantiate()
	particulas.position = global_position
	particulas.finished.connect(particulas.queue_free)
	cena_atual.add_child.call_deferred(particulas)

	for i in range(QUANTIDADE_BALAS):
		var bala_direcao = Vector2.RIGHT.rotated(TAU * i / QUANTIDADE_BALAS)
		var bala = cena_bala.instantiate()
		bala.position = centro + bala_direcao * distancia_saida
		bala.direcao = bala_direcao
		bala.tempo_vida = tempo_vida_balas
		cena_atual.add_child.call_deferred(bala)

	queue_free()
