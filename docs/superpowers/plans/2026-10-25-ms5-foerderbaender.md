# MS5 Förderbänder – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Förderbänder transportieren Items von Maschinen-Ausgängen zu Eingängen, mit Kurven, Stau und Seiteneinspeisung; eine Saugstation holt Rohstoffe aus Haufen, sodass Haufen → Band → Ofen → Band → Terminal ohne Spieler Bolts erzeugt. 2.000 Items laufen bei 60 FPS.

**Architecture:** `Conveyor extends Building` hält Items als `{item, offset 0..255}`; `SimWorld` baut bei jeder Bauänderung die Band-Reihenfolge (Ziel vor Quelle) und die Kurvenformen neu und tickt Bänder, dann Maschinen-Ausgänge. `Extractor` (Saugstation) zieht aus einem Nachbarhaufen. `ConveyorRenderer` zeichnet alle Items per MultiMesh je Itemtyp.

**Spec:** `docs/02_ARCHITECTURE.md` 4.3; `docs/01_GDD.md` Kap. 6; `docs/03_ROADMAP.md` MS5.

## Global Constraints

- Band: 1×1, 1 Schrott, Festpreis. Länge 256 Einheiten, Geschwindigkeit 26 Einheiten/Tick (≈ 2 Kacheln/s), Mindestabstand 64 (4 Items je Kachel).
- Übergabe am Ende: an Band (hinten frei: letztes Item ≥ 64) oder an Gebäude mit passendem Eingangsport (Maschine je Item max 10, Terminal max 10 per Band, Kiste von allen Seiten).
- Seiteneinspeisung bei Offset 128; ist das seitliche Band der einzige Zulauf, wird das Band zur Kurve (Einspeisung bei 0).
- Maschinen-Ausgang legt pro Tick höchstens ein Item auf das Band vor dem Ausgangsport.
- Saugstation: 1×1, 20 Schrott + 5 Kupfer, zieht alle 60 Ticks (3 s) ein Item aus einem angrenzenden Haufen (Tier 1), Füllstand des Haufens bleibt (sie gräbt tiefer), Puffer 5, Ausgang vorne.
- Bänder blockieren Rusty nicht. Spieler kann per A ein Item auf ein Band legen und vorne eines herunternehmen.
- Ziehen im Baumodus: A gehalten und Cursor bewegt legt Bänder in Bewegungsrichtung und dreht das vorherige mit.
- F6 (Dev): Perf-Szenario mit ~480 Bändern und ~1.900 Items in der aktuellen Welt.

---

### Task 1: Sim (Tests)
**Files:** Create `src/sim/buildings/conveyor.gd`, `src/sim/buildings/extractor.gd`, `src/sim/conveyor_network.gd`, `tests/test_conveyor.gd`; Modify `data/buildings.json`, `src/sim/buildings/building.gd` (create, `port_tiles()`, `pop_output_one`), `src/sim/buildings/machine.gd` (`pop_output_one`), `src/sim/buildings/sell_terminal.gd` (`BELT_MAX`), `src/sim/world.gd` (Netzwerk, Befehle rotate, place_free)
- [ ] Tests: Item wandert 26/Tick und stoppt bei 255; Abstand 64 erzwungen; Übergabe Band→Band; Stau wenn Ziel voll; Band→Ofen bis 10; Ofen→Band; Kurvenerkennung; Reihenfolge über 3 Bänder ohne Lücke; Saugstation zieht aus Haufen; Terminal nimmt per Band max 10; Kette Haufen→…→Terminal erzeugt Bolts.
- [ ] Commit.

### Task 2: Darstellung und Bedienung
**Files:** Create `assets/sprites/buildings/{conveyor,conveyor_turn,extractor}.svg`, `src/world/conveyor_renderer.gd`; Modify `src/world/building_view.gd`, `src/world/world_view.gd`, `src/world/build_cursor.gd` (Ziehen), `src/world/main.gd` (F6 Perf, Szenario), `locale/strings.csv`, `tests/screenshot.gd` (Szenario-Cheat)
- [ ] Screenshots: Kette läuft, Kurve, Stau; Perf-Szenario mit FPS im Overlay. Commit.

### Task 3: Doku und Build
- [ ] CHANGELOG 0.5.0, TODO, GDD (Saugstation), Version, Build.
