extends "res://bosses/base/projetil_boss.gd"
## Palheta do guitarrista (rajada, leque e espiral): o mesmo tiro do boss,
## com o lado largo virado para onde foi arremessada (a ponta fica para trás).
## Fica em código porque a direção só é conhecida quando o boss atira.

## A arte da palheta tem o lado largo para cima (-90° em relação à direita)
const ANGULO_DA_ARTE := -PI / 2


func _physics_process(delta):
	$Sprite2D.rotation = direcao.angle() - ANGULO_DA_ARTE
	super(delta)
