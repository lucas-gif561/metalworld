extends Boss
## Boss 3 — MODELO. Troque à vontade: é só um exemplo funcionando.
##
## Ideias de como mexer:
##   - trocar o sprite (AnimatedSprite2D em chefe_3.tscn)
##   - criar ataques novos aqui e chamá-los no ciclo_ataques()
##   - usar outro projétil (exporte uma PackedScene nova)

@export var gotas_por_chuva = 8


func ciclo_ataques():
	await esperar(2.0)

	while pode_atacar():
		await chuva()
		await esperar(1.5)

		for i in range(2):
			if not pode_atacar():
				return
			leque_no_mais_proximo()
			await esperar(0.8)

		await esperar(2.0)


## Tiros caindo do alto em posições sorteadas
func chuva():
	_conjurar()
	for i in range(gotas_por_chuva):
		if not pode_atacar():
			return
		var gota = criar_projetil(Vector2.DOWN)
		gota.global_position = Vector2(randf_range(80.0, 1070.0), 70.0)
		await esperar(0.15)


## Leque de 3 tiros no jogador mais perto
func leque_no_mais_proximo():
	var mira = alvo_mais_proximo()
	if mira == null:
		return
	_conjurar()
	var direcao = (mira.global_position - global_position).normalized()
	for angulo in [-15, 0, 15]:
		criar_projetil(direcao.rotated(deg_to_rad(angulo)))
