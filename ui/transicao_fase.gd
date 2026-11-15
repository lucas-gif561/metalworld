extends CanvasLayer

@export var duracao: float
@onready var tela_escura: ColorRect = $TelaEscura


func _ready() -> void:
	var arvore := get_tree()
	var origem := arvore.current_scene
	# A camada fica na raiz para cobrir a troca e clarear já na próxima cena.
	var escurecer := create_tween().set_ignore_time_scale()
	escurecer.tween_property(tela_escura, "modulate:a", 1.0, duracao)
	await escurecer.finished

	if arvore.current_scene == origem:
		Jogo.proxima_fase()
		await arvore.scene_changed

	var clarear := create_tween().set_ignore_time_scale()
	clarear.tween_property(tela_escura, "modulate:a", 0.0, duracao)
	await clarear.finished
	queue_free()
