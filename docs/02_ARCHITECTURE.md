# Scrap Empire – Technische Architektur

Stand: 2026-10-25 · Version 0.1 · Engine: **Godot 4.7.2 stable** (liegt im Projektordner)

## 1. Leitprinzipien

1. **Simulation und Darstellung sind getrennt.** Die Simulation (`sim/`) besteht aus reinen GDScript-Klassen (`RefCounted`), kennt keine Nodes, keine Zeit in Sekunden, keine Floats. Die Darstellung (`world/`, `ui/`) liest Sim-Zustand und zeichnet ihn interpoliert.
2. **20 Ticks pro Sekunde, deterministisch.** Ein Tick ist 50 ms. Alle Sim-Werte sind Integer (Positionen auf Bändern in 1/256-Kachel-Einheiten, Dauern in Ticks, Mengen in Stück). Gleiche Eingaben erzeugen gleiche Ergebnisse. Das macht Tests trivial und Save/Load exakt.
3. **Daten vor Code.** Items, Rezepte, Gebäude, Techknoten und Rusty-Sprüche liegen als JSON in `data/`. Balancing ändert nie GDScript.
4. **Gamepad ist der Primärpfad.** Jedes UI-Element wird zuerst mit Fokus-Navigation gebaut, Maus kommt kostenlos dazu.
5. **Jeder Meilenstein ist startbar.** `main.tscn` läuft immer; neue Systeme werden hinter Feature-Flags in `GameConfig` ergänzt, bis sie fertig sind.

## 2. Ordnerstruktur

