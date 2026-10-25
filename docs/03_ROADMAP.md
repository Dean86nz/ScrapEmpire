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
| **7** | Speichern und Pause | v0.7.0, F7-Fix v0.7.1, Testschutz v0.7.2 |
| **8** | Tutorial und Autopilot | v0.8.0 |
| **9** | Zonen, Minimap und Karte | v0.9.0 |
| **10** | Helfer-Roboter | v0.10.0 |
| **11** | MVP-Politur | v1.0.0 – **MVP fertig** |
| **12** | Gameplay-Klarheit und Design (Kapitel, Tore, Nebel, Rezepte, Titel) | v1.1.0 |

## Offen

Keine MVP-Meilensteine mehr offen. MS12 hat die Rückmeldung vom 2026-10-25 umgesetzt (Karte deckt auf, Kapitel-Logik, Rezepte sichtbar, einfacheres Menü). Es folgt Phase 2 ohne weiteres Go in der Reihenfolge unten; MS13 = Zonen-Heilung, MS14 = Logistik-Drohnen, MS15 = Deko und Fundstücke.

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
