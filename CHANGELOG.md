# Changelog – Scrap Empire

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Versionen folgen den Meilensteinen aus docs/03_ROADMAP.md (0.MS.Schritt).

## [0.3.0] – 2026-10-25 – MS3 Maschinen

### Hinzugefügt
- `data/recipes.json` mit fünf Rezepten: Eisenbarren (3 Schrott, 4 s), Kupferbarren (2 Kupfer, 4 s), Plastikplatte (2 Plastik, 3 s), Zahnrad und Schaltkreis „Denkbrett“ (bis zur Tech gesperrt)
- Fünf neue Items mit Icons und Verkaufswerten: Eisenbarren 6, Kupferbarren 10, Plastikplatte 7, Zahnrad 20, Denkbrett 30
- Schmelzofen (40 Schrott + 10 Kupfer) und Presse (60 Schrott + 20 Plastik) im Baumenü
- `Machine`: Eingangspuffer max. 10 je Item, Ausgangspuffer max. 10, Rezeptwahl nach Listenreihenfolge, Tech-Sperre je Rezept
- Darstellung: Fortschrittsbalken, Puffer-Icons über dem Gebäude (links Eingang, rechts Ausgang), Status „!“ bei vollem Ausgang und „?“ im Leerlauf
- A mit leerem Slot nimmt zuerst aus dem Ausgang, sonst aus dem Eingang (Fehleinwürfe korrigierbar)
- Rusty-Sprüche: falsches Item („Das passt da nicht rein.“), erste Maschine („Es brummt. Das ist gut. Glaube ich.“)
- 10 neue Tests (77 gesamt)

## [0.2.1] – 2026-10-25 – Maus im Baumodus

### Behoben
- Verkaufsterminal ließ sich per Mausklick nicht platzieren: linke Maustaste platziert/reißt ab, rechte Maustaste bricht ab (Feedback aus MS2-Test)

### Geändert
- Hinweiszeile zeigt je nach Eingabegerät Gamepad-Tasten oder Maus/Tastatur-Belegung

## [0.2.0] – 2026-10-25 – MS2 Bauen und Verkaufen

### Hinzugefügt
- `data/buildings.json`: Verkaufsterminal (2×2, 30 Schrott, Kostenfaktor 1,35) und Kiste (1×1, 10 Schrott, fest)
- Simulation: `Grid` (Belegung), `Building`/`SellTerminal`/`Chest`, `Economy` (Kostenformel, Bezahlen, Erstattung), Befehle place/remove/deposit/withdraw, `bolts`
- Verkaufsterminal verkauft 1 Item / 0,5 s aus einem Puffer (max. 40), Bolts zählen hoch, „+N“ schwebt über dem Terminal
- Kiste: 12 Slots × 20, A legt ein, A mit leerem Slot nimmt heraus
- Baumenü (Y): Gebäude mit Icon und Kosten, „Abreißen“, Fokusnavigation, B schließt
- Bau-Cursor: D-Pad/Pfeiltasten mit Wiederholung, rechter Stick, Maus; Vorschau grün/rot; A platziert, X dreht, B bricht ab; Reichweite 6 Kacheln
- Abreißen erstattet gezahlte Kosten und Inhalt (Rest fällt als lose Items)
- Hotbar-Auswahl (LB/RB) mit orangem Rahmen; Kontexthinweise unten („A: 20 Schrott in Verkaufsterminal einlegen“)
- Rusty-Sprüche bei Baufehlern (zu wenig Material, kein Platz, zu weit weg)
- Gebäude blockieren Rusty (Kollision)
- 24 neue Tests (67 gesamt)

## [0.1.1] – 2026-10-25 – Pause-Menü (aus MS6 vorgezogen)

### Hinzugefügt
- Pause-Menü (Start / Esc): „Fortsetzen“ und „Spiel beenden“, hält Spiel und Simulation an, Gamepad-Fokus mit orangem Rahmen, B/Start schließt
- Button-Stil im Theme (dicke Outline, 28 px Schrift, Fokus-Rahmen) für alle späteren Menüs
- `build.ps1` benennt die EXE nach der Projektversion (`ScrapEmpire_v0.1.1.exe`), damit ein laufendes Spiel den Build nicht blockiert

### Geändert
- Hinweiszeile nennt Start / Esc: Menü

## [0.1.0] – 2026-10-25 – MS1 Sammeln

### Hinzugefügt
- Tutorial-Karte 40×30 aus `data/maps/tutorial.json`: 6 Schrotthaufen, 2 Kabelknäuel, 2 Plastikbröckchen, 3 Wracks
- Simulation: `Inventory` (6×20), `ResourceNode` (Haufen wachsen alle 30 s um 1 bis 10; Wracks endlich), `LooseItem`, `SimRng`, `PlayerState`
- Saugen (RT / linke Maustaste): Kegel 90°, 2,5 Kacheln, 1 Item pro 0,25 s; lose Items vor Haufen; Hinweis bei vollem Inventar
- Hämmern (LT / rechte Maustaste): 1 Kachel Reichweite, 1 Schlag pro 0,5 s, schlägt je ein Item aus dem Wrack, Wrack verschwindet bei 0
- Darstellung: Knoten-Sprites (Haufen schrumpfen mit Menge, Wracks wackeln), lose Items mit Auf-und-ab, Einsammel-Flug zu Rusty, Saugkegel, Hammerschwung
- HUD: Hotbar mit 6 Slots (72 px), Bolts-Anzeige (Platzhalter), Hinweiszeile; Sprechblase über Rusty
- Rusty-Sprüche (`data/quips.json`, 11 Stück) für Start, volles Inventar, erster Schrott/Kupfer/Plastik, Wrack zerlegt, 60 s Leerlauf
- Lokalisierung DE/EN über `locale/strings.csv`, Sprache folgt dem System
- `DataRegistry` lädt `items.json` und `quips.json`; `MapLoader` mit Tests (43 Tests gesamt)

### Geändert
- Rusty dreht sich weich in Laufrichtung (Feedback aus MS0-Test)
- Vollbild im exportierten Build wird per Code gesetzt statt über Projekt-Override

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
