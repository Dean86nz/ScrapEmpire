# TODO – Scrap Empire

## Jetzt

- [ ] MS2 testen (EXE `export/windows/ScrapEmpire_v0.2.0.exe`): Bauen in unter 2 s, Einlegen, Bolts, Abreißen, alles ohne Maus
- [ ] Nach Feedback: Branch `ms/2-bauen` nach `main` mergen, MS3 beginnen

## MS2 Bauen und Verkaufen (erledigt, wartet auf Test)

- [x] data/buildings.json (Terminal, Kiste), Kostenformel 1,35^n
- [x] Grid (Belegung) in der Sim, Befehle place/rotate/remove
- [x] Rastercursor (D-Pad / rechter Stick / Maus), Vorschau grün/rot, Drehen
- [x] Baumenü (Y) mit Fokusnavigation
- [x] Verkaufsterminal: A legt Stack ein, Bolts zählen hoch
- [x] Kiste: A legt ein / nimmt heraus
- [x] Abreißen erstattet Kosten
- [ ] Auf dem Ally getestet

## MS3 Maschinen (nächster Meilenstein)

- [ ] data/recipes.json, Rezeptsystem
- [ ] Schmelzofen (Schrott → Eisenbarren, Kupfer → Kupferbarren)
- [ ] Presse (Plastik → Plastikplatte; Zahnrad/Schaltkreis erst mit Tech)
- [ ] Ein-/Ausgangspuffer (10/10), Fortschrittsanzeige, Stau-Feedback „!“
- [ ] Manuelles Entnehmen aus dem Ausgang

## Bekannte Kleinigkeiten

- Pause-Menü hat noch keinen Sprachwechsel und kein Speichern (kommt in MS6)
- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision), Gebäude blockieren ihn
- Baumenü zeigt nicht leistbare Gebäude nur in roter Schrift, nicht ausgegraut (Fokuskette bleibt vollständig)

## Offene Fragen an den Auftraggeber

- Steam-Deck-Unterstützung: nur Gamepad-Layout prüfen oder auch Linux-Export vorsehen? (Vorschlag: erst nach MVP)

## Vorgemerkt (nach MVP, nicht bauen)

- Offline-Progression (Fabrik läuft bei geschlossenem Spiel weiter)
- Sammeldrohnen
- Ereignisse: Meteoriten, Stromausfall, Überlastung
- Weitere Planeten (prozedurale Welt)
- Bosse, leichter Kampf („Wracks wegschubsen“)
- Prestige-System
- Forschungslabore
- Splitter/Merger, unterirdische Bänder
- Mehrere Aufgabenlisten mit Bedingungen
- Echte Assets, Audio, eigene Schrift
- Icon in der EXE einbetten (rcedit konfigurieren)