```
ScrapEmpire/
├── project.godot
├── README.md
├── CHANGELOG.md
├── TODO.md
├── docs/
│   ├── 01_GDD.md
│   ├── 02_ARCHITECTURE.md
│   └── 03_ROADMAP.md
├── addons/                     (leer im MVP; kein Plugin-Zwang)
├── assets/
│   ├── sprites/                 Platzhalter-SVGs: robot/, items/, buildings/, tiles/, ui/
│   ├── fonts/                   (später; MVP nutzt skalierte Standardschrift)
│   └── audio/                   (später)
├── data/                        JSON, von DataRegistry geladen
│   ├── items.json
│   ├── recipes.json
│   ├── buildings.json
│   ├── tech.json
│   ├── quips.json               Rusty-Sprüche nach Auslöser
│   └── maps/
│       ├── tutorial.json
│       └── main_area.json
├── locale/
│   ├── strings.csv              key, de, en  (Godot-CSV-Import erzeugt .translation)
│   └── ...
├── src/
│   ├── autoload/                Singletons (project.godot → Autoload)
│   │   ├── game_config.gd       Konstanten, Feature-Flags, TILE_SIZE, TICKS_PER_SECOND
│   │   ├── data_registry.gd     lädt data/*.json in typisierte Defs
│   │   ├── event_bus.gd         globale Signale (item_sold, tech_unlocked, …)
│   │   ├── sim_clock.gd         Fixed-Step-Akkumulator, ruft World.tick()
│   │   ├── save_manager.gd      JSON-Save, Versionierung, Migrationen, Autosave
│   │   └── input_router.gd      Kontextwechsel (Spiel / Baumodus / Menü), Gerätetyp-Erkennung
│   ├── sim/                     reine Logik, keine Nodes
│   │   ├── world.gd             SimWorld: Daten, Signale, tick(), Befehlsverteilung, Weiterleitungen (388 Zeilen)
│   │   ├── systems/             Teilsysteme als statische Funktionen mit `w: SimWorld` als erstem Parameter
│   │   │   ├── research_system.gd    Tech, Skills, Modifikatoren, Rezepte, Verkaufswert
│   │   │   ├── node_system.gd        Haufen, Wracks, lose Items, Respawn
│   │   │   ├── building_system.gd    Bauen, Abreißen, Drehen, Einlegen, Entnehmen, Kosten
│   │   │   ├── tool_system.gd        Saugen, Hämmern, Magnet, Helfer-Arbeit
│   │   │   ├── helper_system.gd      Helfer-Kauf, Upgrades, Tick
│   │   │   ├── drone_system.gd       Drohnen-Kauf, Filter, Limit, Tick
│   │   │   ├── collectible_system.gd Fundstücke
│   │   │   └── ship_system.gd        Raumschiff: Stufen, Ausbau, Lager als Zahlungsquelle (count_available, pay)
│   │   ├── quests.gd            QuestState: geführte Aufgabenkette aus data/quests.json (Zähler + Zustandsprüfungen)
│   │   ├── buildings/ship.gd    Ship: Lager, Reserve-Verkauf, Stufen-Sprite
│   │   ├── grid.gd              Vector2i → Building, Belegungsprüfung
│   │   ├── inventory.gd         Slots, add/remove/can_add
│   │   ├── item_stack.gd
│   │   ├── buildings/
│   │   │   ├── building.gd      Basisklasse: pos, rotation, size, tick(), io-Ports
│   │   │   ├── machine.gd       Rezeptverarbeitung, Puffer, Fortschritt in Ticks
│   │   │   ├── furnace.gd
│   │   │   ├── press.gd
│   │   │   ├── sell_terminal.gd
│   │   │   ├── chest.gd
│   │   │   └── conveyor.gd      Lane-Logik, Kurven, Übergabe
│   │   ├── conveyor_network.gd  Tick-Reihenfolge der Bänder (von hinten nach vorne)
│   │   ├── resource_node.gd     Schrotthaufen/Wrack: Menge, Regeneration
│   │   ├── player_state.gd      Inventar, Position (Sim-Sicht), Werkzeugwerte
│   │   ├── tech_state.gd        freigeschaltete Knoten, laufende Forschung (Restticks), Modifikatoren
│   │   ├── task_list.gd         Autopilot: Schrittliste, Ausführungs-Zustandsmaschine
│   │   └── sim_rng.gd           seeded RNG für Wrack-Spawns
│   ├── world/                   Node2D-Darstellung
│   │   ├── main.tscn / main.gd  Einstieg, baut Szene aus Save oder Map
│   │   ├── player/
│   │   │   ├── player.tscn      CharacterBody2D, Bewegung, Zielrichtung
│   │   │   ├── player.gd
│   │   │   ├── suction_tool.gd
│   │   │   └── hammer_tool.gd
│   │   ├── building_view.gd     generische Ansicht, liest Building-Def + Zustand
│   │   ├── conveyor_renderer.gd MultiMeshInstance2D für Items auf allen Bändern
│   │   ├── resource_node_view.gd
│   │   ├── map_loader.gd        JSON-Map → TileMapLayer + Sim-World
│   │   ├── build_cursor.gd      Raster-Cursor, Vorschau, Platzieren/Drehen/Abreißen
│   │   └── camera.gd            folgt Spieler, Deadzone, Zoom fix
│   └── ui/
│       ├── theme/
│       │   └── scrap_theme.tres  Schriftgrößen ≥ 22 px, dicke Rahmen, Farben
│       ├── hud/                 Bolts, Hotbar, Kontexthinweise, Rusty-Sprechblase
│       ├── build_menu/
│       ├── tech_tree/
│       ├── pause_menu/
│       ├── task_editor/         Aufgabenliste anlegen (Schritttyp wählen, Ziel per Cursor)
│       ├── task_hud/            Icon-Kette der laufenden Aufgabenliste
│       ├── tutorial/
│       └── widgets/             FocusButton, ItemSlot, ButtonPrompt (Gamepad-Icons)
└── tests/
    ├── run_tests.gd             headless Runner: godot --headless -s tests/run_tests.gd
    ├── test_inventory.gd
    ├── test_conveyor.gd
    ├── test_machine.gd
    ├── test_save_migration.gd
    └── test_tech.gd
```

## 3. Schichten und Datenfluss

```
 Eingabe (Gamepad/Tastatur)
        │
        ▼
 InputRouter ──► Spielkontext: Player (world/) bewegt CharacterBody2D pro Frame
             ──► Baukontext:  BuildCursor erzeugt Befehle (place/rotate/remove)
             ──► Menükontext: UI-Fokusnavigation
        │
        ▼  Befehle (Dictionaries: {type, pos, rot, item, …})
 SimClock (fixed 50 ms) ──► World.apply_commands(queue) ──► World.tick()
        │                                                       │
        │                               Buildings.tick(), ConveyorNetwork.tick(),
        │                               ResourceNodes.tick(), TechState.tick(), TaskList.tick()
        ▼
 EventBus-Signale (item_sold, buffer_full, tech_unlocked, quip_requested)
        │
        ▼
 Darstellung liest Sim-Zustand jeden Frame, interpoliert mit SimClock.alpha
 (BuildingView, ConveyorRenderer, HUD)
```

