# Scrap Empire

Buntes 2D-Top-down-Automatisierungsspiel. Gamepad-first für den ROG Ally. Godot 4.7.2, GDScript.

## Dokumente

- `docs/01_GDD.md` – Game Design Document (MVP)
- `docs/02_ARCHITECTURE.md` – Technische Architektur und Ordnerstruktur
- `docs/03_ROADMAP.md` – Meilensteine mit „fertig, wenn“-Kriterien
- `CHANGELOG.md`, `TODO.md`

## Entwickeln

Die Engine liegt in `Godot_v4.7.2-stable_win64.exe/` (nicht im Repo). Projekt im Editor öffnen:

```
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path . --editor
```

Spiel direkt starten:

```
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path .
```

## Tests (headless)

```
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

## Windows-Build

```
.\build.ps1
```

Ergebnis: `export/windows/ScrapEmpire.exe` (siehe Build-Abschnitt in `docs/03_ROADMAP.md`).
