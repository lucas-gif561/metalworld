extends "res://personagens/dylan/jogador.gd"

const PROJETIL_VIRADA = preload("res://personagens/baterista/projetil_virada.tscn")
const PROJETIL_CAIXA = preload("res://personagens/baterista/projetil_caixa.tscn")

const MINIRRIFFS_KEVIN = {
	# Impacto no miniboss por batida, somando o do custo (ver MINIRRIFFS em jogador.gd)
	"AABB": {"nome": "Virada", "custo": 3.0, "quadros": [2, 5, 8], "danos": [1, 1, 2], "impactos": [1, 1, 2], "empurrao": 650.0, "cena": PROJETIL_VIRADA},
	"ABBA": {"nome": "Caixa", "custo": 2.0, "quadros": [5], "danos": [2], "impactos": [3], "cena": PROJETIL_CAIXA},
	"ABAB": {"nome": "Bumbo", "custo": 1.0, "quadros": [2, 8], "dano": 1, "impacto": 1, "raio": 120.0, "empurrao": 600.0},
}


func _minirriffs_disponiveis() -> Dictionary:
	return MINIRRIFFS_KEVIN


func _ao_mudar_quadro():
	super._ao_mudar_quadro()
	if sprite.animation != &"minirriff" or _especial_pendente.is_empty() or bloqueado:
		return

	var especial = _especial_pendente
	var batida: int = especial.quadros.find(sprite.frame)
	if batida == -1:
		return
	if batida == 0:
		_alterar_poder(-especial.custo)

	var ultima_batida: bool = batida == especial.quadros.size() - 1
	var batida_grave: bool = especial.has("raio") or (ultima_batida and especial.has("empurrao"))
	Audio.tocar("minirriff_grave" if batida_grave else "minirriff_agudo")
	Combate.tremer(4.0 if ultima_batida else 2.0)
	if especial.has("raio"):
		_soltar_onda(especial)
	else:
		_disparar_pulso(especial, batida, ultima_batida)


func _disparar_pulso(especial: Dictionary, batida: int, ultima_batida: bool) -> void:
	var projetil = especial.cena.instantiate()
	if ultima_batida and especial.has("empurrao"):
		projetil.empurrao = especial.empurrao
	get_tree().current_scene.add_child(projetil)
	projetil.global_position = global_position + Vector2(28.0 * direcao_olhar * escala_personagem, 0.0)
	projetil.disparar(direcao_olhar, especial.danos[batida], escala_personagem, especial.impactos[batida])


func _soltar_especial() -> void:
	_cancelar_especial()
	em_acao = false
	sprite.play("idle")
