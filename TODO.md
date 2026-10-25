# TODO – Scrap Empire

## Jetzt

- [ ] MS4 testen (`export/windows/ScrapEmpire_v0.4.0.exe`): XP-Leiste, Level 2, „Zu hart!“ am Kühlschrank, F4-Cheat, Respawn des Toasters
- [ ] Nach Feedback: Branch `ms/4-xp-tiers` nach `main` mergen, MS5 Förderbänder beginnen

## MS4 XP, Level und Schrott-Stufen (erledigt, wartet auf Test)

- [x] data/progression.json, Progression-Sim, XP-Leiste, Level-Up-Konfetti und Sprüche
- [x] data/scrap_objects.json: Tier 1–5, ResourceNode datengetrieben, Chrom als Material
- [x] Werkzeug-Stufe in PlayerState (Modifiers kommen in MS6), „Zu hart!“-Feedback mit Funken, Dev-Cheat F4
- [x] Respawn-Timer in der Welt, Tutorial-Map mit allen Objekten
- [x] Platzhalter-SVGs: Toaster, Kühlschrank, Einkaufswagen, Raumschiff-Teil, Satellit, Roboter-Arm, Monolith, Chrom, Titan, Sternenstaub
- [ ] Auf dem Ally getestet

## MS5 Förderbänder (nächster Meilenstein)

- [ ] Band-Gebäude (1×1, 1 Schrott), Richtung, automatische Kurven
- [ ] Items auf Bändern (1/256-Kachel-Offsets, 4 je Kachel), topologische Tick-Reihenfolge
- [ ] Einfügen/Auswerfen an Maschinenports (Eingang 10, Ausgang 10)
- [ ] MultiMesh-Rendering, Perf-Szene 2.000 Items
- [ ] Band-Platzierung per Ziehen im Baumodus

## Bekannte Kleinigkeiten

- Pause-Menü hat noch keinen Sprachwechsel und kein Speichern (kommt in MS7)
- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision), Gebäude blockieren ihn
- Baumenü zeigt nicht leistbare Gebäude nur in roter Schrift, nicht ausgegraut (Fokuskette bleibt vollständig)
- Godots SVG-Import rendert keinen `<text>`, Platzhalter nur aus Formen bauen

## Offene Fragen an den Auftraggeber

- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Offline-Progression (Fabrik und Helfer laufen bei geschlossenem Spiel weiter, 8-h-Grenze)
- Skill-Respec gegen Bolts
- Tier 4/5-Materialien (Titan, Sternenstaub) und zugehörige Maschinen
- Sound und Musik (Level-Up-Sound, Werkzeuge, Helfer)
- Ereignisse: Meteoriten, Stromausfall, Überlastung (liefern Schrott-Objekte nach)
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf („Wracks wegschubsen“)
- Prestige-System
- Forschungslabore
- Splitter/Merger, unterirdische Bänder
- Mehrere Aufgabenlisten mit Bedingungen
- Echte Assets, eigene Schrift
- Icon in der EXE einbetten (rcedit konfigurieren)
