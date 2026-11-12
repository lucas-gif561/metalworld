extends CanvasLayer

@export var deslocamento_vida := Vector2.ZERO

@onready var painel_vida = $PainelVida
@onready var barra_vida = $PainelVida/BarraVida
@onready var texto_vida = $PainelVida/TextoVida
@onready var barra_stamina = $PainelVida/BarraStamina
@onready var texto_arma = $PainelVida/TextoArma
@onready var progresso = $Progresso
@onready var aviso = $Aviso
@onready var tela_fim = $TelaFim
@onready var titulo_fim = $TelaFim/Conteudo/Titulo
@onready var subtitulo_fim = $TelaFim/Conteudo/Subtitulo
@onready var barra_solo = $PainelVida/BarraSolo
@onready var texto_solo = $PainelVida/TextoSolo
@onready var texto_combo = $Combo
@onready var clarao = $Clarao
@onready var tom_lento = $TomLento
@onready var destaque = $Destaque

var aviso_id := 0
var tween_combo: Tween
var tween_solo: Tween


func _ready() -> void:
	painel_vida.position += deslocamento_vida
	progresso.position += deslocamento_vida
	aviso.hide()
	tela_fim.hide()
	texto_combo.hide()
	barra_solo.hide()
	texto_solo.hide()
	destaque.hide()
	Combate.camera_lenta_mudou.connect(_ao_mudar_camera_lenta)


func conectar_jogador(jogador) -> void:
	jogador.vida_alterada.connect(_atualizar_vida)
	jogador.stamina_alterada.connect(_atualizar_stamina)
	jogador.arma_trocada.connect(_atualizar_arma)
	jogador.esquiva_perfeita.connect(mostrar_destaque.bind("ESQUIVA PERFEITA!"))
	_atualizar_arma(jogador.arma)
	_atualizar_vida(jogador.vida, jogador.vida_maxima)
	_atualizar_stamina(jogador.stamina, jogador.stamina_maxima)


# Na luta do boss a vida fica no cabo de força; aqui sobra só a stamina
func usar_cabo_de_forca() -> void:
	barra_vida.hide()
	texto_vida.hide()
	barra_stamina.position.y = 0.0


func mostrar_solo(visivel: bool) -> void:
	barra_solo.visible = visivel
	texto_solo.visible = false


func atualizar_solo(atual: float, maxima: float) -> void:
	barra_solo.max_value = maxima
	barra_solo.value = atual
	var cheia = atual >= maxima and barra_solo.visible

	if cheia and not texto_solo.visible:
		texto_solo.show()
		tween_solo = create_tween().set_loops()
		tween_solo.tween_property(texto_solo, "modulate:a", 0.3, 0.3)
		tween_solo.tween_property(texto_solo, "modulate:a", 1.0, 0.3)
	elif not cheia and texto_solo.visible:
		texto_solo.hide()
		if tween_solo:
			tween_solo.kill()


func mostrar_combo(quantidade: int) -> void:
	if quantidade < 2:
		return

	texto_combo.text = "COMBO x%d" % quantidade
	texto_combo.modulate.a = 1.0
	texto_combo.scale = Vector2(1.3, 1.3)
	texto_combo.show()

	if tween_combo:
		tween_combo.kill()
	tween_combo = create_tween()
	tween_combo.tween_property(texto_combo, "scale", Vector2.ONE, 0.12)


func esconder_combo() -> void:
	if tween_combo:
		tween_combo.kill()

	if texto_combo.visible:
		tween_combo = create_tween()
		tween_combo.tween_property(texto_combo, "modulate:a", 0.0, 0.25)
		tween_combo.tween_callback(texto_combo.hide)


func mostrar_destaque(texto: String) -> void:
	destaque.text = texto
	destaque.modulate.a = 1.0
	destaque.scale = Vector2(1.4, 1.4)
	destaque.show()
	var tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(destaque, "scale", Vector2.ONE, 0.15)
	tween.tween_interval(0.8)
	tween.tween_property(destaque, "modulate:a", 0.0, 0.3)
	tween.tween_callback(destaque.hide)


func _ao_mudar_camera_lenta(ativa: bool) -> void:
	var tween = create_tween().set_ignore_time_scale(true)
	tween.tween_property(tom_lento, "color:a", 0.16 if ativa else 0.0, 0.2)


func piscar_tela() -> void:
	clarao.color.a = 0.6
	create_tween().tween_property(clarao, "color:a", 0.0, 0.35)


func _atualizar_arma(nome: String) -> void:
	texto_arma.text = ("METRALHADORA" if nome == "metralhadora" else "GUITARRA") + "  (Q troca)"
	texto_arma.modulate = Color(1, 0.75, 0.3) if nome == "metralhadora" else Color.WHITE


func _atualizar_stamina(atual, maxima) -> void:
	barra_stamina.max_value = maxima
	barra_stamina.value = atual


func _atualizar_vida(atual, maxima) -> void:
	barra_vida.max_value = maxima
	barra_vida.value = atual
	texto_vida.text = "VIDA %d/%d" % [atual, maxima]


func definir_progresso(texto: String) -> void:
	progresso.text = texto


func mostrar_aviso(texto: String, duracao := 0.0) -> void:
	aviso_id += 1
	var id := aviso_id
	aviso.text = texto
	aviso.show()

	if duracao > 0.0:
		await get_tree().create_timer(duracao).timeout
		if id == aviso_id:
			aviso.hide()


func esconder_aviso() -> void:
	aviso_id += 1
	aviso.hide()


func mostrar_fim(titulo: String, subtitulo: String, cor: Color) -> void:
	esconder_aviso()
	titulo_fim.text = titulo
	titulo_fim.modulate = cor
	subtitulo_fim.text = subtitulo
	tela_fim.show()
