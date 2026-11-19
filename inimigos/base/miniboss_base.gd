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
## Acertar um minirriff nele segura a postura: ela para de baixar por este
## tempo (segundos), e os socos seguintes chegam mais fácil na quebra
@export var pausa_recuperacao_minirriff = 5.0
## Cada soco também segura a postura, por menos tempo (não encurta uma pausa
## maior que já esteja correndo, como a do minirriff)
@export var pausa_recuperacao_golpe = 0.3

@export_group("Dano")
## Soco com ele em pé tira só esta fração da vida (a postura enche igual):
## de joelhos o soco tira o dano cheio; o minirriff tira o impacto dele
@export var fracao_golpe_em_pe = 0.5

var postura = 0.0
var tempo_postura_quebrada = 0.0
var _sem_recuperar_postura = 0.0
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

	if _sem_recuperar_postura > 0.0:
		_sem_recuperar_postura = maxf(_sem_recuperar_postura - delta, 0.0)
	else:
		postura = maxf(postura - perda_postura_por_segundo * delta, 0.0)
	_processar_miniboss(delta)


func _processar_miniboss(delta) -> void:
	super._physics_process(delta)


## Soco do jogador (jogador.gd chama receber_golpe em quem tiver)
func receber_golpe(valor):
	if not morto and valor > 0:
		_sem_recuperar_postura = maxf(_sem_recuperar_postura, pausa_recuperacao_golpe)
	var ajoelhado = tempo_postura_quebrada > 0.0 or _levantando
	_apanhar(valor * (1.0 if ajoelhado else fracao_golpe_em_pe), valor * postura_por_dano)


## Minirriff: leva o "impacto" do minirriff (tabelas MINIRRIFFS), não o dano
## normal; a postura sai dele como no soco, e para de baixar por um tempo
func receber_minirriff(_dano, impacto):
	if not morto and impacto > 0:
		_sem_recuperar_postura = maxf(_sem_recuperar_postura, pausa_recuperacao_minirriff)
	_apanhar(impacto, impacto * postura_por_dano)


## Qualquer outro dano
func receber_dano(valor):
	_apanhar(valor, valor * postura_por_dano)


func _apanhar(dano, ganho_postura: float):
	if morto or dano <= 0:
		return
	super.receber_dano(dano)
	if barra_vida:
		barra_vida.definir(vida, _vida_maxima)
	if morto or tempo_postura_quebrada > 0.0 or _levantando:
		return

	postura = minf(postura + ganho_postura, postura_maxima)
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
	_sem_recuperar_postura = 0.0
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
