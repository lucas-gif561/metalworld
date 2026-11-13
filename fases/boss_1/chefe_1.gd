extends Boss
## Boss 1: todos os ataques originais + os novos, em 3 fases.
## Serve de exemplo para os bosses 2 e 3 (veja a lista de ataques em boss_base.gd).

# Ordem dos ataques: [ataque, fase mínima, pausa depois]
const ROTEIRO = [
	["rajada", 1, 2.0],
	["trilha", 1, 1.5],
	["leque", 1, 2.0],
	["descanso", 1, 1.0],
	["espiral", 2, 1.5],
	["corredor", 2, 2.0],
	["capangas", 2, 1.5],
	["teleporte", 2, 0.3],
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
				await esperar_no_ritmo(passo[2])


func _executar(nome: String) -> void:
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
			await espiral()
		"corredor":
			await corredor()
		"capangas":
			invocar_capangas()
		"teleporte":
			await teleporte()
		"escudo":
			ativar_escudo()
		"descanso":
			await descansar()


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
