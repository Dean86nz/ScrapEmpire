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
| **13** | Phase 2: Zonen-Heilung (Natur, Tiere, Tageslicht, Regen) | v1.2.0 |
| **14** | Phase 2: Logistik-Drohnen | v1.3.0 |
| **15** | Phase 2: Deko und Fundstücke (Werkbank, Museum, Journal) | v1.4.0 |
| **16** | Überarbeitung Block 1: Ally-Bugs (A in Menüs, Trigger-Schwelle, Sauger-Reset) | v1.5.0 |
| **17** | Überarbeitung Block 7: `world.gd` in acht Teilsysteme aufgeteilt | v1.6.0 |
| **18a** | Überarbeitung Block 2: Raumschiff-Basis mit Stufen, Planeten-Heilungsbalken, geführte Aufgabenkette, Außenposten | v1.7.0 |
| **19** | Kurswechsel Block 1: Weiterspielen absichern (Lade-Protokoll, Ladeschutz, F-Tasten nur Debug) | v1.8.0 |
| **20** | Kurswechsel Block 2: Kern-Ablauf sammeln, abliefern, aufrüsten; Fabrik entfernt | v1.9.0 |
| **21** | Kurswechsel Block 3: Sichtbar sauber (Schmutz je Kachel, Gras wächst nach, Sauberkeit aus Fläche) | v1.10.0 |
| **22** | Kurswechsel Block 4: Schiff als Herz (fünf Schiffsbilder, Putzwelle, Jubel, Stufenleiste, Abflug-Szene) | v1.11.0 |
| **23** | Kurswechsel Block 5: Erfolgserlebnisse (Meilensteine, kurze Aufgaben, Abliefer-Effekt, erste Sounds) | v1.12.0 |
| **24** | Kurswechsel Block 6: Menüs entschlacken (3 Tabs am Anfang, Icons, Kostenfarbe, Bot abbauen mit LT) | v1.13.0 |
| **25** | Spielgefühl 1: Skill (XP, Rusty) und Schiff (Bolts) getrennt | v1.14.0 |

## Runde „Spielgefühl“ nach dem dritten Praxistest (Go 2026-10-26)

MS25 Skill/Schiff trennen → MS26 Jubel nach Kauf → MS27 Saugen fühlt sich toll an, nächstes Ziel im HUD → MS28 Upgrades an Rusty sichtbar → MS29 saubere Wiese → MS30 Müll endlich, Nachschub über Ereignisse (Touristen, Meteoriten) → MS31 Menüs schöner (Ziele-Tab, eine Hinweiszeile, verspielter) → MS32 echte CC0-Sounds, Musik (Auswahl durch den Auftraggeber), Lautstärke-Regler. Nach jedem Meilenstein EXE, Ally-Testliste, Push von main und Branch.

## Kurswechsel nach dem zweiten Ally-Test (Go 2026-10-26)

Ersetzt den bisherigen Plan ab MS19. Weniger Fabrik, mehr Incremental: sammeln, am Schiff abliefern, aufrüsten, später Bots und Drohnen bauen. MS19 Absturz beim Weiterspielen → MS20 Kern-Ablauf (Förderband, Ofen, Presse, Rezepte fallen weg; alte Spielstände werden gesichert und verworfen; Blaupausen über Schiffsstufen) → MS21 Sichtbar sauber (Schmutz je Kachel, Gras wächst nach) → MS22 Schiff als Herz (Schiffsmenü, sichtbare Stufen, Abflug als Spielende) → MS23 Erfolgserlebnisse → MS24 Menüs → MS25 Animation und Sound → MS26 Balancing.

## Überarbeitung nach dem Ally-Test (Go 2026-10-25)

Keine neuen Phase-2-Systeme, sondern stabiler, klarer, langsamer, lustiger. Reihenfolge: MS16 Ally-Bugs → MS17 `world.gd` aufteilen → MS18a Raumschiff-Basis, Heilungsbalken, geführte Aufgaben → MS18b Intro, Jubel-Momente, Endtext → MS19 Menüs schrittweise freischalten → MS20 Balancing nach Zielkurve (Kapitel 1: 25 min, dann 35, 45, 55, 65, ab Kapitel 6 je 75; Zahlen vorher vorlegen; keine längere Forschungszeit, Müll je Objekt nur moderat) → MS21a Animationen, Effekte, Sound (Musikrichtung vorher abstimmen) → MS21b Zonenthemen, schmutzige Zonen, Haufen-Optik → MS21c Überraschungen, Müllberg-Boss, Rusty-Reaktionen → MS22 zweiter Balancing-Durchlauf. Beschlossen: Verkaufsautomaten bleiben als Außenposten (feste Kosten, einer je Zone); Schrotthaufen werden ab „aufgeräumt“ zur Sammelstelle, ab „sauber“ zum Recycling-Container mit Pflanzen. Nach jedem Meilenstein eine EXE und eine Ally-Testliste.

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
