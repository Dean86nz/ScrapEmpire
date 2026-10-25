# TODO – Scrap Empire

## Jetzt (wartet auf Go)

- [x] Go für Plan erteilt (2026-10-25), Entscheidungen in GDD Kap. 14 eingearbeitet
- [ ] MS0 Projektgerüst (läuft)

## MS0 Projektgerüst

- [ ] project.godot anlegen (1920×1080, Viewport-Stretch, Godot 4.7.2)
- [ ] Ordnerstruktur gemäß docs/02_ARCHITECTURE.md
- [ ] Autoloads registrieren (GameConfig, DataRegistry, EventBus, SimClock, SaveManager, InputRouter)
- [ ] Input-Map mit allen Aktionen, Deadzone 0,2
- [ ] Theme mit Schriftgrößen 24/28/36 px
- [ ] Rusty-SVG-Platzhalter, Bewegung, Kamera
- [ ] Debug-Overlay (F3): FPS, Tick-Zeit, Item-Anzahl
- [ ] Headless-Test-Runner
- [ ] .gitignore, git init, erster Commit
- [ ] Export-Preset Windows, EXE auf dem Ally testen

## Offene Fragen an den Auftraggeber

- (beantwortet) Engine-EXE bleibt im Projektordner, per .gitignore ausgeschlossen
- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Sammeldrohnen
- Ereignisse: Meteoriten, Stromausfall, Überlastung
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf („Wracks wegschubsen“)
- Prestige-System
- Forschungslabore mit Forschungszeit
- Splitter/Merger, unterirdische Bänder
- Echte Assets, Audio, eigene Schrift
