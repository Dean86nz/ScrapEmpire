# TODO – Scrap Empire

## Jetzt

- [x] MS13 Zonen-Heilung (v1.2.0): Gras, Blumen, Büsche, Teiche, Tiere, Tageslicht, Regen, Kartenlegende
- [x] MS12 Gameplay-Klarheit (v1.1.0): Kapitel mit Toren, Nebel auf der Karte, Kapitel-Tab, Rezept-Hinweise, Titelbildschirm, Produkte als Baustoff, Zonen-Auffüllung alter Spielstände
- [ ] Phase 2 weiter: (2) Logistik-Drohnen (MS14), (3) Deko und Fundstücke (MS15), (4) Rest
- [ ] Auftraggeber prüft am Laptop: Titelbildschirm, Kapitel-Tab (Select), Tor nach 50 % Startlager, Maschinen-Hinweis am Schmelzofen, alter Spielstand hat wieder Objekte in allen Zonen
- [ ] NIE wieder user://saves ohne Backup anfassen: Screenshot-Läufe nur über tests/shot.sh, Datei-Tests mit use_directory
- [ ] Auftraggeber testet MS4–MS7 am Laptop / später am Ally: Speichern (F5 oder Pause), Beenden, Neustart, Sprache wechseln, Neues Spiel; Perf-Szenario F6 + F3

## MS13 Zonen-Heilung (erledigt, selbst getestet)

- [x] Natur-Dekor je Stufe, Tiere mit Folgen, Tageslicht, Regen, Legende, 6 Tests
- [ ] Regen soll laut GDD Natur schneller nachwachsen lassen – es gibt noch nichts, das nachwächst (Phase 2 Rest)
- [ ] Dekor unter später gebauten Gebäuden bleibt bestehen (liegt darunter, kosmetisch)
- [ ] Tiere kollidieren nicht mit Gebäuden (laufen darüber)

## MS12 Gameplay-Klarheit und Design (erledigt, selbst getestet)

- [x] Zonenzäune mit Toren, Freischaltung bei 50 %, Nebel auf Minimap und Karte, Bodenfarbe je Zustand
- [x] Kapitel-Tab, HUD-Kapitelzeile, Rezepte an Maschine und im Baumenü, Titelbildschirm, Bolts-Plakette
- [x] Produkte als Tech- und Baukosten, Save v4, fehlende Zonen nachfüllen, 7 neue Tests
- [ ] Rusty auf dem Titelbildschirm ist 5-fach skaliert und dadurch leicht unscharf (SVG-Importgröße erhöhen)
- [ ] Kapitel-Tipps sind Fließtext; später je Kapitel 2–3 Häkchen-Ziele (z. B. „Schmelzofen gebaut“)
- [ ] Zäune an Zonengrenzen liegen auf Kacheln, die in alten Spielständen bebaut sein könnten (Gebäude bleibt, Zaun darüber)

## MS7 Speichern und Pause (erledigt, selbst getestet)

- [x] Versioniertes JSON-Save mit zwei rotierenden Dateien + Meta-Datei
- [x] Serialisierung: Welt, Spieler, Progression, Skills, Tech, Bolts, RNG-Zustand
- [x] Autosave 60 s, beim Pausieren und beim Beenden; Laden beim Start
- [x] Migrationsgerüst mit Tests
- [x] Pause-Menü: Sprache DE/EN, Neues Spiel, Speichern und Beenden
- [ ] Englische Texte einmal komplett gegenlesen (Politur MS10)

## MS11 MVP-Politur (erledigt)

- [x] MVP-Ende-Bildschirm, Sprechblasen im Bild, Baumenü ausgegraut, Helfer-Leerlaufsprüche, README
- [ ] Balancing-Durchlauf 2–3 h durch einen Menschen (Zielkurve GDD 7.5 prüfen)
- [ ] Schriftgrößen-Audit auf dem Ally (alle Texte ≥ 22 px sind eingestellt, Lesbarkeit real prüfen)
- [ ] Item-Filter im Aufgaben-Editor (GDD 9) nachrüsten

## MS10 Helfer-Roboter (erledigt, selbst getestet)

- [x] helpers.json, Kauf mit Kostenkurve und Chrom, Zonen- und Lagerwahl per Cursor
- [x] Helfer-Planer auf Basis der Aufgabenlogik, Steckenbleiben-Ereignis, Namen, Farben, Sprüche
- [x] Globale Upgrades, Tab „Helfer“, Save v3
- [ ] Helfer weichen Gebäuden nicht aus (fahren darüber); Wegfindung ist Phase 2

## MS9 Zonen, Minimap und Karte (erledigt, selbst getestet)

- [x] Zonen-Rechtecke in Karten-JSON, Reinigungsgrad je Zone, Respawn-Sperre ab 50 %
- [x] Minimap unten rechts (ausblendbar), Tab „Karte“ im Fortschritts-Menü mit Scroll/Zoom
- [x] Objekte Palette, Betonbrocken, Sofa, Ruinenmauer; Materialien Holz, Stein, Quellen Treibholz/Geröll
- [x] Tests: Reinigungsgrad, Respawn-Sperre
- [ ] Zonen-Heilung (grüner Boden) ist Phase 2

## MS8 Tutorial und Autopilot (erledigt, selbst getestet)

- [x] Fünf Tutorial-Schritte mit Belohnungen (Sprechblasen, Konfetti)
- [x] Gebietsöffnung nach Osten, Hauptgebiet-Map (120×90) mit allen Tiers
- [x] WorkerBrain (gehe zu, sammle, hämmere, lege ab, nimm, warte)
- [x] Aufgaben-Editor (Y lang / L): Schritt hinzufügen, Ziel per Cursor, sortieren, löschen, starten
- [x] Aufgaben-HUD, Unterbrechen per Stick, Timeout und Warte-Sprüche, Autopilot v0.2 Tempo
- [x] Tech Autopilot als Voraussetzung; Save-Version 2 mit Migration
- [ ] Item-Filter je Schritt (GDD 9) noch nicht im Editor wählbar (Politur)

## Bekannte Kleinigkeiten

- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision), Gebäude außer Bändern blockieren ihn
- Baumenü zeigt nicht leistbare Gebäude nur in roter Schrift, nicht ausgegraut
- Godots SVG-Import rendert keinen `<text>`, Platzhalter nur aus Formen bauen
- Band-Items am Bandende werden bei Stau mit Interpolation leicht „gestaucht“ dargestellt (kosmetisch)
- Lange Tech-/Skill-Beschreibungen werden am Kartenrand abgeschnitten (Texte kurz halten)
- Boost hat keine HUD-Anzeige (Rusty leuchtet nur kurz gelb)
- Sprachwechsel lädt die Szene neu (kurzer Schwarzbild-Moment), Spielstand wird vorher gesichert

## Offene Fragen an den Auftraggeber

- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Offline-Progression (Fabrik und Helfer laufen bei geschlossenem Spiel weiter, 8-h-Grenze; `saved_at_unix` ist bereits im Spielstand)
- Skill-Respec gegen Bolts
- Tier 4/5-Materialien (Titan, Sternenstaub) und zugehörige Maschinen
- Sound und Musik
- Ereignisse: Meteoriten, Stromausfall, Überlastung
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf
- Prestige-System, Forschungslabore
- Splitter/Merger, unterirdische Bänder, Band-Animation (laufende Pfeile)
- Mehrere Aufgabenlisten mit Bedingungen
- Mehrere Spielstand-Slots
- Echte Assets, eigene Schrift
- Icon in der EXE einbetten (rcedit konfigurieren)
