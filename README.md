# Scrap Empire

Buntes 2D-Top-down-Automatisierungsspiel: Rusty, ein kleiner Schrottsammel-Roboter, räumt einen vermüllten Planeten auf und automatisiert nach und nach alles, bis hin zu sich selbst. Gamepad-first für den ROG Ally. Godot 4.7.2, GDScript.

Stand: **MVP (Version 1.0.0)**, Meilensteine 0 bis 11 fertig. Siehe `CHANGELOG.md`.

## Dokumente

- `docs/01_GDD.md` – Game Design Document (MVP, Progression, Cozy-Ergänzung, Phase 2)
- `docs/02_ARCHITECTURE.md` – Technische Architektur und Ordnerstruktur
- `docs/03_ROADMAP.md` – Meilensteine mit „fertig, wenn“-Kriterien
- `CHANGELOG.md`, `TODO.md`

## ROG Ally X

Controller in Armoury Crate auf **Gamepad-Modus** stellen (nicht Desktop-Modus). Woran man es erkennt: Die Hinweisleiste unten zeigt „Stick · RT · Y · Select“. Zeigt sie „WASD · LMB · Tab · T“, sendet der Ally Maus und Tastatur, dann klickt A statt zu bestätigen. RT und LT reagieren erst ab halbem Weg (Schwelle 0,5), damit ein leicht gedrückter Abzug nicht dauerhaft saugt.

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
| Schiff ausbauen (am Schiff) | X | Q |
| Pause-Menü | Start | Esc |

Entwickler-Tasten: F3 Debug-Overlay, F4 Cheat (Bolts, Material, XP), F5 speichern, F6 Perf-Szenario, F7 Beispielkette. Screenshot-Werkzeug (`tests/shot.sh`) kennt zusätzlich die Szenarien `auto`, `helpers`, `drones`, `cozy`, `endgame`.

## Spielablauf in Kürze

1. **Startlager (Kapitel 1):** Rusty ist mit seinem Schiff abgestürzt. Das Wrack ist die Basis: Schrott hineinlegen (A), das Schiff verkauft alles über der Reserve von allein. Der Schmelzofen macht aus 3 Schrott einen Eisenbarren; Barren sind Baustoff für Förderband, Saugstation und den Schiffsausbau (X am Schiff).
2. **Aufgaben:** Oben steht immer genau eine Aufgabe mit Kästchen. Die Kette führt durch das ganze Spiel; Tab „Kapitel“ (Select) zeigt erledigte und kommende Aufgaben.
3. **Zone säubern:** Müll-Objekte (Toaster, Kühlschränke …) zerhämmern. Ab der Tor-Schwelle öffnet sich das Tor zur nächsten Zone. Der Planetenbalken links oben zeigt die Heilung des ganzen Planeten; der Boden wird mit jeder Stufe grüner.
4. **Automatisieren:** Saugstation an einen Haufen, Band zum Ofen, Band zum Schiff. Später Autopilot, Helfer-Roboter und Drohnen. Verkaufsterminals sind Außenposten für entfernte Zonen (eines je Zone).
5. **Weiterkommen:** Forschung kostet Bolts und Produkte; Rustys Inventar und das Schiffslager zählen, Kisten nicht. Skills kosten Skillpunkte aus Leveln.

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
