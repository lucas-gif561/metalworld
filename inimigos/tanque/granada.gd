extends Area2D
## Granada do grandão: sai do cano, faz um arco com gravidade e estoura ao
## cair no chão, perto de onde o alvo estava. A sombra no chão mostra onde
## ela vai cair. Se acertar o corpo de alguém no caminho, estoura ali mesmo.
##
## O nó voa na posição visível (no ar); "chao_y" guarda a linha do chão
## (a altura dos pés de quem atirou), onde ela estoura.

const QUANTIDADE_BALAS = 8

## Velocidade na horizontal (px/s)
@export var velocidade: float = 450.0
## Puxa a granada para baixo (px/s²): maior = arco mais curto e rápido
@export var gravidade: float = 900.0
## Distância mínima e máxima (na horizontal) em que ela cai
@export var alcance_minimo: float = 160.0
@export var alcance_maximo: float = 480.0
@export var distancia_saida_balas: float = 30.0
## Ao cair, as balas saem nessa altura acima do chão (a do peito dos jogadores)
@export var altura_balas: float = 70.0
@export var distancia_saida_jogador: float = 60.0
@export var tempo_vida_balas: float = 2.5
## Explosão (estouro_granada.tscn) e estilhaços (estilhaco.tscn)
@export var cena_particulas: PackedScene
@export var cena_bala: PackedScene

var direcao: Vector2 = Vector2.RIGHT
var dano: int = 1
var estourou = false
## Linha do chão (y dos pés de quem atirou)
var chao_y: float = 0.0
## Quanto ela anda na horizontal até cair (definido por lancar)
var alcance: float = 320.0

var _velocidade_y: float = 0.0

@onready var sombra: Node2D = get_node_or_null("Sombra")
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	area_entered.connect(_ao_colidir)


## Chamado por quem atira, depois de posicionar a granada no cano.
## "distancia" é a distância horizontal até o alvo (vira o alcance, limitado).
func lancar(chao: float, distancia: float) -> void:
	chao_y = chao
	alcance = clampf(distancia, alcance_minimo, alcance_maximo)
	# Tempo de voo para chegar no alcance; a velocidade vertical inicial é a
	# que faz ela sair da altura do cano e tocar o chão nesse tempo
	var tempo = alcance / velocidade
	var altura = chao_y - global_position.y
	_velocidade_y = (altura - 0.5 * gravidade * tempo * tempo) / tempo
	_atualizar_sombra()


func _physics_process(delta: float) -> void:
	if estourou:
		return
	_velocidade_y += gravidade * delta
	var movimento = Vector2(direcao.x * velocidade, _velocidade_y)
	global_position += movimento * delta
	_atualizar_sombra()
	# A arte aponta para a direita: gira junto com o arco (de ponta-cabeça
	# não, por isso espelha na vertical quando vai para a esquerda)
	sprite.rotation = movimento.angle()
	sprite.flip_v = direcao.x < 0

	if global_position.y >= chao_y:
		global_position.y = chao_y
		estourar(global_position + Vector2(0, -altura_balas), distancia_saida_balas)
		return

	var limites = get_tree().current_scene.limites_arena()
	if global_position.x < limites.position.x or global_position.x > limites.end.x:
		estourar(Vector2(global_position.x, chao_y - altura_balas), distancia_saida_balas)


func _atualizar_sombra() -> void:
	if sombra:
		sombra.position.y = chao_y - global_position.y


func _ao_colidir(area) -> void:
	if area.is_in_group("hurtbox_jogador") and not estourou:
		area.get_parent().receber_dano(dano)
		# As balas nascem em volta do corpo para nao serem consumidas por ele
		estourar(area.global_position, distancia_saida_jogador)


func estourar(centro: Vector2, distancia_saida: float) -> void:
	if estourou:
		return

	estourou = true
	Audio.tocar("granada")
	Combate.tremer(6.0)

	var cena_atual = get_tree().current_scene

	# Explosão animada (AnimatedSprite2D): some sozinha quando a animação acaba
	var explosao = cena_particulas.instantiate()
	explosao.position = global_position
	explosao.animation_finished.connect(explosao.queue_free)
	cena_atual.add_child.call_deferred(explosao)

	for i in range(QUANTIDADE_BALAS):
		var bala_direcao = Vector2.RIGHT.rotated(TAU * i / QUANTIDADE_BALAS)
		var bala = cena_bala.instantiate()
		bala.position = centro + bala_direcao * distancia_saida
		bala.direcao = bala_direcao
		bala.tempo_vida = tempo_vida_balas
		cena_atual.add_child.call_deferred(bala)

	queue_free()
