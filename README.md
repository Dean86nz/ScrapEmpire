# Scrap Empire

Buntes 2D-Top-down-Automatisierungsspiel: Rusty, ein kleiner Schrottsammel-Roboter, räumt einen vermüllten Planeten auf und automatisiert nach und nach alles, bis hin zu sich selbst. Gamepad-first für den ROG Ally. Godot 4.7.2, GDScript.

Stand: **MVP (Version 1.0.0)**, Meilensteine 0 bis 11 fertig. Siehe `CHANGELOG.md`.

## Dokumente

- `docs/01_GDD.md` – Game Design Document (MVP, Progression, Cozy-Ergänzung, Phase 2)
- `docs/02_ARCHITECTURE.md` – Technische Architektur und Ordnerstruktur
- `docs/03_ROADMAP.md` – Meilensteine mit „fertig, wenn“-Kriterien
- `CHANGELOG.md`, `TODO.md`

## Steuerung (Gamepad / Tastatur)

| Aktion | Gamepad | Tastatur/Maus |
|---|---|---|
| Bewegen | linker Stick | WASD |
| Zielen | rechter Stick | Maus |
| Saugen / Hämmern | RT / LT | linke / rechte Maustaste |
| Einlegen, Entnehmen, Bestätigen | A | E |
| Zurück / Abbrechen | B | Esc |
| Baumenü (kurz) / Aufgaben-Editor (lang) | Y | Tab / L |
| Fortschritt (kurz) / Minimap ein-aus (lang) | Select | T / M |
| Hotbar-Slot | LB / RB | Mausrad |
| Turbo-Boost (Skill) | L3 | Shift |
| Baumodus: platzieren, drehen, abbrechen | A, X, B | LMB, Q, RMB |
| Pause-Menü | Start | Esc |

Entwickler-Tasten: F3 Debug-Overlay, F4 Cheat (Bolts, Material, XP), F5 speichern, F6 Perf-Szenario, F7 Beispielkette.

## Spielablauf in Kürze

1. **Startlager (Kapitel 1):** Schrott saugen, Terminal bauen, verkaufen, Schmelzofen erforschen. Der Ofen macht aus 3 Schrott einen Eisenbarren; Barren sind Baustoff für Förderband und Saugstation.
2. **Zone säubern:** Müll-Objekte (Toaster, Kühlschränke …) zerhämmern. Ab 50 % Reinigungsgrad öffnet sich das Tor zur nächsten Zone. Minimap und Karte zeigen nur entdeckte Zonen; der Boden wird mit jeder Stufe grüner.
3. **Automatisieren:** Saugstation an einen Haufen, Band zum Ofen, Band zum Terminal. Später Autopilot (Aufgabenliste für Rusty) und Helfer-Roboter, die Zonen allein aufräumen.
4. **Weiterkommen:** Forschung kostet Bolts und Produkte (Barren, Platten, Zahnräder, Schaltkreise, Chrom), Skills kosten Skillpunkte aus Leveln. Tab „Kapitel“ (Select) zeigt immer die nächsten Ziele.

## Entwickeln

Die Engine liegt in `Godot_v4.7.2-stable_win64.exe/` (nicht im Repo).

```
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path . --editor
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe --path .
```

## Tests (headless)

```
.\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd
```

Screenshot-Läufe nur über `tests/shot.sh` (sichert den echten Spielstand). Datei-Tests nutzen `SaveManager.use_directory("user://saves_test/")`.

## Windows-Build

```
.\build.ps1
```

Ergebnis: `export/windows/ScrapEmpire_v<version>.exe` (Version aus `project.godot`). Export-Templates 4.7.2 müssen unter `%APPDATA%\Godot\export_templates\4.7.2.stable\` liegen.

## Daten (Balancing ohne Code)

`data/items.json`, `recipes.json`, `buildings.json`, `tech.json`, `skills.json`, `scrap_objects.json`, `progression.json`, `helpers.json`, `tutorial.json`, `quips.json`, `maps/main.json` (Generator: `tools/gen_main_map.py`). Texte: `locale/strings.csv` (DE/EN).
