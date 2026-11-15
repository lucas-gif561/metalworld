extends Boss
## Boss 1: o guitarrista do galpão, com todos os ataques originais + os novos, em 3 fases.
## Serve de exemplo para os bosses 2 e 3 (veja a lista de ataques em boss_base.gd).

@export_group("Corrida no palco")
## Chance de correr quando chega a vez da corrida (no lugar do teleporte).
## Ao passar de fase ele sempre corre, logo depois do ataque em andamento.
@export_range(0.0, 1.0) var chance_correr := 0.75
@export var velocidade_corrida := 320.0

@export_group("Microfonia")
## Aviso da microfonia grande (área quádrupla), do círculo aparecer até o dano
@export var tempo_microfonia_grande := 1.2
## Aviso de cada círculo da trilha que persegue os jogadores
@export var tempo_microfonia_trilha := 0.7

## Animação de cada ataque (cai no "cast" se a animação não existir)
const ANIMACAO_DO_ATAQUE = {
	"rajada": "arremessar",
	"leque": "arremessar",
	"espiral": "girar",
}

var correndo := false
var correr_ao_terminar_ataque := false
var animacao_ataque := "cast"


func _ready() -> void:
	super()
	fase_avancou.connect(func(): correr_ao_terminar_ataque = true)

# Ordem dos ataques: [ataque, fase mínima, pausa depois]
const ROTEIRO = [
	["rajada", 1, 2.0],
	["trilha", 1, 1.5],
	["leque", 1, 2.0],
	["descanso", 1, 1.0],
	["espiral", 2, 1.5],
	["corredor", 2, 2.0],
	["capangas", 2, 1.5],
	["correr", 2, 0.3],
	["escudo", 3, 1.0],
	["area", 1, 1.0],
	["descanso", 1, 1.0],
]


func ciclo_ataques():
	await esperar(2.0)

	while pode_atacar():
		for passo in ROTEIRO:
			if not pode_atacar():
				return
			if fase >= passo[1]:
				await _executar(passo[0])
				if correr_ao_terminar_ataque and pode_atacar():
					correr_ao_terminar_ataque = false
					await correr_no_palco(true)
				await esperar_no_ritmo(passo[2])


func _executar(nome: String) -> void:
	animacao_ataque = ANIMACAO_DO_ATAQUE.get(nome, "cast")
	match nome:
		"rajada":
			await rajada()
		"leque":
			await _leque_triplo()
		"area":
			await _area_quadrupla()
		"trilha":
			await trilha_no_chao()
		"espiral":
			# "girar" fica em loop enquanto a espiral dura; no fim volta ao idle
			await espiral()
			if vida_atual > 0 and sprite.animation == &"girar":
				sprite.play("idle")
		"corredor":
			await corredor()
		"capangas":
			invocar_capangas()
		"correr":
			await correr_no_palco()
		"escudo":
			ativar_escudo()
		"descanso":
			await descansar()


## Corrida no palco: em vez de teleportar, ele corre até outro dos três pontos
## do palco (esquerda, meio e direita, em pontos_teleporte). Só acontece em
## chance_correr das vezes, a não ser que seja obrigatória (troca de fase).
## A arte corre para a direita; para a esquerda, espelha.
func correr_no_palco(obrigatoria := false) -> void:
	if not sprite.sprite_frames.has_animation("correr"):
		return
	if not obrigatoria and randf() >= chance_correr:
		return
	var destinos = pontos_teleporte.filter(func(p): return p.distance_to(global_position) > 1.0)
	if destinos.is_empty():
		return

	var destino: Vector2 = destinos.pick_random()
	correndo = true
	sprite.flip_h = destino.x < global_position.x
	sprite.play("correr")
	tween_teleporte = create_tween()
	tween_teleporte.tween_property(self, "global_position", destino, global_position.distance_to(destino) / velocidade_corrida)
	await tween_teleporte.finished

	correndo = false
	sprite.flip_h = false
	if vida_atual > 0:
		sprite.play("idle")


## Ajoelhado ou correndo, o golpe usa a animação certa em vez do "hurt" em pé
func receber_dano(valor: float):
	super(valor)
	if vida_atual <= 0 or sprite.animation != &"hurt":
		return
	if descansando and sprite.sprite_frames.has_animation("hurt_ajoelhado"):
		sprite.play("hurt_ajoelhado")
	elif correndo:
		sprite.play("correr")


## Descanso: no fim, ele se levanta (animação "levantar") em vez de pular direto
## para o idle. Só quando ele chegou a se ajoelhar (sem escudo e podendo atacar).
func descansar() -> void:
	var vai_ajoelhar = not escudo_ativo and pode_atacar()
	await super()
	if vai_ajoelhar and vida_atual > 0 and sprite.sprite_frames.has_animation("levantar"):
		sprite.play("levantar")


## Cada ataque toca a própria animação (arremessar, girar); os outros usam "cast"
func _conjurar():
	Audio.tocar("boss_conjura")
	sprite.stop()
	sprite.play(animacao_ataque if sprite.sprite_frames.has_animation(animacao_ataque) else "cast")


func morrer():
	correndo = false
	sprite.flip_h = false
	await super()


## Microfonia grande embaixo de um jogador, com aviso mais curto que o padrão
## (tempo_microfonia_grande). A animação acende até o dano no mesmo tempo.
func area_no_chao(raio := 90.0) -> void:
	var mira = alvo()
	if not pode_atacar() or mira == null:
		return
	_conjurar()
	criar_circulo(mira.global_position, 2, tempo_microfonia_grande, raio)
	await esperar(tempo_microfonia_grande)


## Microfonia que persegue: a trilha segue os dois jogadores ao mesmo tempo
## (um círculo embaixo de cada jogador vivo a cada passo), em vez de só um.
func trilha_no_chao(circulos := 6) -> void:
	for i in range(circulos):
		var vivos = Jogo.jogadores_vivos()
		if not pode_atacar() or vivos.is_empty():
			return
		_conjurar()
		for jogador in vivos:
			criar_circulo(jogador.global_position, 1, tempo_microfonia_trilha)
		await esperar(0.3)


## Parede de som: colunas inteiras de microfonia varrendo o chão livre do galpão
## (entre as caixas de som e abaixo do palco). Não há buraco: para escapar,
## fique no vão entre duas colunas.
func corredor() -> void:
	var colunas = [170, 340, 510, 680, 850, 1000]
	var linhas = [235, 310, 385, 460, 535, 600]
	var mira = alvo()

	if mira and mira.global_position.x < global_position.x:
		colunas.reverse()

	for x in colunas:
		if not pode_atacar():
			return
		_conjurar()
		for y in linhas:
			criar_circulo(Vector2(x, y), 2, 1.0)
		await esperar(0.8)


func _leque_triplo():
	for i in range(3):
		if not pode_atacar():
			return
		leque()
		if i < 2:
			await esperar_no_ritmo(0.7)


func _area_quadrupla():
	for i in range(4):
		if not pode_atacar():
			return
		await area_no_chao()
		if i < 3:
			await esperar_no_ritmo(0.5)
