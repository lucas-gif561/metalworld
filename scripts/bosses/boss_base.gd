class_name Boss
extends Node2D
## Modelo comum dos bosses + caixa de ferramentas de ataques.
##
## Para criar um boss novo:
##   1. Cena com um AnimatedSprite2D (animações: idle, cast, hurt, death;
##      opcionais: ajoelhar e descanso, usadas pelo descansar())
##   2. Script com "extends Boss"
##   3. Escreva ciclo_ataques(): um laço com os ataques, usando
##      "while pode_atacar():" e "await esperar(segundos)".
##
## Ataques prontos (é só chamar com await dentro do ciclo_ataques):
##   rajada(), leque(), area_no_chao(), trilha_no_chao(), espiral(),
##   corredor(), invocar_capangas(), teleporte(), ativar_escudo(), descansar()
## Cada um usa as cenas exportadas abaixo; deixe vazia a que não usar.
## O boss 1 (scripts/bosses/boss.gd) usa todos, como exemplo.
##
## O boss só perde vida pelo Riff (a arena, BossFight.gd, cuida disso).
## Para mirar: alvo() devolve um jogador vivo sorteado e
## alvo_mais_proximo() o mais perto do boss. Ambos podem ser null.

signal vida_atualizada(vida)
signal derrotado
signal anuncio(texto) # aviso na tela (a arena mostra no HUD)
signal fase_avancou
signal dano_recebido(valor)

const COR_ESCUDO = Color(0.5, 0.8, 1.0)

@export var vida_maxima: int = 100

@export_group("Cenas dos ataques")
@export var cena_projetil: PackedScene
## Círculo no chão (aviso e depois dano). Usado por area, trilha e corredor
@export var cena_ataque_area: PackedScene
## Inimigo invocado por invocar_capangas()
@export var cena_capanga: PackedScene
## Runa que segura o escudo (quebra no soco)
@export var cena_runa: PackedScene
## Partículas do teleporte e das invocações
@export var cena_particulas: PackedScene

@export_group("Fases")
## Liga as fases: abaixo de 66% e 33% da vida o boss enfurece (ataca mais rápido)
@export var usar_fases := false
## Com fases, o dano do Riff é calibrado para um Riff bom valer uma fase inteira
@export var perfects_por_fase: int = 6
@export var goods_por_fase: int = 9
## Ao mudar de fase, levanta o escudo (precisa de cena_runa)
@export var escudo_ao_mudar_fase := true

@export_group("Riff")
## Notas vermelhas que machucam quem tocar (sempre vêm com uma normal junto)
@export var usar_nota_maldita := false
@export var fase_nota_maldita: int = 2

@export_group("Posições")
@export var pontos_teleporte: Array[Vector2] = [Vector2(470, 150), Vector2(576, 160), Vector2(682, 150)]
@export var pontos_runa: Array[Vector2] = [Vector2(220, 340), Vector2(932, 340), Vector2(576, 400)]
@export var pontos_capanga: Array[Vector2] = [Vector2(220, 300), Vector2(932, 300)]
@export var maximo_capangas: int = 3
@export var duracao_descanso: float = 4.0

@onready var sprite = $AnimatedSprite2D

var atacando: bool = false
var vida_atual: int
var vida_referencia: int
var fase: int = 1
var escudo_ativo: bool = false
var descansando: bool = false
var runas_restantes: int = 0
var tween_teleporte: Tween
var tween_sinal: Tween
var sinal_riff: Label


func _ready() -> void:
	add_to_group("boss")
	vida_atual = vida_maxima
	vida_referencia = vida_maxima
	sprite.animation_finished.connect(_ao_terminar_animacao)
	_criar_sinal_riff()


## Sobrescreva com o padrão de ataques do boss
func ciclo_ataques() -> void:
	pass


# ---------------------------------------------------------------- Vida

