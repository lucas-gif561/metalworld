extends Line2D


func expandir(raio: float) -> void:
	# O anel cresce até o alcance efetivo do golpe.
	scale = Vector2.ONE * 0.2
	var animacao = create_tween().set_parallel()
	animacao.tween_property(self, "scale", Vector2.ONE * (raio / 100.0), 0.28)
	animacao.tween_property(self, "modulate:a", 0.0, 0.28)
	animacao.chain().tween_callback(queue_free)
