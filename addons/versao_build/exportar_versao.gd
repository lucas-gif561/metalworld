@tool
extends EditorExportPlugin
## A cada exportação, pergunta ao git o commit atual e põe res://versao.txt
## dentro do pacote do jogo. O arquivo não existe no projeto: só no build.
## O menu principal (ui/tela_inicial.gd) lê e mostra no canto da tela.
##
## Conteúdo: "<hash curto> <data do build>", com "+" no hash se havia
## alterações não commitadas na hora de exportar (o build não é só aquele commit).

const ARQUIVO = "res://versao.txt"


func _get_name() -> String:
	return "VersaoBuild"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var texto = preload("res://addons/versao_build/versao_git.gd").linha()
	add_file(ARQUIVO, texto.to_utf8_buffer(), false)
	print("Versão do build: ", texto)

