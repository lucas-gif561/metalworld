extends Area2D

@export var velocidade = 620.0
@export var alcance = 480.0
@export var grupo_alvos: StringName = &"inimigos"
@export var limite_acertos = 2
@export var empurrao = 360.0
@export var atordoamento = 0.0

var direcao = 1
var dano = 4
## Dano no miniboss (ver "impacto" em MINIRRIFFS, jogador.gd)
var impacto = 4
var _distancia_restante = 0.0
var _atingidos: Array[int] = []


func disparar(lado: int, dano_golpe: int, escala_personagem: float, impacto_golpe = -1) -> void:
	direcao = lado
	dano = dano_golpe
	impacto = impacto_golpe if impacto_golpe >= 0 else dano_golpe
	_distancia_restante = alcance * escala_personagem
	scale *= escala_personagem
	$Arco.scale.x *= direcao


func _physics_process(delta: float) -> void:
	var passo = minf(velocidade * delta, _distancia_restante)
	position.x += direcao * passo
	_distancia_restante -= passo
	if _distancia_restante <= 0.0:
		queue_free()


func _ao_atingir(corpo: Node2D) -> void:
	if not corpo.is_in_group(grupo_alvos) and not corpo.is_in_group("caixotes"):
		return
	if _atingidos.size() >= limite_acertos or corpo.get("morto"):
		return
	var id = corpo.get_instance_id()
	if id in _atingidos:
		return
	_atingidos.append(id)
	if empurrao > 0.0 and corpo.has_method("empurrar"):
		corpo.empurrar(Vector2(direcao * empurrao, 0.0))
	if corpo.has_method("receber_minirriff"):
		corpo.receber_minirriff(dano, impacto)
	else:
		corpo.receber_dano(dano)
	if atordoamento > 0.0 and corpo is Inimigo:
		corpo.atordoar(atordoamento)
	if _atingidos.size() == limite_acertos:
		queue_free()
