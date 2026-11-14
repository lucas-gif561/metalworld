extends Area2D

@export var velocidade = 620.0
@export var alcance = 480.0

var direcao = 1
var dano = 4
var _distancia_restante = 0.0
var _atingidos: Array[int] = []


func disparar(lado: int, dano_golpe: int, escala_personagem: float) -> void:
	direcao = lado
	dano = dano_golpe
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
	if _atingidos.size() >= 2 or not corpo.is_in_group("inimigos") or corpo.get("morto"):
		return
	var id = corpo.get_instance_id()
	if id in _atingidos:
		return
	_atingidos.append(id)
	corpo.empurrar(Vector2(direcao * 360.0, 0.0))
	corpo.receber_dano(dano)
	if _atingidos.size() == 2:
		queue_free()
