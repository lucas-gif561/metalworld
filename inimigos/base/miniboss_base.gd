extends Inimigo
## Miniboss: inimigo com postura. Muitos golpes seguidos quebram a postura e
## ele fica atordoado por duracao_quebra_postura.
##
## Atordoado, com as animações (opcionais) no SpriteFrames:
##   "ajoelhar"      cai de joelhos (e tocada ao contrário, levanta no fim);
##   "ajoelhado"     loop enquanto está de joelhos;
##   "hit_ajoelhado" quando apanha de joelhos.
## Sem elas, usa "hurt" como antes. Ele só volta a atacar depois de levantar.

@export_group("Postura")
@export var postura_maxima = 100.0
@export var perda_postura_por_segundo = 14.0
@export var postura_por_dano = 18.0
@export var duracao_quebra_postura = 2.0

var postura = 0.0
var tempo_postura_quebrada = 0.0
## Barra de vida no canto da tela (opcional): instância de
## ui/barra_vida_miniboss.tscn chamada "BarraVida" na cena do miniboss
@onready var barra_vida = get_node_or_null("BarraVida")
@onready var _vida_maxima: float = vida
var _levantando := false


func _ready() -> void:
	super._ready()
	sprite.animation_finished.connect(_ao_terminar_animacao_postura)
	if barra_vida:
		barra_vida.definir(vida, _vida_maxima)


func _physics_process(delta):
	if (tempo_postura_quebrada > 0.0 or _levantando) and not morto:
		if tempo_postura_quebrada > 0.0:
			tempo_postura_quebrada = maxf(tempo_postura_quebrada - delta, 0.0)
			if tempo_postura_quebrada <= 0.0:
				_levantar()
		velocity = Vector2.ZERO
		return

	postura = maxf(postura - perda_postura_por_segundo * delta, 0.0)
	_processar_miniboss(delta)


func _processar_miniboss(delta) -> void:
	super._physics_process(delta)


func receber_dano(valor):
	if morto or valor <= 0:
		return
	super.receber_dano(valor)
	if barra_vida:
		barra_vida.definir(vida, _vida_maxima)
	if morto or tempo_postura_quebrada > 0.0 or _levantando:
		return

	postura = minf(postura + valor * postura_por_dano, postura_maxima)
	if postura >= postura_maxima:
		_quebrar_postura()


func morrer():
	_levantando = false
	if barra_vida:
		barra_vida.hide()
	super.morrer()


func empurrar(_forca: Vector2) -> void:
	# Só uma quebra de postura interrompe os ataques do miniboss.
	pass


func _reagir_ao_dano() -> void:
	Audio.tocar("dano_inimigo")
	# De joelhos ele sente o golpe (sem interromper a queda nem o levantar)
	if tempo_postura_quebrada > 0.0 and sprite.animation != &"ajoelhar" and _tem_animacao("hit_ajoelhado"):
		_tocar_acao("hit_ajoelhado")


func _quebrar_postura() -> void:
	postura = 0.0
	tempo_postura_quebrada = duracao_quebra_postura
	_cancelar_carga()
	velocity = Vector2.ZERO
	_tocar_acao("ajoelhar" if _tem_animacao("ajoelhar") else "hurt")
	Combate.tremer(5.0)


## Fim do atordoamento: levanta (o "ajoelhar" ao contrário) antes de atacar de novo
func _levantar() -> void:
	if not _tem_animacao("ajoelhar"):
		return
	_levantando = true
	em_acao = true
	sprite.play_backwards(&"ajoelhar")


func _ao_terminar_animacao_postura() -> void:
	if morto:
		return
	if sprite.animation == &"ajoelhar":
		if _levantando:
			_levantando = false
			em_acao = false
		elif tempo_postura_quebrada > 0.0 and _tem_animacao("ajoelhado"):
			_tocar_acao("ajoelhado")
	elif sprite.animation == &"hit_ajoelhado" and tempo_postura_quebrada > 0.0:
		_tocar_acao("ajoelhado")


func _tem_animacao(nome: String) -> bool:
	return sprite.sprite_frames.has_animation(nome)
