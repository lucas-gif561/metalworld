extends Boss
## Boss 1: rajada mirada, leque de 5 tiros e círculos no chão.
## Serve de exemplo para os bosses 2 e 3.

@export var cena_ataque_area: PackedScene


func iniciar_rajada():
	if atacando or cena_projetil == null or not pode_atacar():
		return

	atacando = true

	for i in range(6):
		var mira = alvo()
		if not pode_atacar() or mira == null:
			break

		_conjurar()
		criar_projetil((mira.global_position - global_position).normalized())

		await esperar(0.4)

	atacando = false


func ataque_leque():
	var mira = alvo()
	if atacando or cena_projetil == null or not pode_atacar() or mira == null:
		return

	_conjurar()

	var direcao_central = (mira.global_position - global_position).normalized()

	for angulo in [-40, -20, 0, 20, 40]:
		criar_projetil(direcao_central.rotated(deg_to_rad(angulo)))


func ataque_area():
	var mira = alvo()
	if atacando or cena_ataque_area == null or not pode_atacar() or mira == null:
		return

	atacando = true
	_conjurar()

	var area = cena_ataque_area.instantiate()
	get_parent().add_child(area)

	area.global_position = mira.global_position

	await esperar(1.5)

	atacando = false


func ciclo_ataques():
	await esperar(2.0)

	while pode_atacar():
		iniciar_rajada()

		await esperar_fim_do_ataque()

		await esperar(2.0)

		for i in range(3):
			if not pode_atacar():
				return

			ataque_leque()

			if i < 2:
				await esperar(0.7)

		await esperar(2.0)

		for i in range(4):
			if not pode_atacar():
				return

			ataque_area()

			await esperar_fim_do_ataque()

			if i < 3:
				await esperar(0.5)

		await esperar(5.0)
