#!/usr/bin/env bash
# Screenshot-Lauf mit Schutz des echten Spielstands: sichert user://saves vorher,
# lässt den Lauf mit leerem Spielstand laufen und stellt den echten danach wieder her.
# Aufruf: tests/shot.sh <ausgabe.png> [frames] [halten] [sequenz] [cheat]
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
USERDIR="$APPDATA/Godot/app_userdata/Scrap Empire"
BACKUP="$USERDIR/saves_backup_$$"
if [ -d "$USERDIR/saves" ]; then
  mv "$USERDIR/saves" "$BACKUP"
fi
cleanup() {
  rm -rf "$USERDIR/saves"
  if [ -d "$BACKUP" ]; then
    mv "$BACKUP" "$USERDIR/saves"
  fi
}
trap cleanup EXIT
cd "$ROOT" && timeout 180 "$GODOT" --path . --resolution 1920x1080 ${GODOT_EXTRA:-} -s tests/screenshot.gd -- "$@" 2>&1 | grep -iE "screenshot|SCRIPT ERROR|Parse|quip@|measure" | grep -v "quip@3:" | head -12
