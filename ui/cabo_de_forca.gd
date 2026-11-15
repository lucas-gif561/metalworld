extends Control
## Cabo de força: uma barra só, a dupla de um lado e o boss (vermelho) do
## outro. Visual na cena: barra dentro da moldura dos botões do menu.
## O lado da dupla é azul com só o P1 e, com o P2 na partida, um gradiente
## do rosa (P2) ao azul (P1), com o azul encostando no vermelho do boss.

## Preenchimento com só o P1 jogando
@export var estilo_solo: StyleBox
## Preenchimento com o P1 e o P2 (gradiente rosa -> azul)
@export var estilo_dupla: StyleBox

@onready var barra = $Barra
@onready var marcador = $Marcador

var jogador
var boss
var tween_barra: Tween


func _ready() -> void:
	# Fica em código porque o P2 pode entrar ou sair no meio da luta
	Jogo.jogador_entrou.connect(_ao_mudar_jogadores)
	Jogo.jogador_saiu.connect(_ao_mudar_jogadores)
	_atualizar_estilo()


func _ao_mudar_jogadores(_jogador_ou_id) -> void:
	_atualizar_estilo.call_deferred()


func conectar(novo_jogador, novo_boss) -> void:
	jogador = novo_jogador
	boss = novo_boss
	jogador.vida_alterada.connect(_ao_mudar_vida_jogador)
	boss.vida_atualizada.connect(_ao_mudar_vida_boss)
	barra.value = _lado_dylan()
	_atualizar_estilo()


func _atualizar_estilo() -> void:
	var em_dupla = Jogo.jogador_por_id(2) != null
	var estilo = estilo_dupla if em_dupla else estilo_solo
	if estilo:
		barra.add_theme_stylebox_override("fill", estilo)


func _process(_delta: float) -> void:
	marcador.position.x = barra.position.x + barra.value * barra.size.x - marcador.size.x / 2.0


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
