extends Panel

@export var tempo_aviso := 0.9
@export var tempo_impacto := 0.2
@export var brilho_impacto := Color.WHITE
@export var dano := 1

var _tempo := 0.0
var _atingiu := false


func _physics_process(delta: float) -> void:
	_tempo += delta
	if not _atingiu and _tempo >= tempo_aviso:
		_atingiu = true
		self_modulate = brilho_impacto
		var area := Rect2(global_position, size)
		for jogador in Jogo.jogadores_vivos():
			if not jogador.entrando and area.has_point(jogador.global_position):
				jogador.receber_dano(dano)
	if _tempo >= tempo_aviso + tempo_impacto:
		queue_free()
