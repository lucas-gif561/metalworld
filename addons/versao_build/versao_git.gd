extends RefCounted
## Pergunta ao git de qual commit é o projeto. Usado na exportação
## (exportar_versao.gd) e pelo menu quando o jogo roda pelo editor.


## "<hash>[+] <dd/mm/aaaa hh:mm>" ("+" = havia alterações não commitadas),
## ou "sem git" se o git não responder
static func linha() -> String:
	var pasta = ProjectSettings.globalize_path("res://")
	var saida = []
	if OS.execute("git", ["-C", pasta, "rev-parse", "--short", "HEAD"], saida) != 0 or saida.is_empty():
		return "sem git"
	var hash_curto = saida[0].strip_edges()
	saida = []
	OS.execute("git", ["-C", pasta, "status", "--porcelain", "--untracked-files=no"], saida)
	if not saida.is_empty() and not saida[0].strip_edges().is_empty():
		hash_curto += "+"
	var agora = Time.get_datetime_dict_from_system()
	return "%s %02d/%02d/%04d %02d:%02d" % [hash_curto, agora.day, agora.month, agora.year, agora.hour, agora.minute]
