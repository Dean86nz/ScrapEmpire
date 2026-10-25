# Scrap Empire – Game Design Document (MVP)

Stand: 2026-10-25 · Version 0.1 · Autor: Lead Dev/Design

## 1. Vision in einem Satz

Ein buntes, humorvolles 2D-Top-down-Automatisierungsspiel: Ein kleiner Schrottsammel-Roboter macht zuerst alles selbst und automatisiert Schritt für Schritt jede Tätigkeit, bis hin zu sich selbst. Gamepad-first für den ROG Ally.

## 2. Design-Säulen

1. **Vom Handgriff zur Fabrik.** Jede Tätigkeit, die der Spieler zuerst manuell macht, lässt sich später automatisieren. Nichts wird automatisiert, bevor der Spieler es nicht mindestens einmal selbst getan hat.
2. **Alle drei Minuten ein Lächeln.** Freischaltung, Witz oder sichtbares Upgrade im Takt von 2 bis 4 Minuten.
3. **Lesbar auf 7 Zoll, bedienbar mit zwei Sticks.** Keine Tabellen, Status wird visuell gezeigt (Stau = Items hüpfen, Maschine leer = Fragezeichen über Maschine).
4. **Freundlich, nie fies.** Kein Tod, kein Verlust von Fortschritt, kein Zeitdruck. Fehler kosten höchstens ein paar Bolts.

## 3. Core Loop

| Ebene | Dauer | Schleife |
|---|---|---|
| Moment | 10–30 s | Schrott aufsaugen → Wrack zerhämmern → Inventar füllt sich |
| Runde | 2–5 min | Rohstoffe zu Maschine tragen → Produkt verkaufen → Bolts → neue Maschine/Tech |
| Sitzung | 20–40 min | Produktionskette um ein Glied erweitern → Engpass sichtbar → Engpass automatisieren |
| Meta (MVP) | 2–3 h | Vollständiger Techbaum, Roboter läuft seine erste Sammelroutine selbstständig |

## 4. Spielerroboter „Rusty“

| Eigenschaft | Wert | Hinweis |
|---|---|---|
| Laufgeschwindigkeit | 4 Kacheln/s (Basis) | Tech „Ölwechsel“: 5,5 Kacheln/s |
| Kachelgröße | 64 px | 1920 px = 30 Kacheln Sichtbreite |
| Inventar | 6 Slots × 20 Stück | Tech „Rucksack“: 10 Slots |
| Schrottsauger | Kegel 90°, Reichweite 2,5 Kacheln, 1 Item/0,25 s | Rechter Stick zielt, RT saugt |
| Hammer | Nahkampf 1 Kachel, 1 Schlag/0,5 s | Rechter Stick zielt, LT schlägt |

**Gamepad:** Linker Stick Bewegung · Rechter Stick Zielen · RT Saugen · LT Hammer · A Interagieren/Bestätigen · B Zurück/Abbrechen · Y Baumenü (lang: Aufgaben-Menü) · X reserviert (Werkzeugwechsel entfällt, da RT und LT beide Werkzeuge direkt auslösen) · LB/RB Hotbar · D-Pad Cursor im Baumodus · Start Pause · Select Techbaum.

**Tastatur/Maus:** WASD, Maus zielt, LMB Saugen, RMB Hammer, E Interagieren, Tab Baumenü, T Techbaum, Esc Pause.

## 5. Rohstoffe, Produkte, Währung

### 5.1 Rohstoffe (Welt)

| ID | Name DE | Name EN | Quelle | Verkaufswert (Bolts) |
|---|---|---|---|---|
| `scrap` | Schrott | Scrap | Schrotthaufen (saugen), Wracks (hämmern) | 1 |
| `copper` | Kupfer | Copper | Kabelknäuel (saugen), Wracks (hämmern) | 3 |
| `plastic` | Plastik | Plastic | Plastikbröckchen (saugen), Wracks (hämmern) | 2 |

Schrotthaufen regenerieren: alle 30 s wächst ein Haufen um 1 Einheit bis max. 10. Wracks sind endlich (20–40 Items), spawnen aber alle 3 Minuten neu an zufälligen Positionen am Gebietsrand (Humor-Event: „Ein Wrack ist vom Himmel gefallen. Wieder.“).