**Der Spieler ist ein Sonderfall:** Bewegung läuft frame-basiert in `CharacterBody2D` für flüssige 60 FPS. Spielrelevante Wirkungen (Items aufsaugen, Hammerschlag, Einlegen) werden als Befehle in die Sim-Queue gestellt und im nächsten Tick ausgeführt. Dadurch bleibt alles, was zählt, deterministisch.

## 4. Kernsysteme im Detail

### 4.1 SimClock

```
_process(delta):
    accumulator += min(delta, 0.25)          # Spiralschutz bei Rucklern
    while accumulator >= TICK_DT:
        world.apply_commands(command_queue)
        world.tick()
        tick_count += 1
        accumulator -= TICK_DT
    alpha = accumulator / TICK_DT            # für Interpolation
```

Pause setzt `paused = true`; Autosave liest `tick_count` mit.

### 4.2 Grid und Gebäude

- `Grid` hält `Dictionary[Vector2i, Building]`; ein 2×2-Gebäude belegt 4 Einträge auf dasselbe Objekt.
- `Building` hat `pos: Vector2i`, `rot: int` (0–3), `def: BuildingDef`, `ports: Array[Port]` (Seite, Richtung in/out, lokale Zelle).
- Rotation dreht Port-Seiten per Modulo. Darstellung dreht nur das Sprite.

### 4.3 Förderbänder

- Jedes Band ist eine Zelle mit einer Lane (MVP: einspurig). Items liegen als `{item_id, offset}` mit `offset` 0..255 (1/256 Kachel).
- Pro Tick bewegt sich jedes Item um `speed = 256 × 2 Kacheln/s / 20 Ticks = 25,6 → 26` Einheiten (als Integer-Konstante in `GameConfig`, nie zur Laufzeit gerechnet).
- Mindestabstand 64 Einheiten (4 Items pro Kachel). Ein Item, das `offset ≥ 256` erreicht, versucht Übergabe an das Nachfolger-Band oder den Eingangs-Port der Nachbarmaschine; schlägt das fehl, bleibt es bei 255 und blockiert nachfolgende Items.
- **Kurven**: ein Band, dessen Eingang von der Seite kommt, zeichnet sich als Kurve; die Sim behandelt sie identisch (Eingang → Ausgang, 256 Einheiten). Kurvenform wird automatisch aus Nachbarschaft bestimmt, der Spieler platziert nur „Band mit Richtung“.
- **Tick-Reihenfolge**: `ConveyorNetwork` sortiert Bänder topologisch (Ziel vor Quelle), damit ein Item in einem Tick nicht zwei Zellen springt und Lücken korrekt entstehen. Sortierung wird nur bei Bauänderung neu berechnet.
- **Einfüge-Logik**: Maschinen-Ausgangs-Port legt alle 1 Tick ein Item auf das angrenzende Band, wenn `offset 0` frei ist. Auswurf: Band übergibt an Eingangs-Port, wenn Eingangspuffer < 10.
- **Rendering**: ein `MultiMeshInstance2D` pro Item-Typ, Instanzen werden pro Frame aus `offset` + `alpha` positioniert. Ziel: 2.000 Items bei 60 FPS auf dem Ally im 15-W-Modus. Band-Kacheln selbst sind ein `TileMapLayer` mit animierten Tiles.

### 4.4 Maschinen

```
tick():
    if progress_ticks == 0 and output_buffer < 10 and recipe_matches(input_buffer):
        consume inputs; progress_ticks = recipe.ticks
    elif progress_ticks > 0:
        progress_ticks -= 1
        if progress_ticks == 0: output_buffer.add(recipe.output)
    try_eject_to_port()
```

Rezeptwahl: erstes Rezept der Def-Liste, dessen Inputs vollständig im Eingangspuffer liegen und dessen Tech freigeschaltet ist.

### 4.5 Ressourcenknoten

`ResourceNode {item_id, amount, max_amount, regen_ticks}`; Wracks haben `regen_ticks = 0` und werden bei `amount == 0` entfernt. `World` spawnt alle 3.600 Ticks (3 min) ein neues Wrack an einer freien Randzelle via `SimRng`.

### 4.6 Aufgabenliste (Autopilot)

