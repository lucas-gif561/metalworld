@tool
extends EditorPlugin
## Liga o exportador da versão (exportar_versao.gd) enquanto o plugin estiver ativo

var _exportador: EditorExportPlugin


func _enter_tree() -> void:
	_exportador = preload("res://addons/versao_build/exportar_versao.gd").new()
	add_export_plugin(_exportador)


func _exit_tree() -> void:
	remove_export_plugin(_exportador)
	_exportador = null