### 5.2 Zwischenprodukte (Maschinen)

| ID | Name DE | Name EN | Rezept | Maschine | Dauer | Verkaufswert |
|---|---|---|---|---|---|---|
| `iron_bar` | Eisenbarren | Iron Bar | 3 Schrott | Schmelzofen | 4 s | 6 |
| `copper_bar` | Kupferbarren | Copper Bar | 2 Kupfer | Schmelzofen | 4 s | 10 |
| `plastic_sheet` | Plastikplatte | Plastic Sheet | 2 Plastik | Presse | 3 s | 7 |
| `gear` | Zahnrad | Gear | 2 Eisenbarren | Presse | 5 s | 20 |
| `circuit` | Schaltkreis „Denkbrett“ | Circuit "Thinkboard" | 1 Kupferbarren + 1 Plastikplatte | Presse | 6 s | 30 |

Wertschöpfungsregel: Produktwert = Summe Inputwerte × 1,5 bis 1,8 (gerundet). Verarbeitung lohnt sich immer, aber nie so stark, dass Rohstoffverkauf sinnlos wird.

### 5.3 Währung

**Bolts** entstehen ausschließlich im Verkaufsterminal. Keine andere Quelle, keine Senke außer Bauen und Forschen. Das hält die Ökonomie berechenbar.

## 6. Maschinen (MVP)

| Maschine | Größe | Baukosten | Takt | Ein-/Ausgänge | Besonderheit |
|---|---|---|---|---|---|
| Schmelzofen | 2×2 | 40 Schrott, 10 Kupfer | siehe Rezept | 1 Eingang (links), 1 Ausgang (rechts) | Rezept wird automatisch nach Input gewählt |
| Presse | 2×2 | 60 Schrott, 20 Plastik | siehe Rezept | 2 Eingänge (links, oben), 1 Ausgang (rechts) | Zahnrad/Schaltkreis nur nach Tech |
| Verkaufsterminal | 2×2 | 30 Schrott | 1 Item/0,5 s | 1 Eingang (links), kein Ausgang | Zeigt Bolts/min als schwebende Zahl |
| Förderband | 1×1 | 1 Schrott pro Stück | 2 Kacheln/s | gerade, Kurve L/R | Kapazität 4 Items pro Kachel |
| Kiste | 1×1 | 10 Schrott | – | von allen Seiten | 12 Slots × 20, Puffer für Routinen |

Maschinen haben Puffer: Eingang max. 10 Items pro Typ, Ausgang max. 10 Items. Voller Ausgang stoppt die Maschine (visuell: Maschine „schnauft“, Items hüpfen am Band). Ausnahme Verkaufsterminal: beim manuellen Einlegen nimmt es bis zu 40 Items (ein ganzer Stack passt hinein), Bänder (MS4) halten sich an 10.

Manuelles Befüllen: A neben dem Gebäude legt den ausgewählten Hotbar-Stack (LB/RB wählt) ganz ein; ist der gewählte Slot leer, nimmt A einen Stack aus dem Gebäude. Alles weitere lösen Förderbänder.

**Baumodus** (Y öffnet Baumenü, A wählt): D-Pad, rechter Stick oder Pfeiltasten bewegen den Cursor, A platziert, X dreht, B bricht ab, Y zurück ins Menü. Reichweite 6 Kacheln um Rusty. „Abreißen“ im Baumenü erstattet die gezahlten Kosten und den Inhalt.

## 7. Ökonomie-Formeln

### 7.1 Durchsatz

```
items_pro_min(maschine)    = 60 / rezept_dauer_s
bolts_pro_min(kette)       = min über alle Glieder(items_pro_min × anteil) × verkaufswert
band_kapazität_pro_min     = 2 Kacheln/s × 4 Items/Kachel × 60 = 480 Items/min (nie Engpass im MVP)
manueller_durchsatz        = 1 Item / 0,25 s = 240 Rohstoffe/min brutto, netto ca. 60/min inkl. Laufwege
```

### 7.2 Kosten-Progression

Alle Kosten (Maschinen Nr. n desselben Typs) folgen einer Kurve:

```
kosten(n) = basis × 1,35^(n-1)        gerundet auf 5
```

