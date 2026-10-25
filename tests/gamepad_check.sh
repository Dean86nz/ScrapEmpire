#!/usr/bin/env bash
# Gamepad-Prüfung aller Menüs (tests/gamepad_check.gd) mit Schutz des echten Spielstands:
# sichert user://saves vorher, lässt den Lauf mit leerem Testverzeichnis laufen, stellt danach wieder her.
# Aufruf: tests/gamepad_check.sh    Exit-Code 1 bei Fehlern.
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
cd "$ROOT" && timeout 180 "$GODOT" --headless --path . -s tests/gamepad_check.gd 2>&1 | grep -E "^PASS|^FAIL|Prüfungen|SCRIPT ERROR|Parse Error"
exit "${PIPESTATUS[0]}"
