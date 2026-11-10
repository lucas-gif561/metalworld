#!/usr/bin/env bash
# Volta o projeto ao estado anterior as novidades do boss.
# Feche o Godot antes de rodar.
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf assets/sprites/inimigos/drone
rm -f scenes/enemies/inimigo_drone.tscn scenes/bosses/runa.tscn scenes/projectiles/particulas_boss.tscn
rm -f scripts/bosses/runa.gd scripts/bosses/runa.gd.uid
tar -xzf .backup/antes-novidades-boss.tar.gz
echo "Projeto restaurado. Pode abrir o Godot."
