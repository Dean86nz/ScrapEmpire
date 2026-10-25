# TODO – Scrap Empire

## Jetzt

- [ ] Go des Auftraggebers für die Einordnung der Cozy-Ergänzung (Roadmap v0.3: MS9 Zonen/Minimap/Karte neu) und für MS8 abwarten
- [ ] NIE wieder user://saves ohne Backup anfassen: Screenshot-Läufe nur über tests/shot.sh
- [ ] Auftraggeber testet MS4–MS7 am Laptop / später am Ally: Speichern (F5 oder Pause), Beenden, Neustart, Sprache wechseln, Neues Spiel; Perf-Szenario F6 + F3

## MS7 Speichern und Pause (erledigt, selbst getestet)

- [x] Versioniertes JSON-Save mit zwei rotierenden Dateien + Meta-Datei
- [x] Serialisierung: Welt, Spieler, Progression, Skills, Tech, Bolts, RNG-Zustand
- [x] Autosave 60 s, beim Pausieren und beim Beenden; Laden beim Start
- [x] Migrationsgerüst mit Tests
- [x] Pause-Menü: Sprache DE/EN, Neues Spiel, Speichern und Beenden
- [ ] Englische Texte einmal komplett gegenlesen (Politur MS10)

## MS9 Zonen, Minimap und Karte (neu, Grundlagen A der Cozy-Ergänzung)

- [ ] Zonen-Rechtecke in Karten-JSON, Reinigungsgrad je Zone, Respawn-Sperre ab 50 %
- [ ] Minimap unten rechts (ausblendbar), Tab „Karte“ im Fortschritts-Menü mit Scroll/Zoom
- [ ] Objekte Palette, Betonbrocken, Sofa, Ruinenmauer; Materialien Holz, Stein
- [ ] Tests: Reinigungsgrad, Respawn-Sperre

## MS8 Tutorial und Autopilot (nächster Meilenstein)

- [ ] Fünf Tutorial-Schritte mit Belohnungen (Sprechblasen, Konfetti)
- [ ] Gebietsöffnung nach Osten, Hauptgebiet-Map (120×90) mit allen Tiers
- [ ] WorkerBrain (gehe zu, sammle, hämmere, lege ab, nimm, warte)
- [ ] Aufgaben-Editor (Y lang): Schritt hinzufügen, Ziel per Cursor, sortieren, löschen, starten
- [ ] Aufgaben-HUD, Unterbrechen per Stick, Timeout und Warte-Sprüche, Autopilot v0.2 Tempo
- [ ] Tech Autopilot als Voraussetzung; Save-Format um Aufgaben und Tutorial-Schritt erweitern (Version 2)

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
