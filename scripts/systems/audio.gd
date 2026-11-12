extends Node

const SFX = {
	"tiro_dylan": preload("res://assets/audio/sfx/tiro_dylan.wav"),
	"dano_dylan": preload("res://assets/audio/sfx/dano_dylan.wav"),
	"morte_dylan": preload("res://assets/audio/sfx/morte_dylan.wav"),
	"dodge": preload("res://assets/audio/sfx/dodge.wav"),
	"tiro_inimigo": preload("res://assets/audio/sfx/tiro_inimigo.wav"),
	"dano_inimigo": preload("res://assets/audio/sfx/dano_inimigo.wav"),
	"morte_inimigo": preload("res://assets/audio/sfx/morte_inimigo.wav"),
	"granada": preload("res://assets/audio/sfx/granada.wav"),
	"boss_conjura": preload("res://assets/audio/sfx/boss_conjura.wav"),
	"escudo": preload("res://assets/audio/sfx/escudo.wav"),
	"runa_quebrada": preload("res://assets/audio/sfx/runa_quebrada.wav"),
	"teleporte": preload("res://assets/audio/sfx/teleporte.wav"),
	"nota_perfect": preload("res://assets/audio/sfx/nota_perfect.wav"),
	"nota_good": preload("res://assets/audio/sfx/nota_good.wav"),
	"nota_miss": preload("res://assets/audio/sfx/nota_miss.wav"),
	"nota_maldita": preload("res://assets/audio/sfx/nota_maldita.wav"),
	"portal": preload("res://assets/audio/sfx/portal.wav"),
	"vitoria": preload("res://assets/audio/sfx/vitoria.wav"),
	"ui_confirma": preload("res://assets/audio/sfx/ui_confirma.wav"),
}

const MUSICAS = {
	"ruas": preload("res://assets/audio/musica/ruas.ogg"),
	"boss": preload("res://assets/audio/musica/boss.ogg"),
}

const VOZES = 16
const INTERVALO_MINIMO_MS = 40

@export var volume_musica_db: float = -12.0
@export var volume_sfx_db: float = -6.0

var vozes: Array[AudioStreamPlayer] = []
var proxima_voz: int = 0
var ultimo_toque_ms := {}
var musica: AudioStreamPlayer
var musica_atual := ""
var tween_musica: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in range(VOZES):
		var voz = AudioStreamPlayer.new()
		add_child(voz)
		vozes.append(voz)

	musica = AudioStreamPlayer.new()
	add_child(musica)

	for faixa in MUSICAS.values():
		faixa.loop = true


func tocar(nome: String, variacao: float = 0.05) -> void:
	var agora = Time.get_ticks_msec()

	# Evita o estouro de som quando o mesmo efeito dispara várias vezes juntas
	if agora - ultimo_toque_ms.get(nome, -INTERVALO_MINIMO_MS) < INTERVALO_MINIMO_MS:
		return

	ultimo_toque_ms[nome] = agora

	var voz = vozes[proxima_voz]
	proxima_voz = (proxima_voz + 1) % VOZES
	voz.stream = SFX[nome]
	voz.volume_db = volume_sfx_db
	voz.pitch_scale = randf_range(1.0 - variacao, 1.0 + variacao)
	voz.play()


func tocar_musica(nome: String) -> void:
	if nome == musica_atual and musica.playing:
		return

	if tween_musica:
		tween_musica.kill()

	musica_atual = nome
	musica.stream = MUSICAS[nome]
	musica.volume_db = volume_musica_db
	musica.play()


# Na câmera lenta a música fica arrastada, como um disco desacelerando
func definir_lentidao(lento: bool) -> void:
	musica.pitch_scale = 0.7 if lento else 1.0


func parar_musica() -> void:
	musica_atual = ""

	if tween_musica:
		tween_musica.kill()

	tween_musica = create_tween()
	tween_musica.tween_property(musica, "volume_db", -60.0, 0.6)
	tween_musica.tween_callback(musica.stop)


# Posição real da música em segundos, usada para o Riff cair no tempo
func posicao_musica() -> float:
	if not musica.playing:
		return Time.get_ticks_msec() / 1000.0

	return musica.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
