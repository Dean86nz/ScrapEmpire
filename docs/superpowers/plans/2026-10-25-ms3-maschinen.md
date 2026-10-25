# MS3 Maschinen – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schmelzofen und Presse verarbeiten Rohstoffe nach Rezepten aus JSON, mit Ein-/Ausgangspuffern, Fortschrittsanzeige, Stau-Feedback und manuellem Entnehmen; Zwischenprodukte bringen im Terminal mehr Bolts.

**Architecture:** `RecipeDef` (Daten) und `Machine extends Building` (Sim) in `src/sim/`. Die Welt filtert pro Maschine die verfügbaren Rezepte (Tech-Sperre: gear/circuit bleiben bis MS6 gesperrt). Die Darstellung liest `summary()` und den Fortschritt pro Frame.

**Spec:** `docs/01_GDD.md` Kap. 5.2, 6; `docs/02_ARCHITECTURE.md` 4.4; `docs/03_ROADMAP.md` MS3.

## Global Constraints

- Eingangspuffer max. 10 je Item, Ausgangspuffer max. 10 gesamt. Voller Ausgang stoppt die Maschine („!“). Leere Maschine ohne Inputs zeigt „?“.
- Rezeptwahl: erstes Rezept der Liste, dessen Inputs vollständig vorliegen, Tech freigeschaltet und Ausgang Platz hat.
- Dauern in Ticks (Eisenbarren 80, Kupferbarren 80, Plastikplatte 60, Zahnrad 100, Denkbrett 120).
- Kosten: Ofen 40 Schrott + 10 Kupfer (Faktor 1,35), Presse 60 Schrott + 20 Plastik (Faktor 1,35).

---

### Task 1: Daten und Sim (Tests)
**Files:** Create `data/recipes.json`, `src/sim/recipe_def.gd`, `src/sim/buildings/machine.gd`, `tests/test_machine.gd`; Modify `data/items.json` (5 Produkte), `data/buildings.json` (furnace, press), `src/sim/buildings/building.gd` (create), `src/sim/world.gd` (`recipes`, `unlocked_tech`, Rezeptzuweisung, `deposit_rejected`), `src/autoload/data_registry.gd`
- [x] Tests: Rezepte laden; Ofen nimmt Schrott bis 10, lehnt Plastik ab; 3 Schrott → nach 80 Ticks 1 Eisenbarren; Kupfer wählt Kupferrezept; Ausgang 10 voll → blocked, keine Verarbeitung; Zahnrad ohne Tech gesperrt, mit Tech aktiv; Denkbrett braucht beide Inputs; withdraw gibt Ausgang zuerst; Welt: deposit in Ofen per Befehl, Barren verkaufen = 6 Bolts; falsches Item → `deposit_rejected`.
- [x] Commit `ms3: Rezepte und Maschinen in der Sim`.

### Task 2: Darstellung
**Files:** Create `assets/sprites/buildings/{furnace,press}.svg`, `assets/sprites/items/{iron_bar,copper_bar,plastic_sheet,gear,circuit}.svg`; Modify `src/world/building_view.gd` (Fortschrittsbalken, Status „!“/„?“, Puffer-Icons links/rechts), `src/world/main.gd` (Sprüche: Ablehnung, erste Maschine), `data/quips.json`, `locale/strings.csv`
- [x] Screenshots: Ofen mit Fortschritt; Ofen mit „!“ bei vollem Ausgang. Commit `ms3: Maschinen-Darstellung`.

### Task 3: Doku und Build
- [x] CHANGELOG 0.3.0, TODO, Version, `build.ps1`.