`TaskList` hält bis zu 12 Schritte `{type: GOTO|COLLECT|HAMMER|DEPOSIT|WITHDRAW, target: Vector2i, item_filter}` und einen Ausführungszustand `{index, wait_ticks, active}`. Der Spieler baut die Liste im `task_editor` (Schritttyp per Fokusliste, Ziel per `BuildCursor`). `GOTO` setzt im Player eine Zielposition; der Player-Node läuft per einfacher Geradeaus-Steuerung mit Kollisions-Ausweichen (kein A* im MVP; das Tutorial-/Hauptgebiet ist offen genug). Jeder Schritt hat einen Timeout von 200 Ticks (10 s), danach „Warte-Spruch“ und Retry.

### 4.7 Forschung

`TechState` hält `unlocked: Array[String]` und `current: {id, remaining_ticks}`. `start(id)` prüft Voraussetzungen und Bolts, zieht Bolts ab und setzt `remaining_ticks = zeit_s × 20`. `tick()` zählt herunter und sendet `tech_unlocked` über den EventBus. Modifikatoren (Saugreichweite, Laufgeschwindigkeit, Slots) werden als Dictionary aus `tech.json` aggregiert und von Player/Buildings abgefragt.

### 4.8 Speichern

```json
{
  "version": 3,
  "saved_at_unix": 1761400000,
  "tick_count": 123456,
  "player": { "pos": [12.5, 8.0], "inventory": [...], "tool": "suction" },
  "tech": { "unlocked": ["terminal", "furnace"], "current": { "id": "chest", "remaining_ticks": 120 } },
  "world": { "buildings": [...], "conveyor_items": [...], "resource_nodes": [...] },
  "tasks": { "steps": [...], "index": 0, "active": false },
  "economy": { "bolts": 1240 },
  "tutorial": { "step": 5 }
}
```

- `SaveManager.save()` alle 60 s, bei Pause, bei Fensterschließen. Zwei Dateien rotierend (`save_a.json`, `save_b.json`) plus `save_meta.json` mit Verweis auf die zuletzt gültige, damit ein Absturz beim Schreiben nie den Spielstand zerstört.
- Migrationen: `migrations: Dictionary[int, Callable]`, jede hebt um genau eine Version. Test `test_save_migration.gd` lädt Fixtures jeder alten Version.
- Pfad: `user://saves/` (Windows: `%APPDATA%/Godot/app_userdata/ScrapEmpire/`).

Offline passiert nichts (GDD 7.3). `saved_at_unix` wird trotzdem gespeichert, damit eine spätere Offline-Progression ohne Save-Migration nachgerüstet werden kann.

### 4.9 Eingabe

Input-Map-Aktionen werden zur Laufzeit von `InputMapSetup.apply()` (src/autoload/input_map_setup.gd) registriert, nicht in project.godot. Grund: lesbar, testbar (`tests/test_input_map.gd`), kein handgeschriebenes Serialisierungsformat. Aktionen: `move_left/right/up/down` (Stick + WASD), `aim_x/aim_y` (rechter Stick), `tool_primary` (RT/LMB), `tool_secondary` (LT/RMB), `interact` (A/E), `cancel` (B/Esc), `build_menu` (Y/Tab), `tool_swap` (X/Q), `hotbar_prev/next` (LB/RB/Mausrad), `tech_tree` (Select/T), `pause` (Start/Esc), `cursor_*` (D-Pad). Deadzone 0,2. `InputRouter` erkennt das zuletzt benutzte Gerät und tauscht Button-Icons im HUD (Xbox-Layout für Ally).

### 4.10 Lokalisierung

Alle sichtbaren Strings über `tr("KEY")`. `locale/strings.csv` mit Spalten `key,de,en`. Item-/Gebäude-/Tech-Namen stehen als Keys in den JSON-Daten (`"name_key": "ITEM_SCRAP"`). Standardsprache folgt dem System, umschaltbar im Pause-Menü.

### 4.11 Performance-Budget (Ally, 15 W, 1080p)

| Bereich | Budget pro Frame (16,6 ms) |
|---|---|
| Sim-Tick (bei 20/s im Schnitt 0,33 Ticks/Frame) | ≤ 3 ms pro Tick |
| Conveyor-Rendering 2.000 Items | ≤ 2 ms |
| UI | ≤ 1 ms |
| Rest (Physik Spieler, Kamera, Partikel) | ≤ 3 ms |
| Reserve | ≥ 7 ms |

Messung: eingebautes Debug-Overlay (F3), zeigt Tick-Zeit, FPS, Item-Anzahl. Perf-Testszene `tests/perf_conveyor.tscn` baut 500 Bänder mit 2.000 Items.

