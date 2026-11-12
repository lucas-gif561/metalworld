extends CanvasLayer

@export var deslocamento_vida := Vector2.ZERO

@onready var painel_vida = $PainelVida
@onready var barra_vida = $PainelVida/BarraVida
@onready var texto_vida = $PainelVida/TextoVida
@onready var barra_stamina = $PainelVida/BarraStamina
@onready var progresso = $Progresso
@onready var aviso = $Aviso
@onready var tela_fim = $TelaFim
@onready var titulo_fim = $TelaFim/Conteudo/Titulo
@onready var subtitulo_fim = $TelaFim/Conteudo/Subtitulo

var aviso_id := 0


func _ready() -> void:
	painel_vida.position += deslocamento_vida
	progresso.position += deslocamento_vida
	aviso.hide()
	tela_fim.hide()


func conectar_jogador(jogador) -> void:
	jogador.vida_alterada.connect(_atualizar_vida)
	jogador.stamina_alterada.connect(_atualizar_stamina)
	_atualizar_vida(jogador.vida, jogador.vida_maxima)
	_atualizar_stamina(jogador.stamina, jogador.stamina_maxima)


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