Beispiel Schmelzofen: 40, 55, 75, 100, 135 Schrott. Flach genug, dass die zweite und dritte Maschine schnell kommen, steil genug, dass der Spieler ab Nr. 4 Förderbänder statt Laufwege will. Förderbänder und Kisten sind von der Kurve ausgenommen (Festpreis), damit Automatisierung nie bestraft wird.

### 7.3 Offline-Verhalten

Im MVP passiert nichts, solange das Spiel geschlossen ist. Beim Laden wird die Fabrik exakt im gespeicherten Zustand fortgesetzt. Offline-Progression ist für später vorgemerkt (Entscheidung Auftraggeber, 2026-10-25).

### 7.4 Forschungszeit

Forschung kostet Bolts (sofort abgezogen) und dauert danach eine feste Zeit, die nur bei laufendem Spiel verstreicht. Es läuft immer nur eine Forschung gleichzeitig, ein Fortschrittsbalken ist im HUD sichtbar. Richtwert:

```
forschungszeit_s = clamp(kosten_bolts / 10, 10, 180)
```

Beispiel: Schmelzofen (50 Bolts) 10 s, Förderband (200 Bolts) 20 s, Autopilot (2.000 Bolts) 180 s. Die Zeit ist kurz genug, dass sie nie zum Leerlauf wird, und lang genug, dass man inzwischen sammelt oder baut.

### 7.5 Zielkurve MVP (Richtwerte für Balancing-Tests)

| Phase | Spielzeit | Bolts/min | Spieler tut | Schaltet frei |
|---|---|---|---|---|
| A „Handarbeit“ | 0–8 min | 0–20 | Saugen, Hämmern, zum Terminal laufen | Terminal, Schmelzofen |
| B „Erste Kette“ | 8–25 min | 20–80 | Ofen manuell füttern, Barren verkaufen | Presse, Förderband, Kiste |
| C „Bänder“ | 25–60 min | 80–300 | Haufen → Band → Ofen → Terminal | Kurven, Zahnrad |
| D „Fabrik“ | 60–120 min | 300–900 | Zwei Ketten, Schaltkreise | Autopilot v0.1, Rucksack |
| E „Loslassen“ | 120–180 min | 900+ | Rusty läuft Routine, Spieler optimiert | Letzte Tech, MVP-Ende-Bildschirm |

Prüfregel: Wenn Phase C vor Minute 20 oder nach Minute 40 erreicht wird, Kosten anpassen.

## 8. Techbaum (15 Knoten)

Forschung wird im Techbaum-Menü (Select) gestartet: Bolts werden sofort abgezogen, danach läuft die Forschungszeit (Formel 7.4). Nur eine Forschung gleichzeitig.

| # | ID | Name DE | Kosten (Bolts) | Zeit | Voraussetzung | Effekt |
|---|---|---|---|---|---|---|
| 1 | `terminal` | Verkaufsterminal | 0 | 0 s | – | Terminal baubar (Tutorial schaltet frei) |
| 2 | `furnace` | Schmelzofen | 50 | 10 s | 1 | Schmelzofen baubar, Rezepte Eisen-/Kupferbarren |
| 3 | `chest` | Kiste | 80 | 10 s | 2 | Kiste baubar |
| 4 | `press` | Presse | 150 | 15 s | 2 | Presse baubar, Rezept Plastikplatte |
| 5 | `conveyor` | Förderband | 200 | 20 s | 2 | Gerade Bänder, Einfügen/Auswerfen an Maschinen |
| 6 | `conveyor_turn` | Kurvenband | 300 | 30 s | 5 | Bandkurven |
| 7 | `suction_plus` | Turbo-Sauger | 350 | 35 s | 1 | Saugreichweite 3,5, 1 Item/0,15 s |
| 8 | `hammer_plus` | Presslufthammer | 400 | 40 s | 1 | Hammer 2 Items/Schlag |
| 9 | `gear` | Zahnrad-Rezept | 500 | 50 s | 4 | Presse kann Zahnräder |
| 10 | `oil_change` | Ölwechsel | 600 | 60 s | 7 | Laufgeschwindigkeit 5,5 |
| 11 | `backpack` | Rucksack | 800 | 80 s | 3 | 10 Inventar-Slots |
| 12 | `circuit` | Denkbrett-Rezept | 1.200 | 120 s | 9 | Presse kann Schaltkreise |
| 13 | `terminal_plus` | Turbo-Terminal | 1.500 | 150 s | 5 | Terminal 1 Item/0,2 s |
| 14 | `autopilot` | Autopilot v0.1 | 2.000 | 180 s | 11, 12 | Rusty nimmt Aufgabenlisten an (Kap. 9) |
| 15 | `autopilot_speed` | Autopilot v0.2 | 3.500 | 180 s | 14 | Rusty erledigt Aufgaben mit 1,5× Tempo |

