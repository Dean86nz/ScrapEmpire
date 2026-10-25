# Scrap Empire – Entwicklungsplan (MVP)

Stand: 2026-10-25 · Version 0.1

Jeder Meilenstein endet mit einem lauffähigen Stand, einer Testanleitung für den ROG Ally und einem Eintrag in CHANGELOG.md. Reihenfolge ist fix; innerhalb eines Meilensteins wird in kleinen Schritten (jeweils ein Commit, jeweils startbar) gearbeitet.

| MS | Name | Inhalt | Fertig, wenn … |
|---|---|---|---|
| **0** | Projektgerüst | Godot-Projekt, Ordnerstruktur, Autoloads (leer), Input-Map, Theme mit 24-px-Schrift, Git-Repo, Test-Runner, Debug-Overlay, Rusty als SVG-Platzhalter bewegt sich mit linkem Stick über eine flache Fläche, Kamera folgt | … die exportierte Windows-EXE auf dem Ally in 1920×1080 startet, Rusty sich mit dem linken Stick flüssig bewegt, das Overlay 60 FPS zeigt und `run_tests.gd` headless mit 0 Fehlern durchläuft. |
| **1** | Sammeln | Tutorial-Map als JSON geladen, Schrotthaufen/Kabelknäuel/Plastikbröckchen, Wracks, Schrottsauger (rechter Stick + RT), Hammer (LT), Inventar-Sim, Hotbar-HUD, Regeneration, erste 10 Rusty-Sprüche, Sprechblase | … man alle drei Rohstoffe einsammeln kann, das Inventar sich sichtbar füllt und bei „voll“ ein Spruch erscheint, ein Wrack nach Hammerschlägen verschwindet und Items ausspuckt, Haufen nachwachsen. Tests für Inventory und ResourceNode grün. |
| **2** | Bauen und Verkaufen | Rastercursor (D-Pad/rechter Stick), Baumenü (Y) mit Fokusnavigation, Platzieren/Drehen/Abreißen, Verkaufsterminal mit manuellem Einlegen (A), Bolts-Anzeige, Kiste, Kosten-Progressionsformel | … man in unter 2 Sekunden ein Terminal platzieren, drehen und mit A Schrott einlegen kann, Bolts hochzählen, ein zweites Terminal teurer ist und Abreißen die Kosten erstattet. Alles ohne Maus. |
| **3** | Maschinen | Schmelzofen, Presse, Rezeptsystem aus JSON, Ein-/Ausgangspuffer, Fortschrittsanzeige, Stau-Feedback („!“ bei vollem Ausgang), manuelles Entnehmen | … ein manuell gefüllter Ofen Schrott zu Eisenbarren macht, die Presse Plastik zu Platten, der Ofen bei vollem Ausgang stoppt und „!“ zeigt, Barren im Terminal mehr Bolts bringen als der Schrott. Test `test_machine.gd` grün. |
| **4** | Förderbänder | Gerade Bänder, automatische Kurven, Einfüge-/Auswurflogik an Maschinenports, topologische Tick-Reihenfolge, MultiMesh-Rendering, Perf-Szene mit 2.000 Items, Band-Platzierung per Ziehen (Stick gedrückt halten) | … eine Kette Haufen → Band → Ofen → Band → Terminal ohne Eingreifen Bolts erzeugt, Kurven korrekt gezeichnet und durchlaufen werden, ein Stau sichtbar rückwärts wächst, die Perf-Szene auf dem Ally im 15-W-Modus stabil 60 FPS hält. Test `test_conveyor.gd` grün (Übergabe, Blockierung, Kurve). |
| **5** | Techbaum und Ökonomie | 15 Knoten aus `tech.json`, Techbaum-Menü (Select) als fokussierbares Raster, Forschung mit Bolts-Kosten und Forschungszeit (Fortschrittsbalken im HUD, eine Forschung gleichzeitig), Freischaltungen wirken (Werkzeuge, Rezepte, Gebäude, Geschwindigkeit), Balancing-Tabelle angewandt | … alle 15 Knoten erforschbar sind, der Balken sichtbar läuft und bei 0 die Freischaltung sofort wirkt (z. B. größerer Saugkegel), gesperrte Knoten ihre Voraussetzung anzeigen, ein Durchlauf laut Zielkurve Phase C zwischen Minute 20 und 40 erreicht (Selbsttest, Zeit stoppen). Test `test_tech.gd` grün. |
| **6** | Speichern und Pause | Versioniertes JSON-Save mit Rotation, Autosave 60 s, Laden beim Start, Migrationsgerüst, Pause-Menü (Fortsetzen, Sprache DE/EN, Speichern und Beenden), Lokalisierung aller bisherigen Strings | … Spiel beenden und neu starten die Fabrik exakt wiederherstellt (gleiche Items an gleichen Positionen, laufende Forschung mit Restzeit), Sprachwechsel alle Texte sofort umstellt, ein absichtlich abgebrochener Schreibvorgang den vorherigen Spielstand unversehrt lässt. Test `test_save_migration.gd` grün. |
| **7** | Tutorial und Autopilot | Fünf Tutorial-Schritte mit Belohnungen, Gebietsöffnung nach Osten, Hauptgebiet-Map, Aufgaben-Editor (Y lang): Schritte hinzufügen, Ziel per Cursor, sortieren, löschen, starten; Ausführen, Unterbrechen, Aufgaben-HUD, Timeout und Warte-Sprüche, Autopilot v0.2 | … ein neuer Spielstand durch das Tutorial führt und das Hauptgebiet öffnet, Rusty eine erstellte Liste „Gehe zu Haufen → Sammle → Gehe zu Kiste → Lege ab“ mindestens 10-mal ohne Eingriff wiederholt, jede Stick-Eingabe sofort die Kontrolle zurückgibt, Rusty bei leerem Haufen wartet und einen Spruch sagt. |
| **8** | MVP-Politur | Alle 40 Rusty-Sprüche, Humor-Pass über Item-Namen, Platzhalter-Grafik vereinheitlicht (Outline, Farben), Button-Icons je Gerät, Schriftgrößen-Audit (≥ 22 px), Tastatur/Maus-Pfad geprüft, Balancing-Durchlauf 2–3 h, MVP-Ende-Bildschirm, README mit Build-Anleitung | … ein kompletter Durchlauf vom Tutorial bis zum letzten Techknoten auf dem Ally in 2 bis 3 Stunden ohne Absturz, ohne Maus und ohne unlesbaren Text möglich ist, und der Export-Build reproduzierbar aus einem Befehl entsteht. |

## Abhängigkeiten

```
MS0 → MS1 → MS2 → MS3 → MS4 → MS5 → MS6 → MS7 → MS8
                          │
                          └── Perf-Nachweis (2.000 Items) ist Gate für MS5
```

Wird in MS4 das Perf-Budget auf dem Ally verfehlt, wird vor MS5 ein Zwischenschritt „Conveyor in C#“ eingeschoben. Das ist der einzige geplante Punkt, an dem C# in Frage kommt.

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
| Vor MS0 | Go erteilt am 2026-10-25, Entscheidungen in GDD Kap. 14 eingearbeitet |
| Nach MS0 | Erster Ally-Test: läuft die EXE, fühlt sich die Bewegung gut an, ist die Schrift lesbar. Ich sage Bescheid, wann der Ally angeschlossen werden soll. |
| Nach MS4 | Perf-Messung auf dem Ally im 15-W-Modus (Zahlen aus dem Debug-Overlay) |
| Nach MS5 | Ein Balancing-Durchlauf mit Stoppuhr: Minute, in der du das erste Band legst |
| Nach MS8 | Kompletter Durchlauf, Liste aller Stellen, an denen du zur Maus greifen wolltest |
