extends Resource

const DisparoBlaster = preload("res://fases/boss_3/disparo_blaster.gd")

@export var disparos: Array[DisparoBlaster] = []

## Recuperação longa depois de terminar todos os disparos deste padrão.
@export var recarga_longa := false
