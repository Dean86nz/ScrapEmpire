# TODO – Scrap Empire

## Jetzt

- [ ] MS7 Speichern und Pause umsetzen
- [ ] Auftraggeber testet MS4–MS6 später auf dem Ally: Perf-Szenario F6 + F3 (FPS, Tick-Zeit) im 15-W-Modus; Lesbarkeit der Menü-Karten

## MS6 Fortschritts-Menü (erledigt, selbst getestet)

- [x] data/tech.json (17 Knoten), TechState mit Forschungstimer
- [x] data/skills.json (4 Äste, 13 Skills), SkillState, Modifiers
- [x] Modifiers wirken: Tempo, Drehen, Boost, Slots, Stapel, Magnet, Verkaufspreise, Werkzeug-Stufen, Abbau-Tempo, Reichweite
- [x] Menü (Select / T) mit Tabs Techbaum / Skilltree / Nächste Ziele, Fokus-Raster, LB/RB wechselt
- [x] Forschungsbalken im HUD, Freischaltungen wirken sofort
- [x] F4-Cheat angepasst (Werkzeug-Stufen nur noch über Skills)

## MS7 Speichern und Pause

- [ ] Versioniertes JSON-Save mit zwei rotierenden Dateien + Meta-Datei
- [ ] Serialisierung: Welt (Knoten, lose Items, Gebäude mit Puffern/Bändern, Respawns), Spieler, Progression, Skills, Tech, Bolts, RNG-Zustand
- [ ] Autosave 60 s, beim Pausieren und beim Beenden; Laden beim Start
- [ ] Migrationsgerüst mit Test-Fixtures
- [ ] Pause-Menü: Sprache DE/EN, Neues Spiel, Speichern und Beenden
- [ ] Alle sichtbaren Strings lokalisiert prüfen

## Bekannte Kleinigkeiten

- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision), Gebäude außer Bändern blockieren ihn
- Baumenü zeigt nicht leistbare Gebäude nur in roter Schrift, nicht ausgegraut
- Godots SVG-Import rendert keinen `<text>`, Platzhalter nur aus Formen bauen
- Band-Items am Bandende werden bei Stau mit Interpolation leicht „gestaucht“ dargestellt (kosmetisch)
- Lange Tech-/Skill-Beschreibungen werden am Kartenrand abgeschnitten (Texte kurz halten)
- Boost hat keine HUD-Anzeige (Rusty leuchtet nur kurz gelb)

## Offene Fragen an den Auftraggeber

- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Offline-Progression (Fabrik und Helfer laufen bei geschlossenem Spiel weiter, 8-h-Grenze)
- Skill-Respec gegen Bolts
- Tier 4/5-Materialien (Titan, Sternenstaub) und zugehörige Maschinen
- Sound und Musik
- Ereignisse: Meteoriten, Stromausfall, Überlastung
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf
- Prestige-System, Forschungslabore
- Splitter/Merger, unterirdische Bänder, Band-Animation (laufende Pfeile)
- Mehrere Aufgabenlisten mit Bedingungen
- Echte Assets, eigene Schrift
- Icon in der EXE einbetten (rcedit konfigurieren)
