#!/usr/bin/env bash
# Roda todos os testes do jogo sem abrir janela.
#
# Uso:  tests/rodar_testes.sh
# O Godot é procurado na variável GODOT ou no PATH (godot / godot4).
# Ex.:  GODOT=~/Downloads/Godot_v4.7.2-stable_linux.x86_64 tests/rodar_testes.sh
#
# Falha se algum teste falhar OU se aparecer erro de script no meio.

cd "$(dirname "$0")/.." || exit 1

GODOT="${GODOT:-$(command -v godot || command -v godot4)}"
if [ -z "$GODOT" ]; then
	echo "Godot não encontrado. Rode assim: GODOT=/caminho/do/godot tests/rodar_testes.sh"
	exit 1
fi

"$GODOT" --headless --path . --import > /dev/null 2>&1

status=0
for teste in tests/teste_*.gd; do
	echo "### $teste"
	saida=$("$GODOT" --headless --audio-driver Dummy --path . --script "res://$teste" 2>&1)
	codigo=$?
	echo "$saida" | grep -E '^(==|  ok|  FALHOU|RESULTADO)|SCRIPT ERROR|ERROR:|at: '
	if [ $codigo -ne 0 ] || echo "$saida" | grep -qE 'SCRIPT ERROR|ERROR:'; then
		status=1
	fi
	echo
done

if [ $status -eq 0 ]; then
	echo "TUDO CERTO"
else
	echo "ALGUM TESTE FALHOU (veja acima)"
fi
exit $status