Gesamtkosten: 11.630 Bolts, Gesamtforschungszeit ca. 17 min. Bei durchschnittlich 100 Bolts/min über die mittlere Spielzeit ca. 2 h. Passt zur Zielkurve.

## 9. Selbst-Automatisierung: Aufgabenliste („Autopilot v0.1“)

Der Spieler stellt Rusty eine Aufgabenliste zusammen, die Rusty dann endlos wiederholt:

1. **Aufgaben-Menü** (Y lang drücken, nach Tech 14): eine Liste mit max. 12 Schritten, per Gamepad bedienbar. „Schritt hinzufügen“ öffnet die Auswahl des Schritttyps: **Gehe zu**, **Sammle hier** (saugen bis Inventar voll oder nichts mehr da), **Hämmere hier**, **Lege ab in** (Kiste/Maschine/Terminal), **Nimm aus** (Kiste/Maschine).
2. Danach wählt der Spieler das Ziel mit dem Rastercursor auf der Karte (A bestätigt, B bricht ab). Bei „Lege ab“/„Nimm aus“ optional ein Item-Filter.
3. Schritte lassen sich verschieben (LB/RB) und löschen (X). „Starten“ setzt Rusty in den Autopilot-Modus, das HUD zeigt die Liste als Icon-Kette mit markiertem aktuellen Schritt.
4. Jede Eingabe am linken Stick unterbricht sofort; der Spieler hat wieder Kontrolle. Y lang: Autopilot fortsetzen (beim aktuellen Schritt).
5. Scheitert ein Schritt (Haufen leer, Kiste voll), wartet Rusty 5 s, sagt etwas Trockenes („Kiste voll. Ich warte. Ich bin gut im Warten.“) und versucht es erneut.

Eine Aufgabenliste pro Spielstand im MVP. Mehrere Listen und Bedingungen („wenn Kiste leer“) sind vorgemerkt.

## 10. Tutorial-Gebiet

Ein Bereich von 40×30 Kacheln, umrandet von unpassierbaren Schrottbergen. Inhalt: 6 Schrotthaufen, 2 Kabelknäuel, 2 Plastikbröckchen, 3 Wracks, ein halb kaputtes Verkaufsterminal (Tutorial-Freischaltung durch 10 Schrott „Reparatur“). Fünf Tutorial-Schritte als Sprechblasen von Rusty, jeder Schritt endet mit einer Belohnung:

1. Bewegen (Belohnung: Witz)
2. Saugen: 10 Schrott (Belohnung: Terminal repariert, Tech 1)
3. Verkaufen: erste Bolts (Belohnung: Konfetti, 20 Bolts Bonus)
4. Hämmern: ein Wrack (Belohnung: Kupfer + Plastik entdeckt)
5. Techbaum öffnen, Schmelzofen kaufen (Belohnung: Tutorial Ende, Gebiet öffnet sich nach Osten)

Nach dem Tutorial öffnet sich das Hauptgebiet (120×90 Kacheln), handgesetzt, nicht prozedural.

## 11. Humor-Richtlinie

- **Item-Namen** dürfen absurd sein, müssen aber auf einen Blick erkennbar bleiben: „Schaltkreis ‚Denkbrett‘“, nicht nur „Denkbrett“.
- **Rusty-Kommentare**: trocken, kurz (max. 60 Zeichen bei 24 px, eine Zeile), nie sarkastisch gegen den Spieler. Pool von 40 Sprüchen, ausgelöst durch Ereignisse (Inventar voll, erste Maschine, Stau, Offline-Rückkehr, Idle 60 s).
- **Ereignisse** im MVP nur kosmetisch (Wrack fällt vom Himmel). Meteoriten, Stromausfall usw. sind Phase 2.
- Verboten: Horror, Gewalt, Dunkelheit, Zeitdruck-Panik.

