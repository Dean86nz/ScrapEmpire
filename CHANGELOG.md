# Changelog – Scrap Empire

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Versionen folgen den Meilensteinen aus docs/03_ROADMAP.md (0.MS.Schritt).

## [0.0.1] – 2026-10-25 – MS0 Projektgerüst

### Hinzugefügt
- Godot-4.7.2-Projekt: 1920×1080, Stretch `canvas_items`, Mobile-Renderer, Vollbild nur im Export-Build
- Ordnerstruktur gemäß docs/02_ARCHITECTURE.md, Git-Repo mit .gitignore (Engine-Ordner, .godot/, export/ ausgeschlossen)
- Simulationskern: `TickAccumulator` (20 Ticks/s, Spiralschutz) und `SimWorld` (Tick-Zähler, Befehlswarteschlange)
- Autoloads: GameConfig, EventBus, DataRegistry (Stub), SimClock, SaveManager (Stub), InputRouter (Geräteerkennung, F11 Vollbild)
- Input-Map zur Laufzeit (`InputMapSetup`): Gamepad + Tastatur/Maus für alle MVP-Aktionen, Deadzone 0,2
- Rusty (SVG-Platzhalter) mit Bewegung per linkem Stick/WASD, Zielmarker per rechtem Stick/Maus, Kamera mit Zoom 1,5 und Begrenzung
- Flache Welt 120×90 Kacheln mit Sandboden und unsichtbaren Wänden
- Debug-Overlay (F3): FPS, Tick-Zeit, Tick-Zähler, Item-Anzahl, Eingabegerät
- Theme mit 24 px Standardschrift
- Headless-Test-Runner (`tests/run_tests.gd`, 10 Tests) und Screenshot-Werkzeug (`tests/screenshot.gd`)
- Export-Preset „Windows Desktop“ und `build.ps1`

## [Unreleased]

### Hinzugefügt
- 2026-10-25: Game Design Document (docs/01_GDD.md) mit Progressionskurve, Ökonomie-Formeln, Techbaum (15 Knoten) mit Forschungszeit, Aufgabenlisten-Konzept
- 2026-10-25: Technische Architektur und Ordnerstruktur (docs/02_ARCHITECTURE.md)
- 2026-10-25: Entwicklungsplan mit 9 Meilensteinen und „fertig, wenn“-Kriterien (docs/03_ROADMAP.md)
- 2026-10-25: TODO.md und CHANGELOG.md angelegt

### Geändert
- 2026-10-25: Entscheidungen Auftraggeber: keine Offline-Progression im MVP, Forschung mit Zeit, Aufgabenliste per Menü statt Aufzeichnung
