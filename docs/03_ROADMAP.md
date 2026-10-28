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
| **26** | Spielgefühl 2: Jubel nach jedem Kauf (Menü zu, Rusty hüpft und dreht sich, Sterne, Jingle, 0,9 s) | v1.15.0 |
| **27** | Spielgefühl 3: Saugen mit Flugbogen, Plopp, Aufblähen, hüpfender Hotbar-Zahl; nächstes Ziel im HUD | v1.16.0 |
| **28** | Spielgefühl 4: Anbauteile an Rusty je Skill in drei Stufen, Lackierung | v1.17.0 |
| **29** | Spielgefühl 5: geputzter Boden wird Wiese, Schiff und saubere Zonen begrünen | v1.18.0 |
| **30** | Spielgefühl 6: Müll endlich, Haufen als Müll gezeichnet, Touristen und Meteoriten als Nachschub | v1.19.0 |
| **31** | Spielgefühl 7: Ziele-Tab mit Hauptaufgabe, Schiff-Tab 2×2, eine Hinweiszeile, runder und animiert | v1.20.0 |
| **32** | Spielgefühl 8: echte CC0-Sounds, Saug-Rauschen, Lautstärke-Regler, Musik vorbereitet | v1.21.0 |
| **33** | Phase 2, Punkt 0: Werkzeug bis T5, Wirtschafts- und Erreichbarkeits-Test, Bot-Langeweile, natürlicher Klang, Musik | v1.22.0 |
| **34** | Phase 2, Punkt 1: Sammelstellen, Drohnen-Transport, Bots per Karte zuweisen, Kurier | v1.23.0 |
| **35** | Phase 2, Punkt 2: Saugen wächst zum Wirbel, große Upgrade-Sprünge, 40 Bots, Bolts-Strom | v1.24.0 |
| **36** | Phase 2, Punkt 4: neue Karte, sechs Themen-Zonen mit Müllberg-Bossen, Endboss vor dem Abflug | v1.25.0 |
| **37** | Phase 2, Punkt 5: Finale mit Rundflug, Abflug, Abspann mit Bilanz, Weiterspielen | v1.26.0 |
| **38** | Phase 2, Punkt 6: Aufgaben-Editor/Autopilot, Deko-Gebäude und Museum entfernt | v1.27.0 |
| ~~39~~ | Balancing per Simulation: entfällt auf Wunsch, Feintuning nach Ally-Durchlauf | – |
| **40** | Abschluss Phase 2: durchspielbare EXE, Durchlauf-Testliste, offene Punkte | v2.0.0 |

## Phase 2.1 nach dem Test von v2.0.0 (Go 2026-10-28)

| MS | Inhalt | Version |
|---|---|---|
| **41** | Fehler: Endboss, Sauger nach Pause, Karte, Sammelstelle auf festem Bauplatz | v2.1.0 |
| **42** | Bots automatisch, Bot-Werkzeug bis T5, Boss-Verstärkung | v2.2.0 |
| **43** | Hammer spürbar stärker (Schläge nach Stufen-Unterschied) | v2.3.0 |
| **44** | Sprechblasen dezenter, Bot-Symbole | v2.4.0 |
| **45** | Sound im Comic-Stil | v2.5.0 |
| **46** | Musik je Zone und Finale | v2.6.0 |
| **47** | Absturz-Intro | v2.7.0 |

## Phase 2.2 nach dem Test von v2.7.0 (Go 2026-10-28)

| MS | Inhalt | Version |
|---|---|---|
| **48** | Fehler: Endboss ruft alle Bots, Sauger zentral, Bot-Wegfindung | v2.8.0 |
| **49** | Bots sammeln alles Lose | v2.9.0 |
| **50** | Bildschirmwackeln schwächer, Option an/aus | v2.10.0 |
| **51** | Sprechblasen klein (Vorgaben), Screenshot zur Abnahme | v2.11.0 |
| **52** | Musik: echtes Überblenden, Zonen-Jingle | v2.12.0 |
| **53** | Menüs mit Kenney UI Pack, erst Entwurf | v2.13.0 |

## Phase 2.3 nach dem Test von v2.12.0 (Go 2026-10-28)

| MS | Inhalt | Version |
|---|---|---|
| **54** | Fehler: Laden bringt Müll zurück, Listen scrollen, Menüs fertig, Repo aufgeräumt | v2.13.0 |
| 55 | Cheat-Menü nur in der Debug-EXE | v2.14.0 |
| 56 | Bots sichtbar arbeiten | v2.15.0 |
| 57 | Tiefe Upgrades (20–50 Stufen), Bot-Fusion, Drohnen billiger | v2.16.0 |
| 58 | Spiellänge 3–4 h (erst Übersicht) | v2.17.0 |
| 59 | Humor-Momente (alle 14 aus dem Plan) | v2.18.0 |
| 60 | Secrets (alle 10 aus dem Plan, Steam-Erfolgs-IDs) | v2.19.0 |

## Phase 2 nach dem vierten Praxistest (Go 2026-10-28)

Ziel: Steam-Release, 3 bis 4 Stunden mit klarem Ende, danach Content-Stopp. Beschlossen:
- Sammelstellen (1 je Zone, ab Schiffsstufe 2): Bolts entstehen erst, wenn das Material am Schiff ankommt; jede Sammelstelle bringt 1 Drohne mit; Drohnen sind der Transport zwischen Sammelstellen und Schiff.
- Kurier-Abholung aus Rustys Inventar ab Schiffsstufe 3: automatisch bei vollem Inventar, D-Pad runter ruft; Upgrade-Pfad 5 Stufen (Wartezeit 90 → 15 s, Ladung, bis 3 Kuriere).
- Bots über die Karte einer Zone oder Sammelstelle zuweisen, oder „Automatisch“.
- 6 Themen-Zonen mit Boss (Schrottplatz, Kabelsenke, Plastikbucht, Kühlschrank-Friedhof, Satellitenfeld, Monolith-Ebene); Boss: nächste Werkzeugstufe oder mindestens 3 Bots gemeinsam.
- Entfernen: Aufgaben-Editor/Autopilot, Deko bauen, Museum, alte Reste. Alte Spielstände werden gesichert, neues Spiel.
- Finale mit Szene, Abflug, Abspann mit Statistik, danach Weiterspielen.
- Balancing per Headless-Simulation bis zum Abflug, 3 bis 4 Stunden.

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
