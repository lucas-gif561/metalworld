extends Node
## Cria as ondas de inimigos de cada arena da rua.
##
## Lê a árvore Spawns/ArenaN/OndaN/<pontos>. Cada ponto pode ser um
## PontoSpawn com a cena do inimigo; sem cena, usa cena_inimigo (padrão).
## A quantidade de arenas e de ondas sai da própria cena.

signal onda_iniciada(arena, onda, total_ondas)
signal arena_concluida

@export var cena_inimigo: PackedScene
@export var intervalo_ondas = 1.5
## Quem nasce atrás (à esquerda da tela, por onde o jogador acabou de entrar)
## nasce pelo menos isso fora da tela, para não surgir em cima dele.
## Vale também para pontos colados na borda esquerda.
@export var margem_atras = 260.0

@onready var spawns = $"../Spawns"

var arena_atual = 1
var onda_atual = 1
var ondas_por_arena = 1
var inimigos_vivos = 0
var arena_liberada = false
var esperando_onda = false
var reiniciando = false


func _ready():
	call_deferred("iniciar_arena", 1)


func quantidade_arenas() -> int:
	return spawns.get_child_count()


func iniciar_arena(numero):
	arena_atual = numero
	onda_atual = 1
	ondas_por_arena = _arena().get_child_count()
	arena_liberada = false
	esperando_onda = false

	criar_onda()


func _arena() -> Node:
	return spawns.get_node("Arena" + str(arena_atual))


func criar_onda():
	var onda = _arena().get_node("Onda" + str(onda_atual))

	inimigos_vivos = 0

	print("Arena ", arena_atual, " - Onda ", onda_atual)
	onda_iniciada.emit(arena_atual, onda_atual, ondas_por_arena)

	for ponto in onda.get_children():
		var cena = ponto.get("cena_inimigo")
		if cena == null:
			cena = cena_inimigo
		if cena == null:
			push_warning("Ponto %s sem inimigo e GerenciadorOndas sem cena_inimigo" % ponto.name)
			continue

		_criar_inimigo(cena, _afastar_de_tras(ponto.global_position))

	print("Inimigos na onda: ", inimigos_vivos)

	if inimigos_vivos == 0:
		call_deferred("inimigo_morreu", true)


## Empurra para longe os pontos que ficariam colados na borda esquerda da tela
func _afastar_de_tras(posicao: Vector2) -> Vector2:
	var fase = get_parent()
	if not fase.has_method("limites_arena"):
		return posicao
	# limites_arena() tem 40 px de folga para dentro da tela
	var borda_esquerda = fase.limites_arena().position.x - 40.0
	if posicao.x < borda_esquerda + 60.0:
		posicao.x = minf(posicao.x, borda_esquerda - margem_atras)
	return posicao


func invocar_inimigo(cena: PackedScene, posicao: Vector2) -> Node2D:
	if reiniciando or esperando_onda or arena_liberada or inimigos_vivos <= 0:
		return null
	return _criar_inimigo(cena, posicao)


func _criar_inimigo(cena: PackedScene, posicao: Vector2) -> Node2D:
	var inimigo = cena.instantiate()
	inimigos_vivos += 1
	inimigo.tree_exited.connect(inimigo_morreu)
	get_parent().add_child(inimigo)
	inimigo.global_position = posicao
	return inimigo


func inimigo_morreu(sem_inimigos := false):
	if reiniciando or not is_inside_tree():
		return

	if not sem_inimigos:
		inimigos_vivos -= 1

	if inimigos_vivos <= 0 and not esperando_onda:
		if onda_atual < ondas_por_arena:
			esperando_onda = true
			iniciar_proxima_onda()
		else:
			arena_liberada = true
			print("ARENA LIBERADA!")
			arena_concluida.emit()


func iniciar_proxima_onda():
	if reiniciando or not is_inside_tree():
		return

	await get_tree().create_timer(intervalo_ondas, false).timeout

	if reiniciando or not is_inside_tree():
		return

	onda_atual += 1
	esperando_onda = false

	criar_onda()


func _exit_tree():
	reiniciando = true
