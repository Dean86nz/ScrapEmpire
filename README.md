# Scrap Empire

Buntes 2D-Top-down-Automatisierungsspiel: Rusty, ein kleiner Schrottsammel-Roboter, räumt einen vermüllten Planeten auf und automatisiert nach und nach alles, bis hin zu sich selbst. Gamepad-first für den ROG Ally. Godot 4.7.2, GDScript.

Stand: **MVP (Version 1.0.0)**, Meilensteine 0 bis 11 fertig. Siehe `CHANGELOG.md`.

## Dokumente

- `docs/01_GDD.md` – Game Design Document (MVP, Progression, Cozy-Ergänzung, Phase 2)
- `docs/02_ARCHITECTURE.md` – Technische Architektur und Ordnerstruktur
- `docs/03_ROADMAP.md` – Meilensteine mit „fertig, wenn“-Kriterien
- `CHANGELOG.md`, `TODO.md`

## ROG Ally X

Controller in Armoury Crate auf **Gamepad-Modus** stellen (nicht Desktop-Modus). Woran man es erkennt: Die Hinweisleiste unten zeigt „Stick · RT · LT · Select“. Zeigt sie „WASD · LMB · Tab · T“, sendet der Ally Maus und Tastatur, dann klickt A statt zu bestätigen. RT und LT reagieren erst ab halbem Weg (Schwelle 0,5), damit ein leicht gedrückter Abzug nicht dauerhaft saugt.

## Steuerung (Gamepad / Tastatur)

| Aktion | Gamepad | Tastatur/Maus |
|---|---|---|
| Bewegen | linker Stick | WASD |
| Zielen | rechter Stick | Maus |
| Saugen / Hämmern | RT / LT | linke / rechte Maustaste |
| Am Schiff: alles abliefern / Bestätigen | A | E |
| Zurück / Abbrechen | B | Esc |
| Baumenü (Deko, ab Schiffsstufe 3) | Y | Tab |
| Schiff und Ziele (kurz) / Minimap ein-aus (lang) | Select | T / M |
| Hotbar-Slot | LB / RB | Mausrad |
| Turbo-Boost (Skill) | L3 | Shift |
| Baumodus: platzieren, drehen, abbrechen | A, X, B | LMB, Q, RMB |
| Schiff-Menü: Upgrades, Reparatur, Bots, Drohnen (am Schiff) | X | Q |
| Pause-Menü | Start | Esc |

Entwickler-Tasten (nur Debug-Builds, in der Release-EXE ohne Wirkung): F3 Debug-Overlay, F4 Cheat (Bolts, Material, XP), F5 speichern, F6 zwei Bots, F7 zwei Drohnen. Screenshot-Werkzeug (`tests/shot.sh`) kennt zusätzlich die Szenarien `auto`, `helpers`, `drones`, `cozy`, `endgame`.

## Spielablauf in Kürze

1. **Sammeln:** Rusty saugt Schrott (RT) und zerhämmert Müll (LT). Am Anfang passen 4 × 10 Teile in die Taschen.
2. **Abliefern:** Am abgestürzten Schiff liefert A alles auf einmal ab, das Schiff zahlt sofort Bolts.
3. **Aufrüsten:** X am Schiff öffnet das Schiff-Menü: Laderaum, Ertrag, Fahrtempo, Saugtempo, Werkzeugstufe.
4. **Reparieren:** Schiffsstufen schalten Blaupausen frei: Sammel-Bots (Stufe 2), Drohnen und Deko (Stufe 3), bessere Bots und Museum (Stufe 4). Stufe 5 hebt ab, wenn der Planet zu 80 % geheilt ist.
5. **Automatisieren:** Bots sammeln dort, wo du sie baust, Drohnen fliegen lose Teile einsammeln. Mehr und bessere Bots sind der Incremental-Teil.

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
