extends Control


func _ready() -> void:
	Audio.tocar_musica("ruas")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		Audio.tocar("ui_confirma", 0.0)
		get_tree().change_scene_to_file("res://scenes/main/main.tscn")
