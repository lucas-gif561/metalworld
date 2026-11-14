extends Inimigo

@export_group("Postura")
@export var postura_maxima = 100.0
@export var perda_postura_por_segundo = 14.0
@export var postura_por_dano = 18.0
@export var duracao_quebra_postura = 2.0

var postura = 0.0
var tempo_postura_quebrada = 0.0


func _physics_process(delta):
	if tempo_postura_quebrada > 0.0 and not morto:
		tempo_postura_quebrada = maxf(tempo_postura_quebrada - delta, 0.0)
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
	if morto or tempo_postura_quebrada > 0.0:
		return

	postura = minf(postura + valor * postura_por_dano, postura_maxima)
	if postura >= postura_maxima:
		_quebrar_postura()


func empurrar(_forca: Vector2) -> void:
	# Só uma quebra de postura interrompe os ataques do miniboss.
	pass


func _reagir_ao_dano() -> void:
	Audio.tocar("dano_inimigo")


func _quebrar_postura() -> void:
	postura = 0.0
	tempo_postura_quebrada = duracao_quebra_postura
	_cancelar_carga()
	velocity = Vector2.ZERO
	_tocar_acao("hurt")
	Combate.tremer(5.0)
