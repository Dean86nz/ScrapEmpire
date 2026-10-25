# TODO – Scrap Empire

## Jetzt

- [ ] MS1 testen (PC oder ROG Ally X, EXE in export/windows/), Feedback zu Saugen, Hämmern, Lesbarkeit der Sprechblase
- [ ] Nach Feedback: Branch `ms/1-sammeln` nach `main` mergen, MS2 beginnen

## MS1 Sammeln (erledigt, wartet auf Test)

- [x] data/items.json, DataRegistry lädt JSON
- [x] Tutorial-Map als JSON (40×30), MapLoader
- [x] ResourceNode (Haufen, Knäuel, Bröckchen, Wracks) in Sim + Darstellung
- [x] Inventory (6 Slots × 20) mit Tests
- [x] Schrottsauger (Kegel 90°, 2,5 Kacheln, 1 Item/0,25 s)
- [x] Hammer (1 Kachel, 1 Schlag/0,5 s), Wrack zerlegen, lose Items
- [x] Hotbar-HUD (72-px-Slots), Sprechblase, 11 Rusty-Sprüche (data/quips.json)
- [x] Regeneration der Haufen
- [ ] Auf dem Ally getestet

## MS2 Bauen und Verkaufen (nächster Meilenstein)

- [ ] data/buildings.json (Terminal, Kiste), Kostenformel 1,35^n
- [ ] Grid (Belegung) in der Sim, Befehle place/rotate/remove
- [ ] Rastercursor (D-Pad / rechter Stick), Vorschau grün/rot, Drehen
- [ ] Baumenü (Y) mit Fokusnavigation
- [ ] Verkaufsterminal: A legt Stack ein, Bolts zählen hoch
- [ ] Kiste: A legt ein / nimmt heraus
- [ ] Abreißen erstattet Kosten

## Bekannte Kleinigkeiten

- Pause-Menü hat noch keinen Sprachwechsel und kein Speichern (kommt in MS6)
- Sprechblase wird nicht an den Bildschirmrand geclampt (kann oben abgeschnitten werden)
- Rusty kann über Haufen und Wracks fahren (keine Kollision; Entscheidung folgt mit dem Bauen in MS2)

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
