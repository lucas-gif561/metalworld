extends Resource

@export var cena_feixe: PackedScene
@export var cena_orbe: PackedScene
@export var cena_pulso: PackedScene
## Ângulos em graus, relativos à mira. Os orbes da lista saem juntos.
@export var angulos_dos_orbes := PackedFloat32Array()
## Espera os projéteis saírem da arena antes de seguir para o próximo padrão.
@export var aguardar_rajada := false
@export_range(0, 8) var reflexoes := 0
@export var teleportar_antes := false
## Multiplicador dos tempos de aviso e chegada do teleporte antes do tiro.
@export_range(0.4, 1.0) var fator_tempo_teleporte := 1.0
## Faixas da Parede de Feixes, numeradas de 0 a 2. Vazio usa a mira normal.
@export var faixas_da_parede := PackedInt32Array()
@export_range(0.0, 5.0) var intervalo_anterior := 0.0
@export_range(0.05, 3.0) var tempo_aviso := 0.45
@export_range(0.05, 3.0) var tempo_carga := 0.2