## 5. Tests

- Headless-Runner ohne Plugin: `tests/run_tests.gd` erbt `SceneTree`, lädt alle `test_*.gd`, ruft jede `test_*`-Methode, zählt Fehler, beendet mit Exit-Code.
- Aufruf: `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s tests/run_tests.gd`
- Getestet wird nur `sim/` und `autoload/` (deterministisch). Darstellung wird manuell auf dem Ally getestet (Testanleitung je Meilenstein).

## 6. Platzhalter-Grafik

Alle Sprites als handgeschriebene SVG in `assets/sprites/`: runde Formen, 4 px dunkle Outline, gesättigte Füllfarbe, kleines Gesicht auf Rusty. Godot importiert SVG direkt als Textur (Skalierung 2× für Schärfe). Items 32 px, Rusty 56 px, Gebäude 128 px (2×2), Band-Tiles 64 px. Ein Austausch gegen echte Assets ändert nur Dateien, keinen Code.

## 7. Git

- Repo-Root = Projektordner. `.gitignore`: `.godot/`, `*.import`-Reste nicht ignorieren (werden benötigt), `export/`, `Godot_v4.7.2-stable_win64.exe/` (die Engine gehört nicht ins Repo).
- Branch `main` ist immer lauffähig. Arbeit pro Meilenstein auf `ms/<nr>-<name>`, Merge nach bestandener Testanleitung.
- Commit-Format: `ms3: Presse verarbeitet Plastik zu Platten`.

## 8. Bewusst nicht gebaut (MVP)

Kein ECS, kein C# (erst wenn Perf-Messung es verlangt; Kandidat wäre `conveyor_network.gd`), kein Multithreading, kein Netzwerk, kein Plugin-Framework für Tests, keine prozedurale Welt, keine Shader außer Outline-Shader für Fokus-Hervorhebung.


---

# Teil B – Erweiterung Progression (2026-10-25)

## 9. Neue Datendateien

| Datei | Inhalt |
|---|---|
| `data/progression.json` | XP-Quellen, Level-Formel (Basis 100, Faktor 1,15, Rundung 5), Level-Obergrenze, Skillpunkte pro Level |
| `data/skills.json` | Äste, Skills, Stufen, Voraussetzungen, Modifikator-Schlüssel und Werte je Stufe |
| `data/scrap_objects.json` | Objekttypen: id, name_key, tier, tool (`suction`/`hammer`), yield (item → Menge) oder regen, respawn_s, sprite, size |
| `data/helpers.json` | Helfer-Kostenkurve, Maximalzahl, globale Upgrades, Namen, Farben, Sprüche |
| `data/tech.json` | wie geplant, plus Knoten 16/17 und Chrom-Kosten |

`ResourceNode` wird datengetrieben: `kind` verweist auf `scrap_objects.json`; neue Felder `tier`, `tool`, `respawn_ticks`, `spawn_tile`. Die drei bisherigen Haufen-Arten und das Wrack werden zu Einträgen dieser Datei (Wrack = „Verbeulter Kühlschrank“, Tier 2; neues Tier-1-Hammerobjekt „Rostiger Toaster“ für den Einstieg).

## 10. Neue Sim-Module

| Modul | Aufgabe |
|---|---|
| `src/sim/progression.gd` | `xp`, `level`, `skill_points`, `add_xp(amount, source)`, `xp_for_level(n)`; Signal `level_up(level)` |
| `src/sim/skill_state.gd` | Stufen je Skill, `can_buy(id)`, `buy(id)`, erzeugt `Modifiers` |
| `src/sim/modifiers.gd` | zentrales Dictionary aller aktiven Boni: `speed_mult`, `turn_mult`, `boost_cooldown`, `slots_add`, `stack_add`, `magnet_radius`, `sell_mult`, `rare_mult`, `bulk_bonus`, `hammer_tier`, `suction_tier`, `mine_speed_mult`, `range_add`. Wird aus Skills + Tech aggregiert; `PlayerState`, `SellTerminal` und Werkzeuge lesen nur hieraus. |
| `src/sim/worker_brain.gd` | Zustandsmaschine für Autopilot und Helfer: `GOTO`, `COLLECT`, `HAMMER`, `DEPOSIT`, `WITHDRAW`, `WAIT`; Timeout und Retry |
| `src/sim/helpers/helper.gd` | Helfer-Zustand: Name, Farbe, Zone, Lager, Inventar, nutzt `WorkerBrain` |
| `src/sim/spawn_manager.gd` | Respawn-Timer je Objekt, Spawn-Punkte aus der Karte |

