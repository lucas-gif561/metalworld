extends Panel
## Ataque de chão dos pilares e do Guardião. Na cena fica com z_index -1: atrás
## dos personagens e na frente do fundo da rua (também -1, mas antes na árvore).

const MARGEM_ARENA := 18.0

@export var tempo_aviso := 0.9
@export var tempo_impacto := 0.2
@export var brilho_impacto := Color.WHITE
@export var dano := 1
## Feixe que segue o jogador: para de seguir este tempo antes de cair, para dar
## tempo de sair do círculo ou esquivar
@export var tempo_travado := 0.7
## Feixe que segue o jogador: círculo que enche do centro até a borda e chega
## na borda no instante do impacto
@export var cor_carga := Color(1, 1, 1, 0.8)

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
	if _raio_seguimento > 0.0:
		queue_redraw()
	if is_instance_valid(_alvo_seguido):
		if _tempo < tempo_aviso - tempo_travado:
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


func _draw() -> void:
	if _raio_seguimento <= 0.0 or _atingiu:
		return
	var carga := clampf(_tempo / tempo_aviso, 0.0, 1.0)
	draw_circle(size * 0.5, _raio_seguimento * carga, cor_carga)


func _dentro_da_area(area: Rect2, ponto: Vector2) -> bool:
	if _raio_seguimento > 0.0:
		return area.get_center().distance_squared_to(ponto) <= _raio_seguimento * _raio_seguimento
	return area.has_point(ponto)
