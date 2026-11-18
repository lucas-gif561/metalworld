extends "res://fases/boss_1/chefe_1.gd"
## Eddie de treino: não ataca. Ou fica sempre no descanso (hora do Riff, sem o
## "!" de alerta), ou fica "atacando" sem atacar, para ver o alerta.
## A vida e o resto ficam no Inspector de treino_riff.tscn.

## true: descanso sem fim. false: sem descanso, com o "!" piscando no Riff.
@export var sempre_descansando := true
## Ergue os totens a cada tantos segundos (0 = nunca), para testar o Riff
## fechando sozinho e o cadeado
@export var escudo_a_cada := 0.0


func ciclo_ataques():
	if escudo_a_cada > 0.0:
		_escudo_de_tempos_em_tempos()
	while is_inside_tree() and vida_atual > 0:
		if sempre_descansando and not escudo_ativo:
			await descansar()
		# Também segura o laço se o descanso voltar na hora (escudo de pé)
		await esperar(0.2)


func _escudo_de_tempos_em_tempos() -> void:
	while is_inside_tree() and vida_atual > 0:
		await esperar(escudo_a_cada)
		if not escudo_ativo:
			# Sai do descanso para os totens poderem subir de verdade
			_encerrar_descanso()
			ativar_escudo()
