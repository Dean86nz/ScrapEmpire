#!/usr/bin/env bash
# „Speichern, Beenden, Weiterspielen“ über drei echte Programmstarts (tests/continue_check.gd).
# Schützt den echten Spielstand: user://saves wird vorher weggesichert und danach wiederhergestellt.
# Aufruf: tests/continue_check.sh    Exit-Code 1 bei Fehlern.
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
  rm -f "$USERDIR/continue_expect.json"
  if [ -d "$BACKUP" ]; then
    mv "$BACKUP" "$USERDIR/saves"
  fi
}
trap cleanup EXIT
cd "$ROOT"
fail=0
run() {
  local out
  out=$(timeout 120 "$GODOT" --path . --resolution 1280x720 -s tests/continue_check.gd -- "$1" 2>&1)
  local ec=$?
  echo "$out" | grep -E "^PASS|^FAIL|Prüfungen|   |SCRIPT ERROR|Parse Error|\[Laden"
  # Ein FAIL zählt auch dann, wenn das Programm danach regulär beendet wird (Phase „play“)
  if echo "$out" | grep -q "^FAIL"; then fail=1; fi
  return $ec
}
echo "== 1. Spielen, Speichern und Beenden"
run play
ec=$?
if [ ! -f "$USERDIR/saves/save_meta.json" ]; then
  echo "FAIL [play] kein Spielstand geschrieben (Exit $ec)"; fail=1
else
  echo "PASS [play] Spielstand geschrieben, Programm beendet (Exit $ec)"
fi
echo "== 2. Weiterspielen"
run continue || fail=1
echo "== 3. Rettung nach abgestürztem Laden"
run rescue || fail=1
echo "Ergebnis: $([ $fail -eq 0 ] && echo bestanden || echo FEHLER)"
exit $fail