## 12. UI und Lesbarkeit (7 Zoll, 1080p)

| Element | Vorgabe |
|---|---|
| Schrift | Rundliche Sans (Platzhalter: Godot-Standardschrift skaliert, später Nunito/Fredoka), Fließtext 24 px, Zahlen 28 px, Überschriften 36 px, Minimum 22 px |
| HUD | Oben links Bolts (groß), oben rechts Inventar-Hotbar (6–10 Slots à 72 px), unten Mitte Kontexthinweise mit Button-Icons |
| Baumodus | Rastercursor 64 px mit dickem Rahmen, grün = baubar, rot = blockiert, Rotationsvorschau |
| Menüs | Alle Menüs als Fokus-Ketten (Godot `focus_neighbor`), erstes Element hat beim Öffnen Fokus, B schließt immer |
| Stau-Feedback | Items hüpfen, Maschine zeigt Icon „!“ in Sprechblase |
| Farben | Gesättigte Grundfarben, dicke dunkle Outlines (4 px), weicher Schatten unter allem |

## 13. Nicht im MVP (vorgemerkt)

Offline-Progression, Skill-Respec, Tier-4/5-Materialien, Sound, Ereignisse (Meteoriten, Stromausfall, Überlastung), weitere Planeten, Bosse, Prestige, Forschungslabore, Splitter/Merger, unterirdische Bänder, Strom-System, Multiplayer, mehrere Aufgabenlisten mit Bedingungen.

## 14. Getroffene Standardentscheidungen (Widerspruch willkommen)

Bestätigt bzw. entschieden durch den Auftraggeber am 2026-10-25:

| Thema | Entscheidung |
|---|---|
| Offline | Nichts passiert bei geschlossenem Spiel. Offline-Progression ist aus dem MVP gestrichen und für später vorgemerkt. |
| Forschungszeit | Forschung kostet Bolts und dauert Zeit (Formel 7.4), wie in üblichen Spielen. |
| Aufgaben | Spieler stellt Rusty eine Aufgabenliste per Menü zusammen (Kap. 9), kein Aufzeichnen. |
| Welt | handgesetzt (Standard, nicht widersprochen) |
| Kampf | nicht im MVP (Standard, nicht widersprochen) |
| Selbst-Automatisierung | im MVP als letztes Feature (MS7) |


---

# Teil B – Ergänzung Progression (2026-10-25, Auftraggeber)

Diese Kapitel ergänzen das MVP um Erfahrung und Level, Skilltree, Schrott-Stufen, Helfer-Roboter und ein Fortschritts-Menü. Alle Zahlen liegen in `data/progression.json`, `data/skills.json`, `data/scrap_objects.json` und `data/helpers.json`, nicht im Code.

## 15. Erfahrung und Level

**XP-Quellen** (Werte in `data/progression.json`):

| Aktion | XP |
|---|---|
| Item abbauen (saugen oder hämmern) | 1 × Tier des Objekts |
| Verkauf | 1 XP je 5 Bolts (aufgerundet pro Verkaufsvorgang) |
| Gebäude bauen | 5 |
| Tech erforscht | Kosten in Bolts / 10 |
| Skill gekauft | 0 (Skillpunkte sind die Belohnung, keine XP-Schleife) |

**Level-Kurve:** `xp_für_level(n) = 100 × 1,15^(n-1)`, gerundet auf 5. Level-Obergrenze im MVP: 20.

| Level | XP für dieses Level | kumuliert |
|---|---|---|
| 2 | 100 | 100 |
| 3 | 115 | 215 |
| 4 | 130 | 345 |
| 5 | 150 | 495 |
| 6 | 175 | 670 |
| 8 | 230 | 1.105 |
| 10 | 305 | 1.705 |
| 12 | 405 | 2.515 |
| 15 | 615 | 4.165 |
| 20 | 1.230 | 8.985 |

Richtwert: bei durchschnittlich 60 XP/min (Phase C) dauert Level 10 etwa 30 Minuten, Level 20 etwa 2,5 Stunden. Damit fällt Level 20 ungefähr mit dem Ende des MVP-Techbaums zusammen.

**Levelaufstieg:** +1 Skillpunkt, Konfetti-Partikel um Rusty, Spruch aus dem Pool `level_up`, kurzer HUD-Puls der XP-Leiste. Sound kommt mit dem Audio-Pass nach dem MVP.

