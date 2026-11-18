extends "res://bosses/base/arena_boss.gd"
## Arena de treino do Riff: a arena do boss 1 com um boss que não ataca e não
## morre, para tocar à vontade e testar o Riff. Não faz parte do jogo (fica
## fora de Jogo.FASES): abra fases/treino_riff/treino_riff.tscn e rode com F6.
##
## Fora das FASES o P2 não entra com START e o pause não abre, por isso a dupla
## se escolhe aqui no Inspector.

## Começa com os dois jogadores (P1 à esquerda, P2 à direita)
@export var dois_jogadores := false


func _ready() -> void:
	Jogo.p2_ativo = dois_jogadores
	super()
