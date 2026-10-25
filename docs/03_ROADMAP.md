# Scrap Empire – Entwicklungsplan (MVP)

Stand: 2026-10-25 · Version 0.3 (nach Ergänzung Cozy/Welt)

Jeder Meilenstein endet mit einem lauffähigen Stand, einer Testanleitung und einem Eintrag in CHANGELOG.md. Vor jedem neuen Meilenstein wartet der Lead Dev auf das Go des Auftraggebers. Reihenfolge ist fix; innerhalb eines Meilensteins wird in kleinen Schritten (jeweils ein Commit, jeweils startbar) gearbeitet.

## Erledigt

| MS | Name | Stand |
|---|---|---|
| **0** | Projektgerüst | v0.0.1 |
| **1** | Sammeln | v0.1.0, Pause-Menü vorgezogen (v0.1.1) |
| **2** | Bauen und Verkaufen | v0.2.1 |
| **3** | Maschinen | v0.3.0 |
| **4** | XP, Level und Schrott-Stufen | v0.4.0 |
| **5** | Förderbänder und Saugstation | v0.5.0 (60 FPS, 2,7 ms Tick bei 1.884 Items am Laptop) |
| **6** | Fortschritts-Menü: Techbaum, Skilltree, Nächste Ziele | v0.6.0 |
| **7** | Speichern und Pause | v0.7.0, F7-Fix v0.7.1 |

## Offen

| MS | Name | Inhalt | Fertig, wenn … |
|---|---|---|---|
| **8** | Tutorial und Autopilot | Fünf Tutorial-Schritte mit Belohnungen, Gebietsöffnung, Hauptgebiet-Map (120×90) mit allen Tiers und Zonen-Rechtecken, `WorkerBrain`, Aufgaben-Editor (Y lang), Ausführen, Unterbrechen, Aufgaben-HUD, Autopilot v0.2; Save-Version 2 (Aufgaben, Tutorial-Schritt) | … ein neuer Spielstand durch das Tutorial führt, Rusty eine Liste „Gehe zu Haufen → Sammle → Gehe zu Kiste → Lege ab“ mindestens 10-mal ohne Eingriff wiederholt, jede Stick-Eingabe sofort die Kontrolle zurückgibt. |
| **9** | Zonen, Minimap und Karte (Grundlagen A) | Zonen in der Karten-JSON, Reinigungsgrad je Zone (Müll-Objekte zählen, Rohstoffquellen nicht), Respawn nur unter 50 %, Stufen vermüllt/unordentlich/aufgeräumt/sauber, Minimap unten rechts (ausblendbar), Tab „Karte“ im Fortschritts-Menü mit Scroll und Zoom per Gamepad, neue Objekte Palette/Betonbrocken/Sofa/Ruinenmauer, Materialien Holz und Stein | … die Minimap die Zonen in Stufenfarben zeigt, eine Zone nach dem Entfernen aller Müll-Objekte auf „sauber“ springt und dort nichts mehr respawnt, die große Karte per rechtem Stick scrollt und per Trigger zoomt, Zonennamen auf 7 Zoll lesbar sind. Tests für Reinigungsgrad und Respawn-Sperre grün. |
| **10** | Helfer-Roboter | `helpers.json`, Tech Helfer-Werkstatt, Kauf mit Kostenkurve und Chrom, Zonen-Cursor, Lager-Wahl, Helfer nutzen `WorkerBrain`, globale Upgrades, Namen, Farben, Sprüche, „Steckenbleiben“-Ereignis, Tab „Helfer“ im Fortschritts-Menü | … zwei Helfer gleichzeitig in verschiedenen Zonen abbauen und in Kisten liefern, der zweite Helfer teurer ist, ein Helfer ohne passende Werkzeug-Stufe ein Tier-2-Objekt sichtbar ignoriert und das kommentiert, das Spiel mit 6 Helfern 60 FPS hält. |
| **11** | MVP-Politur | Alle Sprüche, Humor-Pass, Platzhalter-Grafik vereinheitlicht, Button-Icons je Gerät, Schriftgrößen-Audit, Tastatur/Maus-Pfad, englische Texte gegengelesen, Balancing-Durchlauf 2–3 h mit Level 20 am Ende, MVP-Ende-Bildschirm, README | … ein kompletter Durchlauf vom Tutorial bis Techbaum-Ende und Level 20 auf dem Ally in 2 bis 3 Stunden ohne Absturz, ohne Maus und ohne unlesbaren Text möglich ist, und der Export-Build aus einem Befehl entsteht. |

## Phase 2 (geplant, nicht im MVP)

Reihenfolge laut Auftraggeber: (1) Zonen-Heilung mit Boden, Blumen, Wasser, Tieren, Wetter; (2) Logistik-Drohnen; (3) Dekoration und Fundstücke mit Museum und Journal; (4) Besucher, Scrap-Fischen, Fahrzeuge, Zen- und Fotomodus, Planeten-Rat-Aufgaben. Außerdem aus früheren Phasen: Offline-Progression (8 h, inkl. Helfer und Drohnen), Ereignisse, weitere Planeten, Prestige. Details in GDD Kap. 25.

## Abhängigkeiten

```
MS8 → MS9 → MS10 → MS11
 │      │
 │      └── Zonen aus der Hauptgebiet-Map (MS8) sind Voraussetzung für Reinigungsgrad
 └── WorkerBrain aus dem Autopilot wird von Helfern (MS10) und Drohnen (Phase 2) genutzt
```

## Scope-Hinweis

Die Cozy-Ergänzung fügt dem MVP einen Meilenstein hinzu (MS9) und verschiebt Helfer und Politur um eins. Der MVP hat damit 12 Meilensteine (0–11). Alles aus den Abschnitten B bis D ist nur dokumentiert.

## Arbeitsrhythmus pro Schritt

1. Ich nenne den Schritt und was er ändert (2–3 Sätze).
2. Code vollständig mit Dateipfaden, Tests für Sim-Teile zuerst.
3. Headless-Tests laufen grün, Screenshots über `tests/shot.sh` (sichert den echten Spielstand).
4. Testanleitung: „Starte das Spiel, tue X, du müsstest Y sehen.“
5. CHANGELOG.md und TODO.md aktualisiert, Commit, Merge, versionierter Build.
6. Stopp bis zum Go des Auftraggebers.
