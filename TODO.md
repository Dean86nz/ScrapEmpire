# TODO – Scrap Empire

## Jetzt

- [x] MVP fertig (v1.0.0). Warten auf Rückmeldung des Auftraggebers: Ally-Test, Balancing-Eindruck, Wünsche für Phase 2
- [ ] NIE wieder user://saves ohne Backup anfassen: Screenshot-Läufe nur über tests/shot.sh, Datei-Tests mit use_directory
- [ ] Auftraggeber testet MS4–MS7 am Laptop / später am Ally: Speichern (F5 oder Pause), Beenden, Neustart, Sprache wechseln, Neues Spiel; Perf-Szenario F6 + F3

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