Tick-Reihenfolge wird erweitert: Nodes → Buildings → Conveyors → Helpers → Player-Werkzeuge → Progression (XP-Buchungen des Ticks) → SpawnManager.

## 10a. Teilsysteme (seit v1.6.0, MS17)

`SimWorld` ist die Fassade: Felder, Signale, `tick()`, `queue_command()` und `_apply()`. Die Logik steht in `src/sim/systems/*.gd` als `static func name(w: SimWorld, …)`. Regeln:

- Systeme halten keinen Zustand und keine Referenz auf die Welt (keine Zyklen zwischen RefCounted-Objekten); alles Veränderliche liegt in `SimWorld`.
- Funktionen, die von Ansichten, Tests oder anderen Systemen gebraucht werden, haben eine gleichnamige Weiterleitung in `SimWorld` (z. B. `w.place_free(...)` → `BuildingSystem.place_free(w, ...)`). Nur intern genutzte Funktionen ruft `tick()`/`_apply()` direkt über das System auf.
- Neue Spielregeln kommen als neues System dazu (z. B. `ShipSystem` für die Basis), nicht in `world.gd`.

## 10b. Raumschiff und Aufgaben (seit v1.7.0, MS18a)

- `Ship` ist ein Gebäude (`buildable: false`, 3×3), genau eines je Welt (`MapLoader.ensure_ship`). Lager = `Inventory`; `tick()` verkauft ein Item je Takt über der Reserve; `SimWorld.tick()` bucht wie beim Terminal.
- Alle Kosten laufen über `ShipSystem.can_afford / pay / missing`: Inventar zuerst, dann Schiffslager. `TechState.can_start` nimmt zusätzliche Inventare entgegen.
- `QuestState` wird alle 10 Ticks geprüft (`check`); Zähler kommen über Welt-Signale (`item_collected`, `item_sold`, `wreck_destroyed`, `ship_received`), Zustandsprüfungen lesen die Welt. Abschluss → `quest_completed`. Alte Stände: `fast_forward`.

## 10c. Schmutz je Kachel (seit v1.10.0, MS21)

- `DirtMap` (`src/sim/dirt_map.gd`): `dirt` (0..255) und `start` (war anfangs schmutzig) als `PackedByteArray`, erzeugt aus Seed (FastNoiseLite) plus Müll-Kacheln. Zählt je Zone anfangs und jetzt schmutzige Kacheln; `ZoneTracker.cleanliness` nutzt das, wenn Schmutz aktiv ist.
- Putzen: `ToolSystem._tick_clean` (Saugkegel), `ToolSystem.clean_around` (Bots), `NodeSystem` beim Entfernen und Respawn von Müll. Geänderte Kacheln sammeln sich in `changed`.
- Darstellung: `DirtView` liest `take_changed()`, aktualisiert eine R8-Maske (Shader) und eine Farbtextur für Minimap/Karte und meldet `tiles_changed` an `NatureView` (Gras je Kachel).
- Spielstand: Schlüssel `dirt` mit Deflate+Base64; fehlt er, erzeugt `MapLoader.ensure_dirt` den Startschmutz.

## 10d. Schiff als Herz (seit v1.11.0, MS22)

- Sim: `ShipSystem._tick_clean_wave` lässt `Ship.clean_radius` alle `clean_wave_ticks` um eine Kachel wachsen, bis `clean_radius` der Stufe erreicht ist, und putzt den Ring (ohne Kleinschrott, Müll-Kacheln ausgenommen).
- Darstellung: `ShipFx` hängt an der `BuildingView` des Schiffs (Rauch, Lichter, Düsen, `celebrate`, `launch` → `launch_finished`, `land`). `Main` steuert Kamera-Fokus (`Camera2D.offset`), Weißblende und Endbildschirm; `Hud.stage_banner` (`StageBanner`) zeigt das Jubel-Schild, `StageTrack` die Stufenleiste im Schiff-Tab.

## 10e. Meilensteine und Sound (seit v1.12.0, MS23)

