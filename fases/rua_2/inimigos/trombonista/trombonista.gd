extends Inimigo

var _golpe_pendente = false


func _ready():
	super._ready()
	sprite.frame_changed.connect(_ao_avancar_quadro)


func _comportamento(delta):
	if em_acao and sprite.animation == &"attack":
		return
	super._comportamento(delta)


func _golpe_da_vaga():
	_golpe_pendente = true
	_ao_avancar_quadro()


func _ao_avancar_quadro() -> void:
	if not _golpe_pendente or sprite.animation != &"attack":
		return
	var ultimo_quadro = sprite.sprite_frames.get_frame_count(&"attack") - 1
	if sprite.frame != ultimo_quadro:
		return
	_golpe_pendente = false
	super._golpe_da_vaga()


func _cancelar_carga() -> void:
	_golpe_pendente = false
	super._cancelar_carga()
