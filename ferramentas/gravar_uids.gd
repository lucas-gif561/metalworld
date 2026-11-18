# Grava os UIDs que faltam em cenas, recursos e scripts, sem abrir o editor.
#
# Uso (rode da raiz do projeto, depois de importar as imagens novas):
#   godot --headless --path . --import   (só se houver imagens ou sons novos)
#   godot --headless --path . --script res://ferramentas/gravar_uids.gd
#   godot --headless --path . --script res://ferramentas/gravar_uids.gd -- fases/rua_3/rua_3.tscn fases/rua_3/inimigos/
#   godot --headless --path . --script res://ferramentas/gravar_uids.gd -- --verificar
#
# Sem argumentos, preenche o que falta no projeto inteiro e lista os arquivos alterados.
# Com arquivos ou pastas depois do "--", só mexe neles (use para os arquivos do seu PR).
# Com --verificar, não altera nada: só lista o que falta e termina com erro se faltar algo.
#
# O que faz, mexendo só nas linhas necessárias (o resto do arquivo fica igual):
# - .tscn/.tres sem uid no cabeçalho: o Godot sorteia um UID novo (ResourceUID.create_id);
# - [ext_resource] sem uid: copia o UID real do arquivo apontado (cabeçalho, .import ou .uid);
# - .gd/.gdshader sem o .uid ao lado: cria o .uid com um UID novo.
# Nenhum UID é inventado à mão: os novos vêm do gerador do Godot, e as referências
# usam o que já está gravado no arquivo de destino.
extends SceneTree

const EXTENSOES_TEXTO = ["tscn", "tres"]
const EXTENSOES_COM_ARQUIVO_UID = ["gd", "gdshader", "gdshaderinc"]

var _verificar := false
var _uids_novos := {} # caminho res:// -> texto "uid://..." criado nesta execução
var _pendencias: Array[String] = []
var _alterados: Array[String] = []


func _init():
	var cenas: Array[String] = []
	var scripts: Array[String] = []
	var escolhidos := 0
	for arg in OS.get_cmdline_user_args():
		if arg == "--verificar":
			_verificar = true
			continue
		escolhidos += 1
		var caminho: String = arg if arg.begins_with("res://") else "res://" + arg.replace("\\", "/").trim_prefix("./")
		caminho = caminho.trim_suffix("/")
		if DirAccess.dir_exists_absolute(caminho):
			_listar(caminho, cenas, scripts)
		elif not FileAccess.file_exists(caminho):
			printerr("arquivo não encontrado: ", arg)
		elif caminho.get_extension() in EXTENSOES_TEXTO:
			cenas.append(caminho)
		elif caminho.get_extension() in EXTENSOES_COM_ARQUIVO_UID:
			scripts.append(caminho)
	if escolhidos == 0:
		_listar("res://", cenas, scripts)

	# Primeiro dá UID a quem não tem, para as referências a eles já saírem completas.
	for caminho in scripts:
		_gravar_arquivo_uid(caminho)
	var textos := {}
	for caminho in cenas:
		textos[caminho] = _cabecalho_com_uid(caminho, FileAccess.get_file_as_string(caminho))
	for caminho in cenas:
		var original := FileAccess.get_file_as_string(caminho)
		var novo := _referencias_com_uid(caminho, textos[caminho])
		if novo != original:
			_salvar(caminho, novo)

	if _verificar:
		for p in _pendencias:
			print("falta UID: ", p)
		print("UIDs: %s" % ("tudo certo" if _pendencias.is_empty() else "%d pendência(s)" % _pendencias.size()))
		quit(0 if _pendencias.is_empty() else 1)
		return
	for p in _alterados:
		print("gravado: ", p)
	for p in _pendencias:
		print("AVISO sem UID para copiar: ", p)
	print("UIDs: %d arquivo(s) alterado(s)" % _alterados.size())
	if not _alterados.is_empty():
		# Os UIDs novos só entram no cache local (.godot/uid_cache.bin) quando o Godot
		# varre o projeto. Sem isso, ele avisa "invalid UID" e carrega pelo path.
		print("Atualizando o cache de UIDs (--import)...")
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"])
	quit()


func _listar(pasta: String, cenas: Array[String], scripts: Array[String]):
	if FileAccess.file_exists(pasta.path_join(".gdignore")):
		return
	for sub in DirAccess.get_directories_at(pasta):
		if not sub.begins_with("."):
			_listar(pasta.path_join(sub), cenas, scripts)
	for arquivo in DirAccess.get_files_at(pasta):
		var caminho := pasta.path_join(arquivo)
		if arquivo.get_extension() in EXTENSOES_TEXTO:
			cenas.append(caminho)
		elif arquivo.get_extension() in EXTENSOES_COM_ARQUIVO_UID:
			scripts.append(caminho)


func _gravar_arquivo_uid(caminho: String):
	if FileAccess.file_exists(caminho + ".uid"):
		return
	if _verificar:
		_pendencias.append(caminho + ".uid")
		return
	var uid := _sortear_uid(caminho)
	_salvar(caminho + ".uid", uid + "\n")


func _cabecalho_com_uid(caminho: String, texto: String) -> String:
	var fim := texto.find("]")
	var cabecalho := texto.substr(0, fim)
	if not cabecalho.begins_with("[gd_") or "uid=" in cabecalho:
		return texto
	if _verificar:
		_pendencias.append(caminho)
		return texto
	return cabecalho + ' uid="%s"' % _sortear_uid(caminho) + texto.substr(fim)


func _referencias_com_uid(caminho: String, texto: String) -> String:
	var linhas := texto.split("\n")
	for i in linhas.size():
		var linha := linhas[i]
		if not linha.begins_with("[ext_resource") or "uid=" in linha:
			continue
		var inicio := linha.find(' path="')
		if inicio == -1:
			continue
		var destino := linha.substr(inicio + 7, linha.find('"', inicio + 7) - inicio - 7)
		var uid := _uid_de(destino)
		if uid == "" or _verificar:
			_pendencias.append("%s -> %s" % [caminho, destino])
			continue
		linhas[i] = linha.insert(inicio, ' uid="%s"' % uid)
	return "\n".join(linhas)


func _uid_de(caminho: String) -> String:
	if _uids_novos.has(caminho):
		return _uids_novos[caminho]
	var id := ResourceLoader.get_resource_uid(caminho)
	return "" if id == ResourceUID.INVALID_ID else ResourceUID.id_to_text(id)


func _sortear_uid(caminho: String) -> String:
	var id := ResourceUID.create_id()
	while ResourceUID.has_id(id):
		id = ResourceUID.create_id()
	ResourceUID.add_id(id, caminho)
	_uids_novos[caminho] = ResourceUID.id_to_text(id)
	return _uids_novos[caminho]


func _salvar(caminho: String, texto: String):
	var arquivo := FileAccess.open(caminho, FileAccess.WRITE)
	arquivo.store_string(texto)
	arquivo.close()
	_alterados.append(caminho)
