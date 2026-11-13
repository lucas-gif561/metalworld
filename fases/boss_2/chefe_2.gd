extends Boss
## Boss 2 — MODELO. Troque à vontade: é só um exemplo funcionando.
##
## Ideias de como mexer:
##   - trocar o sprite (AnimatedSprite2D em chefe_2.tscn)
##   - criar ataques novos aqui e chamá-los no ciclo_ataques()
##   - usar outro projétil (exporte uma PackedScene nova)

@export var tiros_no_anel = 10


func ciclo_ataques():
	await esperar(2.0)

	while pode_atacar():
		ataque_anel()
		await esperar(2.5)

		for i in range(3):
			if not pode_atacar():
				return
			tiro_mirado()
			await esperar(0.5)

		await esperar(2.0)


## Anel de tiros em todas as direções
func ataque_anel():
	_conjurar()
	var giro = randf() * TAU
	for i in range(tiros_no_anel):
		criar_projetil(Vector2.RIGHT.rotated(giro + TAU * i / tiros_no_anel))


## Um tiro na direção de um dos jogadores
func tiro_mirado():
	var mira = alvo()
	if mira == null:
		return
	_conjurar()
	criar_projetil((mira.posicao_do_corpo() - global_position).normalized())