func receber_dano(valor: int):
	if vida_atual <= 0 or escudo_ativo:
		return
	var vida_antes = vida_atual
	vida_atual = max(vida_atual - valor, 0)
	vida_atualizada.emit(vida_atual)
	dano_recebido.emit(vida_antes - vida_atual)

	if vida_atual <= 0:
		morrer()
		return

	sprite.stop()
	sprite.play("hurt")
	sprite.modulate = Color(1, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.15)
	_atualizar_fase()


func curar(valor: int) -> void:
	if vida_atual <= 0:
		return
	vida_atual = mini(vida_atual + valor, vida_maxima)
	vida_atualizada.emit(vida_atual)


## Cabo de força: o boss começa no meio da barra e as fases contam a partir daí
func iniciar_cabo_de_forca() -> void:
	vida_atual = vida_maxima / 2
	vida_referencia = vida_atual
	vida_atualizada.emit(vida_atual)


func morrer():
	atacando = false
	_encerrar_descanso()
	if tween_teleporte:
		tween_teleporte.kill()
	modulate.a = 1.0
	sprite.modulate = Color.WHITE
	sprite.self_modulate = Color.WHITE

	for capanga in get_tree().get_nodes_in_group("capangas"):
		capanga.queue_free()
	for runa in get_tree().get_nodes_in_group("runas"):
		runa.queue_free()

	Audio.tocar("granada", 0.0)
	sprite.stop()
	sprite.play("death")
	await sprite.animation_finished
	derrotado.emit()


func _ao_terminar_animacao():
	if vida_atual > 0:
		sprite.play("descanso" if descansando and sprite.sprite_frames.has_animation("descanso") else "idle")


func _conjurar():
	Audio.tocar("boss_conjura")
	sprite.stop()
	sprite.play("cast")


# ---------------------------------------------------------------- Fases

func _atualizar_fase():
	if not usar_fases:
		return

	var porcentagem = float(vida_atual) / vida_referencia
	var nova_fase = 1 if porcentagem > 0.66 else (2 if porcentagem > 0.33 else 3)

	if nova_fase > fase:
		fase = nova_fase
		if not (escudo_ao_mudar_fase and ativar_escudo("FASE %d! " % fase)):
			anuncio.emit("FASE %d! O boss enfureceu!" % fase)
		fase_avancou.emit()


## Com fases, os intervalos encurtam: fase 1 normal, 2 em 80%, 3 em 60%
func ritmo() -> float:
	return [1.0, 0.8, 0.6][fase - 1] if usar_fases else 1.0


## Dano de uma nota do Riff
func dano_da_nota(perfect: bool) -> int:
	if not usar_fases:
		return 3 if perfect else 1
	# 34% é a maior fatia entre as fases (de 100% até 66%)
	var fatia = vida_referencia * 0.34
	return ceili(fatia / (perfects_por_fase if perfect else goods_por_fase))


func nota_maldita_disponivel() -> bool:
	return usar_nota_maldita and (not usar_fases or fase >= fase_nota_maldita)


# ---------------------------------------------------------------- Utilidades

func pode_atacar() -> bool:
	return vida_atual > 0 and is_inside_tree() and not Jogo.todos_caidos()


## Um jogador vivo sorteado (null se todos caíram)
func alvo():
	return Jogo.jogador_aleatorio()


## O jogador vivo mais perto do boss (null se todos caíram)
func alvo_mais_proximo():
	return Jogo.jogador_mais_proximo(global_position)