- `MilestoneState` (`src/sim/milestones.gd`): liest Zähler aus `QuestState.counters`, `DirtMap.cleaned_total` und `ShipSystem.upgrades_total`; `check()` alle 20 Ticks, Signal `SimWorld.milestone_reached`. Gespeichert wird nur die Zahl erreichter Stufen je Meilenstein.
- `QuestState.to_dict` speichert zusätzlich die ID der aktuellen Aufgabe; `from_dict` findet sie über die ID wieder.
- `Sfx` (Autoload) erzeugt die Effekte beim Start als `AudioStreamWAV` (22 kHz, 16 Bit) und spielt sie über den Bus `SFX` mit sechs Stimmen. Nur die Darstellung ruft `Sfx.play` auf, nie die Sim.

## 10f. Ereignisse (seit v1.19.0, MS30)

- `EventSystem` (`src/sim/systems/event_system.gd`): Zustand `SimWorld.events_state` = {next: Typ → Tick, warn: [{type, ticks_left, tiles}], drops: [{type, tile, ticks_left, loot}]}. Signale `event_warning`, `event_started` (Ziele und Verzögerungen für die Darstellung), `event_landed`. Zufall über `SimRng` (deterministisch). Bonus-Objekte tragen `ResourceNode.bonus` und stehen im Spielstand unter `bonus_nodes`.
- `EventView` (`src/world/event_view.gd`) zeigt Vorwarnung, UFO, fallende Säcke, Meteore und Einschläge passend zu den Zeitpunkten der Sim.

## 10g. Netz und Kurier (seit v1.23.0, MS34)

- `CollectionPoint` (Gebäude, `store`), `NetworkSystem`: `depot_for` (Sammelstelle der Zone, sonst Schiff), `zone_check` (eine je Zone), Befehle `assign_helper` (Zone oder `auto`) und `call_courier`, Tick für Automatik und Kuriere.
- `Helper.zone_id`/`auto`: Bots arbeiten in einer Zone; `_plan` bestimmt den Abgabeort neu.
- `Drone.State.FETCH`: Transport von der Sammelstelle mit dem meisten unverplanten Material zum Schiff hat Vorrang.
- `Courier`: TO_PLAYER → TO_DEPOT → HOME; Stufen aus `ship.json` „courier“; Upgrade „courier“ mit `requires_feature`.

## 10h. Themen-Zonen und Bosse (seit v1.25.0, MS36)

- Karte aus `tools/gen_main_map.py` (Zonen mit `name_key` und `theme`); Themen in `data/zone_themes.json`, gelesen über `DataRegistry.zone_theme()` von `WorldView` (Bodenton), `MeadowView` (Wiesen-Tönung, Regenbogen-Shader) und `NatureView` (Pflanzen, Deko, Tiere).
- `ResourceNode.boss/bots_needed/final`; `NetworkSystem.team_can_hit` erlaubt Bots (Planung, Aufgabe, Hammer) höhere Stufen; `NodeSystem._remove_node` zahlt die Belohnung, setzt Flags und sendet `boss_defeated`.
- `ZoneTracker.check_unlocks` wartet auf `boss_alive() == false`; `ShipSystem.can_upgrade` liefert `"boss"`, solange `final_boss` fehlt.

## 10i. Finale (seit v1.26.0, MS37)

- `main.gd`: `_launch_sequence` → `_finale_tour` (Kamera-Marker je Zone, Schild) → `ShipFx.launch` → `EndScreen.show_stats` → Signal `closed` → `_on_credits_closed`.
- `EndScreen` (`src/ui/end_screen/`): Sterne, Schiff, rollender `VBoxContainer`; Zahlen aus `FinaleStats.rows(w)` (`src/sim/finale_stats.gd`).

## 11. Neue Darstellung und UI

- HUD: XP-Leiste (`src/ui/hud/xp_bar.tscn`), Level-Up-Konfetti (`CPUParticles2D` über Rusty), Funken-Partikel bei „Zu hart“.
- `src/ui/progress_menu/` mit Tabs Techbaum / Skilltree / Nächste Ziele (LB/RB), gemeinsames Fokus-Raster-Widget `FocusGrid`.
- `src/world/helper_view.gd`: Rusty-Sprite mit Farbmodulation, Namensschild 22 px, eigene Sprechblase.
- Zonen-Cursor (Kreis) für Helfer, basiert auf `BuildCursor`.

## 12. Save-Format

`version` wird erhöht; neue Felder: `progression {xp, level, skill_points}`, `skills {id: stufe}`, `helpers [...]`, `spawns [...]`. Migrationen heben alte Stände mit Standardwerten an.
