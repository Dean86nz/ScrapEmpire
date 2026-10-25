# Scrap Empire – Entwicklungsplan (MVP)

Stand: 2026-10-25 · Version 0.2 (nach Ergänzung Progression)

Jeder Meilenstein endet mit einem lauffähigen Stand, einer Testanleitung für den ROG Ally und einem Eintrag in CHANGELOG.md. Reihenfolge ist fix; innerhalb eines Meilensteins wird in kleinen Schritten (jeweils ein Commit, jeweils startbar) gearbeitet.

## Erledigt

| MS | Name | Stand |
|---|---|---|
| **0** | Projektgerüst | fertig, gemerged (v0.0.1) |
| **1** | Sammeln | fertig, gemerged (v0.1.0), Pause-Menü vorgezogen (v0.1.1) |
| **2** | Bauen und Verkaufen | fertig, gemerged (v0.2.1) |

## Offen

| MS | Name | Inhalt | Fertig, wenn … |
|---|---|---|---|
| **3** | Maschinen | Schmelzofen, Presse, Rezeptsystem aus JSON, Ein-/Ausgangspuffer (10/10), Fortschrittsanzeige, Stau-Feedback („!“ bei vollem Ausgang), manuelles Entnehmen | … ein manuell gefüllter Ofen Schrott zu Eisenbarren macht, die Presse Plastik zu Platten, der Ofen bei vollem Ausgang stoppt und „!“ zeigt, Barren im Terminal mehr Bolts bringen als der Schrott. Test `test_machine.gd` grün. |
| **4** | XP, Level und Schrott-Stufen | `progression.json`, XP für Abbauen/Verkaufen/Bauen, Level-Kurve 100 × 1,15^(n-1), XP-Leiste im HUD, Level-Up mit Konfetti und Spruch, Skillpunkte werden gesammelt (noch nicht ausgebbar); `scrap_objects.json` mit Tier 1–5, Werkzeug-Stufe in `Modifiers`, „Zu hart!“-Feedback mit Funken, Respawn-Timer, neues Material Chrom, Tutorial-Map mit Toaster, Kühlschrank, Einkaufswagen, Raumschiff-Teil, Satellit, Roboter-Arm, Monolith | … die XP-Leiste bei jeder Aktion sichtbar wächst, Level 2 nach ca. 2 Minuten Sammeln erreicht wird (Konfetti, Spruch, Skillpunkt-Zähler), ein Tier-2-Objekt mit Tier-1-Werkzeug Funken und „Zu hart!“ auslöst, mit Dev-Cheat (F4: Werkzeug-Stufe +1) abbaubar wird und Chrom liefert, ein abgebauter Toaster nach 3 Minuten wieder erscheint. Tests für Progression und Tier-Prüfung grün. |
| **5** | Förderbänder | Gerade Bänder, automatische Kurven, Einfüge-/Auswurflogik an Maschinenports, topologische Tick-Reihenfolge, MultiMesh-Rendering, Perf-Szene mit 2.000 Items, Band-Platzierung per Ziehen | … eine Kette Haufen → Band → Ofen → Band → Terminal ohne Eingreifen Bolts erzeugt, Kurven korrekt laufen, ein Stau sichtbar rückwärts wächst, die Perf-Szene auf dem Ally im 15-W-Modus stabil 60 FPS hält. Test `test_conveyor.gd` grün. |
| **6** | Fortschritts-Menü: Techbaum, Skilltree, Nächste Ziele | `tech.json` (17 Knoten) mit Forschungszeit und Fortschrittsbalken, `skills.json` (4 Äste, 13 Skills) mit Voraussetzungen, Fokus-Raster-Widget, Tab „Nächste Ziele“ mit fehlenden Anforderungen, `Modifiers` wirken (Tempo, Slots, Stapel, Magnet, Preise, Werkzeug-Stufen, Reichweite) | … alle Techknoten erforschbar sind und sichtbar wirken, Skillpunkte per Gamepad ausgebbar sind, Schlagkraft Stufe 1 den Kühlschrank abbaubar macht, „Nächste Ziele“ korrekt anzeigt, was zum Raumschiff-Teil fehlt, kein Skill eine Sackgasse ist (Test über alle Pfade), ein Durchlauf Phase C zwischen Minute 20 und 40 erreicht. Tests `test_tech.gd`, `test_skills.gd` grün. |
| **7** | Speichern und Pause | Versioniertes JSON-Save mit Rotation, Autosave 60 s, Laden beim Start, Migrationsgerüst, Pause-Menü mit Sprache DE/EN und „Speichern und Beenden“, Lokalisierung aller Strings | … Spiel beenden und neu starten die Fabrik, XP, Skills und laufende Forschung exakt wiederherstellt, Sprachwechsel alle Texte sofort umstellt, ein abgebrochener Schreibvorgang den vorherigen Spielstand unversehrt lässt. Test `test_save_migration.gd` grün. |
| **8** | Tutorial und Autopilot | Fünf Tutorial-Schritte mit Belohnungen, Gebietsöffnung, Hauptgebiet-Map mit allen Tiers, `WorkerBrain`, Aufgaben-Editor (Y lang), Ausführen, Unterbrechen, Aufgaben-HUD, Autopilot v0.2 | … ein neuer Spielstand durch das Tutorial führt, Rusty eine Liste „Gehe zu Haufen → Sammle → Gehe zu Kiste → Lege ab“ mindestens 10-mal ohne Eingriff wiederholt, jede Stick-Eingabe sofort die Kontrolle zurückgibt. |
| **9** | Helfer-Roboter | `helpers.json`, Tech Helfer-Werkstatt, Kauf mit Kostenkurve und Chrom, Zonen-Cursor, Lager-Wahl, Helfer nutzen `WorkerBrain`, globale Upgrades, Namen, Farben, Sprüche, „Steckenbleiben“-Ereignis, Tab „Helfer“ im Fortschritts-Menü | … zwei Helfer gleichzeitig in verschiedenen Zonen abbauen und in Kisten liefern, der zweite Helfer teurer ist, ein Helfer ohne passende Werkzeug-Stufe ein Tier-2-Objekt sichtbar ignoriert und das kommentiert, das Spiel mit 6 Helfern 60 FPS hält. Test `test_worker_brain.gd` grün. |
| **10** | MVP-Politur | Alle Sprüche (Rusty, Helfer, Level-Up), Humor-Pass, Platzhalter-Grafik vereinheitlicht, Button-Icons je Gerät, Schriftgrößen-Audit, Tastatur/Maus-Pfad geprüft, Balancing-Durchlauf 2–3 h mit Level 20 am Ende, MVP-Ende-Bildschirm, README | … ein kompletter Durchlauf vom Tutorial bis Techbaum-Ende und Level 20 auf dem Ally in 2 bis 3 Stunden ohne Absturz, ohne Maus und ohne unlesbaren Text möglich ist, und der Export-Build aus einem Befehl entsteht. |

