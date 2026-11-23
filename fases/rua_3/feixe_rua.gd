extends Panel

const MARGEM_ARENA := 18.0
const TEMPO_ANTES_DO_IMPACTO := 0.2

@export var tempo_aviso := 0.9
@export var tempo_impacto := 0.2
@export var brilho_impacto := Color.WHITE
@export var dano := 1

var _tempo := 0.0
var _atingiu := false
var _alvo_seguido: Node2D
var _raio_seguimento := 0.0


func seguir(alvo: Node2D, raio: float) -> void:
	_alvo_seguido = alvo
	_raio_seguimento = raio
	var circulo := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	circulo.set_corner_radius_all(ceili(raio))
	circulo.corner_detail = 16
	add_theme_stylebox_override("panel", circulo)


func _physics_process(delta: float) -> void:
	_tempo += delta
	if is_instance_valid(_alvo_seguido):
		if _tempo < tempo_aviso - TEMPO_ANTES_DO_IMPACTO:
			global_position = _alvo_seguido.global_position - size * 0.5
		else:
			_alvo_seguido = null
			self_modulate = self_modulate.lerp(brilho_impacto, 0.35)
	if not _atingiu and _tempo >= tempo_aviso:
		_atingiu = true
		self_modulate = brilho_impacto
		var area := Rect2(global_position, size)
		for jogador in Jogo.jogadores_vivos():
			if not jogador.entrando and _dentro_da_area(area, jogador.global_position):
				jogador.receber_dano(dano)
	if _tempo >= tempo_aviso + tempo_impacto:
		queue_free()


func _dentro_da_area(area: Rect2, ponto: Vector2) -> bool:
	if _raio_seguimento > 0.0:
		return area.get_center().distance_squared_to(ponto) <= _raio_seguimento * _raio_seguimento
	return area.has_point(ponto)
