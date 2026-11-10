extends Node

signal onda_iniciada(arena, onda, total_ondas)
signal arena_concluida

@export var cena_inimigo: PackedScene
@export var cena_inimigo_rapido: PackedScene
@export var cena_inimigo_grande: PackedScene
@export var cena_inimigo_atirador: PackedScene

@export var ondas_por_arena = 2
@export var intervalo_ondas = 1.5

@onready var spawns = $"../Spawns"

var arena_atual = 1
var onda_atual = 1
var inimigos_vivos = 0
var arena_liberada = false
var esperando_onda = false
var reiniciando = false

func _ready():
	call_deferred("iniciar_arena", 1)


func iniciar_arena(numero):
	if cena_inimigo == null:
		print("Configure a cena do inimigo!")
		return

	arena_atual = numero
	onda_atual = 1
	arena_liberada = false
	esperando_onda = false

	criar_onda()


func criar_onda():
	var arena = spawns.get_node("Arena" + str(arena_atual))
	var onda = arena.get_node("Onda" + str(onda_atual))
	var pontos = onda.get_children()

	inimigos_vivos = 0

	print("Arena ", arena_atual, " - Onda ", onda_atual)
	onda_iniciada.emit(arena_atual, onda_atual, ondas_por_arena)

	for i in range(pontos.size()):
		var ponto = pontos[i]
		var tipo_inimigo = escolher_inimigo(i)

		var inimigo = tipo_inimigo.instantiate()

		get_parent().add_child(inimigo)
		inimigo.global_position = ponto.global_position

		inimigos_vivos += 1
		inimigo.tree_exited.connect(inimigo_morreu)

	print("Inimigos na onda: ", inimigos_vivos)


func escolher_inimigo(indice):
	match arena_atual:
		1:
			# Arena 1
			if onda_atual == 1:
				match indice:
					0, 2:
						return cena_inimigo
					1, 3:
						return cena_inimigo_rapido

			elif onda_atual == 2:
				match indice:
					0, 3:
						return cena_inimigo_rapido
					1, 2:
						return cena_inimigo

		2:
			# Arena 2
			if onda_atual == 1:
				match indice:
					0:
						if cena_inimigo_atirador != null:
							return cena_inimigo_atirador
					1, 3:
						if cena_inimigo_rapido != null:
							return cena_inimigo_rapido
					2:
						return cena_inimigo

			elif onda_atual == 2:
				match indice:
					0, 2:
						if cena_inimigo_atirador != null:
							return cena_inimigo_atirador
					1, 3:
						return cena_inimigo

		3:
			# Arena 3
			if onda_atual == 1:
				match indice:
					0:
						if cena_inimigo_grande != null:
							return cena_inimigo_grande
					1, 3:
						if cena_inimigo_rapido != null:
							return cena_inimigo_rapido
					2:
						return cena_inimigo

			elif onda_atual == 2:
				match indice:
					0:
						if cena_inimigo_grande != null:
							return cena_inimigo_grande
					1, 2:
						return cena_inimigo
					3:
						if cena_inimigo_rapido != null:
							return cena_inimigo_rapido

	return cena_inimigo


func inimigo_morreu():
	if reiniciando or not is_inside_tree():
		return

	inimigos_vivos -= 1

	print("Inimigos restantes: ", inimigos_vivos)

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

	print("Preparando próxima onda...")

	await get_tree().create_timer(intervalo_ondas).timeout

	if reiniciando or not is_inside_tree():
		return

	onda_atual += 1
	esperando_onda = false

	criar_onda()

func _exit_tree():
	reiniciando = true
