extends Node
## Sons e música (autoload "Audio"). Ex.: Audio.tocar("tiro_dylan"), Audio.tocar_musica("boss")

const ARQUIVOS_SFX = {
	"tiro_dylan": "res://assets/audio/sfx/tiro_dylan.wav",
	"dano_dylan": "res://assets/audio/sfx/dano_dylan.wav",
	"morte_dylan": "res://assets/audio/sfx/morte_dylan.wav",
	"dodge": "res://assets/audio/sfx/dodge.wav",
	"tiro_inimigo": "res://assets/audio/sfx/tiro_inimigo.wav",
	"dano_inimigo": "res://assets/audio/sfx/dano_inimigo.wav",
	"morte_inimigo": "res://assets/audio/sfx/morte_inimigo.wav",
	"granada": "res://assets/audio/sfx/granada.wav",
	"boss_conjura": "res://assets/audio/sfx/boss_conjura.wav",
	"escudo": "res://assets/audio/sfx/escudo.wav",
	"runa_quebrada": "res://assets/audio/sfx/runa_quebrada.wav",
	"teleporte": "res://assets/audio/sfx/teleporte.wav",
	"nota_perfect": "res://assets/audio/sfx/nota_perfect.wav",
	"nota_good": "res://assets/audio/sfx/nota_good.wav",
	"nota_miss": "res://assets/audio/sfx/nota_miss.wav",
	"nota_maldita": "res://assets/audio/sfx/nota_maldita.wav",
	"portal": "res://assets/audio/sfx/portal.wav",
	"vitoria": "res://assets/audio/sfx/vitoria.wav",
	"ui_confirma": "res://assets/audio/sfx/ui_confirma.wav",
}

const ARQUIVOS_MUSICA = {
	"ruas": "res://assets/audio/musica/ruas.ogg",
	"boss": "res://assets/audio/musica/boss.ogg",
}

const VOZES = 16
const INTERVALO_MINIMO_MS = 40

@export var volume_musica_db: float = -12.0
@export var volume_sfx_db: float = -6.0

## Sem janela (testes) ninguém ouve: não toca nada, e o Godot fecha sem recurso preso
var mudo := false
var SFX := {}
var MUSICAS := {}
var vozes: Array[AudioStreamPlayer] = []
var proxima_voz: int = 0
var ultimo_toque_ms := {}
var musica: AudioStreamPlayer
var musica_atual := ""
var tween_musica: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mudo = DisplayServer.get_name() == "headless"

	for nome in ARQUIVOS_SFX:
		SFX[nome] = load(ARQUIVOS_SFX[nome])
	for nome in ARQUIVOS_MUSICA:
		MUSICAS[nome] = load(ARQUIVOS_MUSICA[nome])

	for i in range(VOZES):
		var voz = AudioStreamPlayer.new()
		add_child(voz)
		vozes.append(voz)

	musica = AudioStreamPlayer.new()
	add_child(musica)

	for faixa in MUSICAS.values():
		faixa.loop = true


func tocar(nome: String, variacao: float = 0.05) -> void:
	if mudo:
		return
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
	if mudo:
		return
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


## Pausa a música junto com o jogo (o Riff usa a posição da música)
func pausar_musica(pausar: bool) -> void:
	musica.stream_paused = pausar


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


# Solta os sons ao fechar o jogo (evita aviso de recurso preso na saída)
func _exit_tree() -> void:
	musica.stop()
	musica.stream = null
	for voz in vozes:
		voz.stop()
		voz.stream = null
	SFX.clear()
	MUSICAS.clear()
