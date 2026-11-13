extends Control
## Cabo de força: uma barra só, a dupla de um lado e o boss do outro.

@onready var barra = $Barra
@onready var marcador = $Marcador

var jogador
var boss
var tween_barra: Tween


func conectar(novo_jogador, novo_boss) -> void:
	jogador = novo_jogador
	boss = novo_boss
	jogador.vida_alterada.connect(_ao_mudar_vida_jogador)
	boss.vida_atualizada.connect(_ao_mudar_vida_boss)
	barra.value = _lado_dylan()


func _process(_delta: float) -> void:
	$TextoDylan.text = "P1 + P2" if Jogo.jogadores.size() >= 2 else "DYLAN"
	marcador.position.x = barra.value * size.x - marcador.size.x / 2.0


# 0 = boss venceu, 1 = Dylan venceu, 0,5 = empate
func _lado_dylan() -> float:
	var vida_dylan = clampf(float(jogador.vida) / jogador.vida_maxima, 0.0, 1.0)
	var vida_boss = clampf(float(boss.vida_atual) / boss.vida_maxima, 0.0, 1.0)
	var total = vida_dylan + vida_boss

	return vida_dylan / total if total > 0.0 else 0.5


func _ao_mudar_vida_jogador(_atual, _maxima) -> void:
	_atualizar()


func _ao_mudar_vida_boss(_vida) -> void:
	_atualizar()


func _atualizar() -> void:
	if tween_barra:
		tween_barra.kill()

	tween_barra = create_tween()
	tween_barra.tween_property(barra, "value", _lado_dylan(), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