**XP-Leiste:** dauerhaft im HUD unten links, 480 × 28 px, Level-Zahl 32 px links daneben, Fortschritt als gefüllter Balken mit dicker Outline.

## 16. Skilltree

Vier Äste, jeder Skill 3 bis 5 Stufen, Boni prozentual oder additiv. Voraussetzung innerhalb des Astes: Skill 2 braucht Skill 1 auf Stufe 2, Skill 3 braucht Skill 2 auf Stufe 2. Keine Sackgassen: mit 20 Skillpunkten sind alle Äste anspielbar, mit späteren Levels alles kaufbar (Gesamtstufen: 48; Level-Obergrenze wird nach dem MVP angehoben). Respec gegen Bolts ist vorgemerkt.

| Ast | Skill | Stufen | Bonus pro Stufe |
|---|---|---|---|
| Bewegung | Flinke Räder | 5 | +8 % Laufgeschwindigkeit |
| Bewegung | Turbo-Boost (L3 / Shift) | 3 | Boost +40 % für 2 s; Abklingzeit 8 / 6 / 4 s |
| Bewegung | Wendigkeit | 3 | +25 % Drehgeschwindigkeit |
| Inventar | Taschen | 4 | +1 Slot |
| Inventar | Stapler | 4 | +5 Stapelgröße |
| Inventar | Magnet | 3 | lose Items im Radius 1 / 2 / 3 Kacheln werden automatisch eingesammelt |
| Handel | Feilschen | 5 | +5 % Bolts je Verkauf |
| Handel | Kenner | 3 | +10 % auf Kupfer, Plastik, Chrom und daraus gefertigte Produkte |
| Handel | Großhändler | 3 | +5 % wenn der Terminal-Puffer beim Verkauf mindestens 20 Items hält |
| Werkzeuge | Schlagkraft | 3 | Hammer-Stufe +1 (Tier 2, 3, 4) |
| Werkzeuge | Saugkraft | 3 | Sauger-Stufe +1 (Tier 2, 3, 4) |
| Werkzeuge | Tempo | 5 | +15 % Abbau-Geschwindigkeit (Sauger-Takt und Hammer-Takt) |
| Werkzeuge | Reichweite | 4 | +0,5 Kacheln Saug- und Hammerreichweite |

Skillpunkte-Kosten: 1 Punkt pro Stufe. UI: vier farbige Spalten (Bewegung blau, Inventar grün, Handel gelb, Werkzeuge orange), D-Pad wechselt Spalte/Zeile, A kauft, gesperrte Skills zeigen die fehlende Voraussetzung.

## 17. Schrott-Objekte mit Stufen (Tier 1–5)

Jedes Objekt hat ein Werkzeug (Sauger oder Hammer), eine Härte-Stufe und eine Ausbeute. Ein Werkzeug baut nur Objekte bis zu seiner eigenen Stufe ab. Zu niedrige Stufe: Funken-Partikel, kurzes Wackeln, Spruch „Zu hart!“ (Hammer) bzw. „Zu schwer!“ (Sauger), kein stiller Fehlschlag. Definitionen in `data/scrap_objects.json`.

| Tier | Objekt | Werkzeug | Ausbeute | Respawn | Im MVP |
|---|---|---|---|---|---|
| 1 | Schrotthaufen | Sauger | Schrott, wächst nach | 30 s je Einheit | ja |
| 1 | Kabelknäuel | Sauger | Kupfer, wächst nach | 30 s je Einheit | ja |
| 1 | Plastikbröckchen | Sauger | Plastik, wächst nach | 30 s je Einheit | ja |
| 1 | Rostiger Toaster | Hammer | 8 Schrott, 2 Kupfer | 3 min | ja |
| 2 | Verbeulter Kühlschrank | Hammer | 15 Schrott, 6 Kupfer, 6 Plastik | 5 min | ja |
| 2 | Kaputter Einkaufswagen | Sauger | 12 Schrott, 8 Kupfer | 5 min | ja |
| 3 | Gestrandetes Raumschiff-Teil | Hammer | 10 Schrott, 6 Kupfer, 4 Chrom | 8 min | ja |
| 3 | Alter Satellit | Sauger | 6 Kupfer, 6 Plastik, 3 Chrom | 8 min | ja |
| 4 | Vergrabener Roboter-Arm | Hammer | Titan (neu) | 12 min | sichtbar, nicht abbaubar |
| 5 | Monolith „Warum steht der hier?“ | Hammer | Sternenstaub (neu) | nie | sichtbar, nicht abbaubar |

