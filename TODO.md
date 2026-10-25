# TODO – Scrap Empire

## Jetzt

- [ ] Go des Auftraggebers für die neue Reihenfolge (docs/03_ROADMAP.md): MS3 Maschinen, dann MS4 XP/Level/Tiers
- [ ] MS2 auf dem Ally testen (`export/windows/ScrapEmpire_v0.2.1.exe`), Maus-Platzierung am PC bestätigen

## MS3 Maschinen (nächster Meilenstein)

- [ ] data/recipes.json, Rezeptsystem
- [ ] Schmelzofen (Schrott → Eisenbarren, Kupfer → Kupferbarren)
- [ ] Presse (Plastik → Plastikplatte; Zahnrad/Schaltkreis erst mit Tech)
- [ ] Ein-/Ausgangspuffer (10/10), Fortschrittsanzeige, Stau-Feedback „!“
- [ ] Manuelles Entnehmen aus dem Ausgang

## MS4 XP, Level und Schrott-Stufen

- [ ] data/progression.json, Progression-Sim, XP-Leiste, Level-Up-Konfetti und Sprüche
- [ ] data/scrap_objects.json: Tier 1–5, ResourceNode datengetrieben, Chrom als Material
- [ ] Werkzeug-Stufe in Modifiers, „Zu hart!“-Feedback mit Funken, Dev-Cheat F4
- [ ] Respawn-Timer (SpawnManager), Tutorial-Map mit allen Objekten
- [ ] Platzhalter-SVGs: Toaster, Kühlschrank, Einkaufswagen, Raumschiff-Teil, Satellit, Roboter-Arm, Monolith, Chrom

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
