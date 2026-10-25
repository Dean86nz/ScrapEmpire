# TODO – Scrap Empire

## Jetzt

- [ ] MS6 Fortschritts-Menü (Techbaum, Skilltree, Nächste Ziele) umsetzen
- [ ] Auftraggeber testet MS4/MS5 später auf dem Ally: Perf-Szenario F6 + F3 (FPS, Tick-Zeit) im 15-W-Modus

## MS5 Förderbänder (erledigt, selbst getestet)

- [x] Band-Gebäude (1×1, 1 Schrott), Richtung, automatische Kurven
- [x] Items auf Bändern (1/256-Kachel-Offsets, 4 je Kachel), topologische Tick-Reihenfolge
- [x] Einfügen/Auswerfen an Maschinenports (Eingang 10, Ausgang 10)
- [x] MultiMesh-Rendering, Perf-Szenario F6 (60 FPS, 2,7 ms Tick bei 1.884 Items am Laptop)
- [x] Band-Platzierung per Ziehen im Baumodus
- [x] Saugstation als Quelle für Haufen → Band
- [ ] Perf-Messung auf dem Ally (15 W)

## MS6 Fortschritts-Menü

- [ ] data/tech.json (17 Knoten, Kosten, Zeit, Voraussetzungen, Effekte), TechState mit Forschungstimer
- [ ] data/skills.json (4 Äste, 13 Skills), SkillState, Modifiers
- [ ] Modifiers wirken: Tempo, Drehen, Boost, Slots, Stapel, Magnet, Verkaufspreise, Werkzeug-Stufen, Abbau-Tempo, Reichweite
- [ ] Menü (Select / T) mit Tabs Techbaum / Skilltree / Nächste Ziele, Fokus-Raster, LB/RB wechselt
- [ ] Forschungsbalken im HUD, Freischaltungen wirken sofort (Rezepte, Gebäude, Werkzeuge)
- [ ] F4-Cheat entfernen, sobald Skilltree läuft

## Bekannte Kleinigkeiten

- Pause-Menü hat noch keinen Sprachwechsel und kein Speichern (kommt in MS7)
- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision), Gebäude außer Bändern blockieren ihn
- Baumenü zeigt nicht leistbare Gebäude nur in roter Schrift, nicht ausgegraut
- Godots SVG-Import rendert keinen `<text>`, Platzhalter nur aus Formen bauen
- Band-Items am Bandende werden bei Stau mit Interpolation leicht „gestaucht“ dargestellt (kosmetisch)

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