## Espera alguns segundos (seguro mesmo se a fase for reiniciada no meio)
func esperar(segundos: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(segundos).timeout


## Igual a esperar(), mas encurta conforme a fase (ver ritmo())
func esperar_no_ritmo(segundos: float) -> void:
	await esperar(segundos * ritmo())


## Espera um ataque que usa "atacando = true" terminar
func esperar_fim_do_ataque() -> void:
	while atacando and is_inside_tree():
		await get_tree().process_frame


## Cria um projétil saindo do boss na direção dada
func criar_projetil(direcao: Vector2, cena: PackedScene = cena_projetil):
	if cena == null:
		return null
	var projetil = cena.instantiate()
	get_parent().add_child(projetil)
	projetil.global_position = global_position
	projetil.direcao = direcao
	return projetil


## Círculo no chão: avisa por tempo_aviso segundos e depois machuca quem estiver dentro
func criar_circulo(posicao: Vector2, dano: int = 2, tempo_aviso: float = 1.5, raio: float = 45.0):
	if cena_ataque_area == null:
		return null
	var area = cena_ataque_area.instantiate()
	area.dano = dano
	area.tempo_aviso = tempo_aviso
	area.raio = raio
	area.position = posicao
	get_parent().add_child(area)
	return area


func criar_particulas(posicao: Vector2):
	if cena_particulas == null:
		return
	var particulas = cena_particulas.instantiate()
	particulas.position = posicao
	particulas.finished.connect(particulas.queue_free)
	get_parent().add_child(particulas)


# ---------------------------------------------------------------- Ataques prontos

## 6 tiros mirados, um a cada 0,4 s
func rajada(tiros := 6, intervalo := 0.4) -> void:
	for i in range(tiros):
		var mira = alvo()
		if not pode_atacar() or mira == null:
			return
		_conjurar()
		criar_projetil((mira.global_position - global_position).normalized())
		await esperar(intervalo)


## Leque de tiros abertos na direção de um jogador
func leque(angulos := [-40, -20, 0, 20, 40]) -> void:
	var mira = alvo()
	if not pode_atacar() or mira == null:
		return
	_conjurar()
	var direcao_central = (mira.global_position - global_position).normalized()
	for angulo in angulos:
		criar_projetil(direcao_central.rotated(deg_to_rad(angulo)))


## Um círculo grande (raio 90, o dobro dos outros) embaixo de um jogador
func area_no_chao(raio := 90.0) -> void:
	var mira = alvo()
	if not pode_atacar() or mira == null:
		return
	_conjurar()
	criar_circulo(mira.global_position, 2, 1.5, raio)
	await esperar(1.5)


## Rastro de círculos rápidos seguindo os passos de um jogador
func trilha_no_chao(circulos := 6) -> void:
	var mira = alvo()
	for i in range(circulos):
		if not pode_atacar() or not Jogo.esta_vivo(mira):
			return
		_conjurar()
		criar_circulo(mira.global_position, 1, 0.9)
		await esperar(0.3)


## Dois fios de tiros girando em espiral
func espiral(passos := 40) -> void:
	_conjurar()
	for i in range(passos):
		if not pode_atacar():
			return
		var angulo = deg_to_rad(i * 25.0)
		criar_projetil(Vector2.RIGHT.rotated(angulo))
		criar_projetil(Vector2.LEFT.rotated(angulo))
		await esperar(0.08)


## Colunas de círculos varrendo a arena, cada uma com um buraco para passar
func corredor() -> void:
	var colunas = [110, 300, 490, 680, 870, 1060]
	var linhas = [120, 205, 290, 375, 460, 545]
	var mira = alvo()

	# Começa do lado oposto ao jogador e varre na direção dele
	if mira and mira.global_position.x < global_position.x:
		colunas.reverse()

	for x in colunas:
		if not pode_atacar():
			return
		_conjurar()
		var buraco = randi_range(2, linhas.size() - 1)
		for i in range(linhas.size()):
			if i != buraco:
				criar_circulo(Vector2(x, linhas[i]), 2, 1.0)
		await esperar(0.8)


## Chama inimigos (cena_capanga) nos pontos_capanga, até maximo_capangas vivos
func invocar_capangas() -> void:
	if cena_capanga == null:
		return
	_conjurar()
	var vivos = get_tree().get_nodes_in_group("capangas").size()

	for ponto in pontos_capanga:
		if vivos >= maximo_capangas:
			return
		# Dois corpos exatamente no mesmo ponto travam na física
		var nascimento = ponto + Vector2(randf_range(-50.0, 50.0), randf_range(-50.0, 50.0))
		var capanga = cena_capanga.instantiate()
		capanga.add_to_group("capangas")
		capanga.position = nascimento
		get_parent().add_child(capanga)
		criar_particulas(nascimento)
		vivos += 1


## Some e reaparece em outro dos pontos_teleporte
func teleporte() -> void:
	var destinos = pontos_teleporte.filter(func(p): return p.distance_to(global_position) > 1.0)
	if destinos.is_empty():
		return

	Audio.tocar("teleporte")
	criar_particulas(global_position)
	tween_teleporte = create_tween()
	tween_teleporte.tween_property(self, "modulate:a", 0.0, 0.25)
	await tween_teleporte.finished

	global_position = destinos.pick_random()
	criar_particulas(global_position)

	tween_teleporte = create_tween()
	tween_teleporte.tween_property(self, "modulate:a", 1.0, 0.25)
	await tween_teleporte.finished


## Escudo: o Riff não fere até os jogadores quebrarem as runas no soco.
## Devolve true se o escudo subiu agora.
func ativar_escudo(prefixo := "") -> bool:
	if escudo_ativo or cena_runa == null:
		return false

	escudo_ativo = true
	Audio.tocar("escudo", 0.0)
	runas_restantes = pontos_runa.size()
	sprite.self_modulate = COR_ESCUDO

	for ponto in pontos_runa:
		var runa = cena_runa.instantiate()
		runa.position = ponto
		runa.quebrada.connect(_ao_quebrar_runa)
		get_parent().add_child(runa)

	anuncio.emit(prefixo + "Escudo ativo! Quebrem as runas na porrada (J / X)")
	return true


func _ao_quebrar_runa():
	runas_restantes -= 1
	if runas_restantes <= 0:
		escudo_ativo = false
		sprite.self_modulate = Color.WHITE
		anuncio.emit("Escudo quebrado! Voltem ao Riff!")


## O boss se ajoelha e para de atacar por duracao_descanso: a hora do Riff
func descansar() -> void:
	# Com escudo as notas não ferem, então o aviso enganaria os jogadores
	if escudo_ativo or not pode_atacar():
		return

	descansando = true
	sprite.stop()
	sprite.play("ajoelhar" if sprite.sprite_frames.has_animation("ajoelhar") else "idle")
	sinal_riff.modulate.a = 1.0
	sinal_riff.show()

	tween_sinal = create_tween().set_loops()
	tween_sinal.tween_property(sinal_riff, "modulate:a", 0.35, 0.3)
	tween_sinal.tween_property(sinal_riff, "modulate:a", 1.0, 0.3)

	var restante = duracao_descanso * ritmo()
	while restante > 0.0 and pode_atacar() and not escudo_ativo:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		restante -= get_process_delta_time()

	_encerrar_descanso()
	if vida_atual > 0:
		sprite.play("idle")


func _encerrar_descanso():
	descansando = false
	if sinal_riff:
		sinal_riff.hide()
	if tween_sinal:
		tween_sinal.kill()


func _criar_sinal_riff():
	sinal_riff = Label.new()
	sinal_riff.text = "RIFF!\nESPAÇO / LB"
	sinal_riff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sinal_riff.size = Vector2(200, 60)
	sinal_riff.position = Vector2(-100, -150)
	sinal_riff.z_index = 5
	sinal_riff.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	sinal_riff.add_theme_color_override("font_outline_color", Color.BLACK)
	sinal_riff.add_theme_constant_override("outline_size", 8)
	sinal_riff.add_theme_font_size_override("font_size", 24)
	sinal_riff.hide()
	add_child(sinal_riff)