**Neues Material Chrom** (`chrome`, Verkaufswert 8): nötig für Tech „Autopilot v0.1“ (10 Chrom zusätzlich zu Bolts), Tech „Helfer-Werkstatt“ (20 Chrom) und den Kauf von Helfer-Robotern. Tier 4 und 5 stehen als Ziel sichtbar in der Welt, ihre Materialien kommen nach dem MVP.

**Werkzeug-Stufen:** Start Tier 1. Tier 2 und 3 über den Werkzeug-Ast (Schlagkraft, Saugkraft). Tech „Presslufthammer“ und „Turbo-Sauger“ erhöhen Ausbeute bzw. Takt, nicht die Stufe. Tier 4 ist über Skill Stufe 3 erreichbar, aber erst nach dem MVP relevant.

**Respawn:** Objekte respawnen an ihrem Spawn-Punkt nach der angegebenen Zeit; Ereignisse (Phase 2) liefern zusätzlich nach.

## 18. Helfer-Roboter

- Freischaltung: Tech „Helfer-Werkstatt“ (nach Autopilot v0.1). Kauf im Fortschritts-Menü, Tab „Helfer“.
- Kosten: `bolts(n) = 400 × 1,5^(n-1)` plus 5 Chrom pro Helfer; maximal 6 Helfer im MVP.
- Einsatz: Spieler setzt per Cursor einen Zielbereich (Kreis, Radius 6 Kacheln) und ein Lager (Kiste, später Bandanfang). Der Helfer baut im Bereich alle Objekte bis zu seiner Werkzeug-Stufe ab und bringt volle Ladung zum Lager.
- Upgrades **global** (einfacher balancierbar, eine Tabelle): Helfer-Tempo (3 Stufen, +20 %), Helfer-Tragkraft (3 Stufen, +10 Items), Helfer-Werkzeug (Tier 1 → 2 → 3). Kosten in `data/helpers.json`.
- Persönlichkeit: Name aus Liste (Bolte, Knirps, Dübel, Fräulein Flex, Schraubi, Rostnase), eigene Farbe, 12 Sprüche. Alle 4 bis 6 Minuten bleibt ein zufälliger Helfer 5 s stehen und sagt etwas („Ich habe vergessen, was ich tun wollte.“), dann geht es weiter.
- Offline: im MVP passiert nichts offline (Entscheidung Auftraggeber). Sobald Offline-Progression kommt, zählen Helfer mit derselben 8-Stunden-Grenze.
- Technik: Helfer und Autopilot teilen sich die Arbeiter-Logik (`WorkerBrain`): gehe zu, baue ab, liefere ab, warte bei Problemen.

## 19. Fortschritts-Menü

Ein Menü (Select / T) mit drei Tabs, LB/RB wechselt: **Techbaum**, **Skilltree**, **Nächste Ziele**. Der Tab „Nächste Ziele“ listet für Objekte, Materialien, Werkzeug-Stufen und Helfer die nächste Freischaltung mit dem, was fehlt (Level, Tech, Bolts, Material), als große Karten mit Icon und Fortschrittsbalken. Alles mindestens 24 px, Fokus orange.

## 20. Auswirkungen auf Techbaum und Zielkurve

- Neue Techknoten: 16 `helper_workshop` Helfer-Werkstatt (2.500 Bolts, 20 Chrom, 180 s, nach 14), 17 `helper_tools` Helfer-Werkzeug II (3.000 Bolts, 120 s, nach 16). Autopilot v0.1 kostet zusätzlich 10 Chrom.
- Zielkurve: Phase D (60–120 min) enthält jetzt Tier 2/3 und Level 10–15; Phase E (120–180 min) Helfer-Roboter und Level 15–20.
- Scope: Der MVP wächst von 9 auf 11 Meilensteine (siehe Roadmap). Helfer-Roboter sind das letzte Feature vor der Politur und bei Zeitnot abtrennbar.