## Abhängigkeiten

```
MS3 → MS4 → MS5 → MS6 → MS7 → MS8 → MS9 → MS10
             │
             └── Perf-Nachweis (2.000 Items) ist Gate für MS6
```

- MS4 vor MS5: XP und Tiers sind klein, geben früh ein Ziel und liefern Chrom, das MS6 (Tech) braucht.
- MS6 bündelt Techbaum, Skilltree und Nächste Ziele, weil sie dasselbe Fokus-Raster-Widget und `Modifiers` teilen.
- MS9 nach MS8: Helfer nutzen `WorkerBrain` aus dem Autopilot.
- Wird in MS5 das Perf-Budget verfehlt, kommt vor MS6 ein Zwischenschritt „Conveyor in C#“.

## Scope-Hinweis

Die Ergänzung Progression erweitert den MVP um etwa zwei Meilensteine (MS4 teilweise, MS6 deutlich, MS9 komplett). Helfer-Roboter überschneiden sich mit den „Sammeldrohnen“ aus Phase 2 und sind bewusst der letzte Inhalts-Meilenstein: bei Zeitnot lassen sie sich ohne Umbau abtrennen, weil Autopilot und Helfer dieselbe Logik teilen.

## Arbeitsrhythmus pro Schritt

1. Ich nenne den Schritt und was er ändert (2–3 Sätze).
2. Code vollständig mit Dateipfaden, Tests für Sim-Teile zuerst.
3. Headless-Tests laufen grün, Spiel startet im Editor.
4. Testanleitung: „Starte das Spiel, tue X, du müsstest Y sehen.“
5. CHANGELOG.md und TODO.md aktualisiert, Commit.
6. Du testest auf dem Ally und gibst Feedback oder Go für den nächsten Schritt.

## Was ich von dir brauche

| Wann | Was |
|---|---|
| Vor MS3 | Go für die neue Reihenfolge (MS3 Maschinen, dann MS4 XP/Tiers) |
| Nach MS4 | Gefühl für XP-Tempo: Kommt Level 2 zu früh oder zu spät? |
| Nach MS5 | Perf-Messung auf dem Ally im 15-W-Modus (Zahlen aus dem Debug-Overlay) |
| Nach MS6 | Ein Balancing-Durchlauf mit Stoppuhr: Minute, in der du das erste Band legst, und Level am Ende |
| Nach MS10 | Kompletter Durchlauf, Liste aller Stellen, an denen du zur Maus greifen wolltest |
