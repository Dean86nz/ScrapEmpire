# TODO – Scrap Empire

## Jetzt

- [ ] MS0 auf dem ROG Ally X testen (EXE in export/windows/), Feedback zu Bewegung, Schriftgröße, Zoom
- [ ] Nach Ally-Feedback: Branch `ms/0-projektgeruest` nach `main` mergen, MS1 beginnen

## MS0 Projektgerüst (erledigt, wartet auf Ally-Test)

- [x] project.godot (1920×1080, Viewport-Stretch, Godot 4.7.2)
- [x] Ordnerstruktur gemäß docs/02_ARCHITECTURE.md
- [x] Autoloads (GameConfig, DataRegistry, EventBus, SimClock, SaveManager, InputRouter)
- [x] Input-Map mit allen Aktionen, Deadzone 0,2 (zur Laufzeit, testbar)
- [x] Theme mit 24 px Standardschrift
- [x] Rusty-SVG-Platzhalter, Bewegung, Kamera (Zoom 1,5)
- [x] Debug-Overlay (F3)
- [x] Headless-Test-Runner (10 Tests grün)
- [x] .gitignore, git init, Commits auf Branch `ms/0-projektgeruest`
- [x] Export-Preset Windows, build.ps1, EXE startet auf dem PC
- [ ] EXE auf dem Ally getestet

## MS1 Sammeln (nächster Meilenstein)

- [ ] data/items.json, DataRegistry lädt JSON
- [ ] Tutorial-Map als JSON (40×30), MapLoader
- [ ] ResourceNode (Haufen, Knäuel, Bröckchen, Wracks) in Sim + Darstellung
- [ ] Inventory (6 Slots × 20) mit Tests
- [ ] Schrottsauger (Kegel 90°, 2,5 Kacheln, 1 Item/0,25 s)
- [ ] Hammer (1 Kachel, 1 Schlag/0,5 s), Wrack zerlegen
- [ ] Hotbar-HUD (72-px-Slots), Sprechblase, erste 10 Rusty-Sprüche (data/quips.json)
- [ ] Regeneration der Haufen

## Offene Fragen an den Auftraggeber

- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Offline-Progression (Fabrik läuft bei geschlossenem Spiel weiter)
- Sammeldrohnen
- Ereignisse: Meteoriten, Stromausfall, Überlastung
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf („Wracks wegschubsen“)
- Prestige-System
- Forschungslabore
- Splitter/Merger, unterirdische Bänder
- Mehrere Aufgabenlisten mit Bedingungen
- Echte Assets, Audio, eigene Schrift
- Icon in der EXE einbetten (rcedit konfigurieren)
