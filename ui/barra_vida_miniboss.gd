extends CanvasLayer
## Barra de vida do miniboss, no canto superior direito da tela (o mesmo
## lugar da barra dos bosses). Fica dentro da cena do miniboss, como nó
## "BarraVida", mas é um CanvasLayer: desenha na tela, não acima da cabeça.
## A moldura é um NinePatchRect que estica pelo meio, e o "Enchimento" fica
## sobre a canaleta. O miniboss_base chama definir() quando ele apanha.

@onready var enchimento: ColorRect = $Barra/Enchimento
@onready var _largura_cheia: float = enchimento.size.x


func definir(vida: float, vida_maxima: float) -> void:
	var fracao = clampf(vida / maxf(vida_maxima, 1.0), 0.0, 1.0)
	enchimento.size.x = roundf(_largura_cheia * fracao)
