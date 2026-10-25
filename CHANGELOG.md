# Changelog – Scrap Empire

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Versionen folgen den Meilensteinen aus docs/03_ROADMAP.md (0.MS.Schritt).

## [1.4.0] – 2026-10-25 – MS15 Deko und Fundstücke (Phase 2, Teil 3)

### Hinzugefügt
- **Tech „Deko-Werkbank“** (nach Kiste, 150 Bolts, 10 Holz, 10 Stein) schaltet Dekoration frei; **Tech „Museum“** (nach Deko-Werkbank, 400 Bolts, 10 Eisenbarren, 5 Plastikplatten) das Museum-Gebäude. Damit 20 Techknoten
- **Dekoration** ohne Spielnutzen, Kosten in Holz, Stein, Schrott: Laterne, Bank (2×1), Blumenkasten, Schrott-Skulptur, Holzschild, Steinkreis. Das Baumenü hat dafür eine zweite Seite „Deko“ (LB/RB wechselt, nur mit Werkbank sichtbar)
- **Fundstücke:** neun einzigartige Objekte, eines je Zone (Gartenzwerg Gunther, Alte Gitarre, Kaffeemaschine Kurt, Gummiente, Plüschkrake, Schneekugel, Rostige Trophäe, Lesebrille, Spieluhr). Sie funkeln und schweben, Rusty sammelt sie beim Darüberfahren: Konfetti, Spruch, 60 XP, Hinweis oben. Position deterministisch je Zone; gefundene stehen im Spielstand und tauchen nie wieder auf
- **Tab „Journal“** im Fortschritts-Menü: Zähler, Museum-Status, je Fundstück Name und humorvoller Text; noch nicht gefundene zeigen „???“ und die Zone oder das Kapitel. Tab „Kapitel“ zeigt „Fundstücke: n / 9“
- `data/collectibles.json`, `src/sim/collectible.gd`, `src/world/collectible_view.gd`; Gebäudedefinitionen kennen `category` und `requires_feature`; Spielstand-Version 6 (gefundene Fundstücke), Migration 5 → 6
- Tests: `tests/test_cozy.gd` (Deko-Sperre und Kosten, Museum per Tech, deterministisches Platzieren, Einsammeln mit XP, Speichern ohne Respawn, Migration). Dev-Szenario `cozy`, Screenshot-Cheat `goto_collectible=`

## [1.3.0] – 2026-10-25 – MS14 Logistik-Drohnen (Phase 2, Teil 2)

### Hinzugefügt
- **Tech „Drohnen-Hangar“** (nach Helfer-Werkstatt, 1200 Bolts, 10 Schaltkreise, 15 Zahnräder, 60 s) schaltet Logistik-Drohnen frei; damit 18 Techknoten
- **Drohnen** fliegen über alles hinweg zwischen einer Quelle (Kiste oder Maschinen-Ausgang) und einem Ziel (Kiste, Maschine oder Terminal). Sie tragen 10 Items je Flug, warten 3 s, wenn die Quelle leer ist, das Ziel nichts annimmt oder das Limit erreicht ist. Maximal 4, Kosten 600 × 1,4ⁿ Bolts + 3 Schaltkreise
- **Tab „Drohnen“** im Fortschritts-Menü (erst nach dem Hangar sichtbar): Kauf mit Quelle und Ziel per Fadenkreuz, Karte je Drohne mit Zustand, Ladung, Material, Limit und Fahrten. A wechselt das Material (alles oder ein bestimmtes Item), X das Limit (keins, 10, 25, 50, 100 im Ziel), LT entfernt die Drohne. Upgrades: Tempo (+25 %/Stufe, 3 Stufen), Tragkraft (+10/Stufe, 2 Stufen)
- Drohnen-Figur (Quadcopter mit Schatten, Schwebe-Bob, getragenes Item als Symbol; halbtransparent beim Warten); Rusty kommentiert Kauf und Fehler
- Tab „Kapitel“ nennt den Hangar als nächstes Ziel, sobald Helfer da sind
- `data/drones.json`, `src/sim/drone.gd`, `src/world/drone_view.gd`; Spielstand-Version 5 (Drohnen mit Quelle und Ziel als Kacheln, Upgrades), Migration 4 → 5
- Tests: `tests/test_drones.gd` (Kaufbedingungen, Kostenkurve, Kiste → Ofen, Material-Filter, Limit, leere Quelle, fehlendes Gebäude, Upgrades, Speichern und Migration). Dev-Szenario `drones` (Kiste mit Schrott → Ofen → Terminal, zwei Drohnen)

## [1.2.0] – 2026-10-25 – MS13 Zonen-Heilung (Phase 2, Teil 1)

### Hinzugefügt
- **Der Planet heilt:** Je Reinigungsstufe wächst in einer Zone Natur nach: etwas Gras ab „unordentlich“, Gras und Blumen ab „aufgeräumt“, dazu Büsche und Teiche ab „sauber“. Dekor erscheint mit kleiner Pop-Animation, Platz wird deterministisch je Zone gewählt (gleiche Zone heilt immer gleich) und lässt Haufen, Gebäude und Zäune frei
- **Tiere:** ab „aufgeräumt“ ein Käfer, ab „sauber“ zwei Käfer und zwei Vögel je Zone. Sie streunen in ihrer Zone, hüpfen beim Laufen und folgen Rusty neugierig mit Abstand. Rusty kommentiert das erste Tier
- **Tageslicht:** weiche Farbpendelung zwischen warmem Morgen und kühlem Nachmittag über 6 Minuten, nie dunkel (mindestens 90 % Helligkeit)
- **Leichter Regen:** alle 4 bis 7 Minuten für 30 s, mit Tropfen und blauem Schimmer; Rusty hat zwei Regensprüche. Rein kosmetisch, lässt noch nichts schneller wachsen
- Legende mit vier Farbfeldern unter der großen Karte
- `data/nature.json` (Dichten je Stufe, Tiere, Tageszyklus, Regen), `src/world/nature_planner.gd`, `nature_view.gd`, `critter_view.gd`, `day_light.gd`, `rain_layer.gd`
- Tests: `tests/test_nature.gd` (deterministischer Plan, mehr Dekor je Stufe, Rand und belegte Kacheln frei, keine Überlappung, Tageslicht nie dunkel). Screenshot-Werkzeug: `clean=z01;0.95` und `rain=1`

## [1.1.0] – 2026-10-25 – MS12 Gameplay-Klarheit und Design

Antwort auf die Rückmeldung „Karte deckt nicht auf, keine Ressourcen in den anderen Kapiteln, zu kompliziert“.

### Hinzugefügt
- **Kapitel-System:** Die neun Zonen sind Kapitel in fester Reihenfolge (Startlager → Kabelsenke → Nordstrand → …). Jede Zone ist von einem Schrottzaun umgeben; das Tor zur nächsten Zone öffnet sich, sobald die aktuelle Zone zu 50 % sauber ist (Konfetti, Spruch, Hinweis oben)
- **Nebel auf Minimap und Karte:** nicht freigeschaltete Zonen sind dunkelgrau mit „?“ und heißen nur „Kapitel N“; Müll-Punkte erscheinen erst nach dem Aufdecken. Die Bodenfarbe im Spiel zeigt den Zustand: dunkel (unentdeckt), braun (vermüllt), grau, hellgrün, grün (sauber)
- **Tab „Kapitel“** zuerst im Fortschritts-Menü: aktuelle Zone, Ziele mit Haken (Tutorial, 50 % sauber), nächstes Tor, Tipp je Kapitel, darunter wie bisher Forschung, Objekte, Level. Tabs heißen jetzt Kapitel, Forschung, Skills, Karte, Helfer (Helfer erst nach der Werkstatt-Forschung sichtbar)
- **Kapitel-Zeile im HUD** nach dem Tutorial: „Kapitel 1 · Startlager · 30 % sauber · Tor öffnet bei 50 %“
- **Rezepte sichtbar:** neben einer Maschine steht in der Hinweiszeile „Schmelzofen: 3 Schrott → Eisenbarren | 2 Kupfer → Kupferbarren“; im Baumenü steht bei Maschinen „(macht: Eisenbarren, Kupferbarren)“
- **Titelbildschirm** mit Weiterspielen (nur mit Spielstand), Neues Spiel, Sprache, Beenden; Rusty wippt daneben
- `data/chapters.json` mit Tipp-Schlüsseln je Zone; Spielstand-Version 4 (freigeschaltete Zonen) mit Migration 3 → 4
- Tests: `tests/test_chapters.gd` (Freischaltung, Helfer-Sperre, fehlende Zonen auffüllen, Save v4, Produktkosten). Screenshot-Werkzeug kann jetzt Techs freischalten (`tech=`), Zonen öffnen (`unlock=`), Rusty neben ein Gebäude stellen (`goto=`) und andere Szenen laden

### Geändert
- **Produkte sind Baustoff:** Förderband und Saugstation kosten Eisenbarren, Presse kostet Eisenbarren, Rucksack kostet Plastikplatten, Ölwechsel Kupferbarren, Terminal-Upgrade und Schaltkreis-Forschung Zahnräder, Autopilot Schaltkreise und Chrom, Helfer-Werkstatt Zahnräder, Schaltkreise und Chrom. Damit hat der Schmelzofen einen Zweck jenseits des Verkaufs
- Helfer lassen sich nur in freigeschalteten Zonen einsetzen (Spruch „Da darf noch keiner hin“)
- Kapitel-Reihenfolge so gelegt, dass jede Zone an die vorherige grenzt
- Hinweiszeile kürzer: „Stick: bewegen · RT: saugen · LT: hämmern · Y: bauen · Select: Kapitel und Forschung“
- Bolts-Anzeige als runde dunkle Plakette mit Schrauben-Symbol
- Der alte Einzel-Zaun um die Tutorial-Zone ist durch die Zonenzäune ersetzt; das Tutorial öffnet das Tor nicht mehr, der Reinigungsgrad tut es

### Behoben
- **Keine Ressourcen in den anderen Kapiteln:** ältere Spielstände hatten nur die Objekte der Tutorial-Zone. Beim Laden werden Zonen ohne Objekte jetzt aus der Karte nachgefüllt

## [1.0.0] – 2026-10-25 – MS11 MVP-Politur (MVP fertig)

### Hinzugefügt
- MVP-Ende-Bildschirm, sobald alle 17 Techknoten erforscht sind: Spielzeit, Bolts, Level, Helfer, saubere Zonen; einmalig, danach geht das Spiel weiter
- Helfer sagen alle 60 bis 120 s einen Leerlauf-Spruch; Debug-Overlay zeigt die Helferzahl
- README mit Steuerungstabelle, Entwickler-Tasten, Test- und Build-Anleitung
- Dev-Szenario „endgame“ für den Ende-Bildschirm

### Geändert
- Sprechblasen bleiben im Bild: am oberen Rand erscheinen sie unter dem Sprecher, seitlich werden sie hereingeschoben
- Baumenü graut nicht leistbare Gebäude zusätzlich aus
- Alle englischen Texte automatisch auf deutsche Umlaute geprüft (0 Treffer)

## [0.10.0] – 2026-10-25 – MS10 Helfer-Roboter

### Hinzugefügt
- `data/helpers.json`: Kostenkurve 400 × 1,5^n Bolts + 5 Chrom, maximal 6 Helfer, Namen (Bolte, Knirps, Dübel, Fräulein Flex, Schraubi, Rostnase), Farben, Sprüche, Steckenbleiben alle 4 bis 6 Minuten für 5 s
- Helfer arbeiten in einer Zone (Radius 6 Kacheln) alle Objekte bis zu ihrer Werkzeug-Stufe ab und bringen die Ladung zum Lager (Kiste oder Terminal); sie planen nach jedem Durchlauf neu und nutzen die Aufgabenlogik des Autopiloten
- Tab „Helfer“ im Fortschritts-Menü: Kauf mit Zone und Lager per Fadenkreuz, Liste mit Zustand, Zone und Ladung (A entlässt), drei globale Upgrades: Tempo (+20 %/Stufe), Tragkraft (+10 Items je Slot/Stufe), Werkzeug (T2, T3 nach Tech „Helfer-Werkzeug II“)
- Helfer-Figuren in eigener Farbe mit Namensschild und eigener Sprechblase; Konfetti beim Kauf
- Spielstand-Version 3 mit Helfern und Upgrades; Migration 2 → 3
- Dev-Szenario „helpers“; 11 neue Tests (162 gesamt)

### Geändert
- Tech „Helfer-Werkzeug II“ schaltet jetzt das Upgrade „Helfer-Werkzeug“ frei statt direkt die Stufe zu setzen
- Aufgabenliste zählt Schleifendurchläufe (für Helfer-Planung)

## [0.9.0] – 2026-10-25 – MS9 Zonen, Minimap und Karte

### Hinzugefügt
- Zonen aus der Karten-JSON mit Reinigungsgrad: Müll = Items in Loot-Objekten ohne Rohstoff-Flag; Stufen vermüllt / unordentlich / aufgeräumt / sauber; Stufenwechsel mit Spruch, ab „aufgeräumt“ mit Konfetti
- Respawn-Sperre: Müll respawnt nur, solange die Zone unter 50 % sauber ist; Rohstoffquellen (Haufen, Satellit) respawnen immer (Grundsatz: nie ohne Ressourcen)
- Minimap unten rechts: Zonen in Stufenfarbe, Müll-Punkte, Gebäude, Rusty-Pfeil; ausblendbar mit M oder Select lang
- Tab „Karte“ im Fortschritts-Menü: Zonen mit Namen und Prozent, D-Pad wählt eine Zone, Infotafel mit Reinigungsgrad, Zustand, Müll und Objekten je Stufe; RT/LT zoomen, rechter Stick scrollt
- Alles aus Schrott: Objekte Kaputte Palette, Betonbrocken (T1), Verrottetes Sofa, Ruinenmauer (T2), Materialien Holz und Stein mit nachwachsenden Quellen Treibholz-Stapel und Geröllfeld; Hauptkarte neu erzeugt (149 Objekte)
- Kurz/Lang-Erkennung für Y und Select per Tastenzustand (funktioniert auch mit simulierten Eingaben)
- 7 neue Tests (151 gesamt)

## [0.8.0] – 2026-10-25 – MS8 Tutorial und Autopilot

### Hinzugefügt
- Hauptkarte `data/maps/main.json` (120×90, 9 benannte Zonen, 146 Objekte, Tier steigt mit der Entfernung; Generator `tools/gen_main_map.py`); die alte Tutorial-Karte ist jetzt die Zone „Startlager“ links in der Mitte
- Zaun aus Schrottbergen um die Tutorial-Zone mit Tor nach Osten; das Tor öffnet sich nach dem Tutorial
- Tutorial mit fünf Schritten aus `data/tutorial.json` (bewegen, 30 Schrott saugen, Terminal bauen und verkaufen mit 20 Bolts Bonus, Toaster zerlegen, Schmelzofen erforschen), Fortschritt oben im HUD, Konfetti und Spruch je Schritt
- Autopilot (nach Tech „Autopilot v0.1“): Aufgaben-Editor per Y lang oder L mit Schritten Gehe zu, Sammle hier, Hämmere hier, Lege ab in, Nimm aus; Ziel per Fadenkreuz-Cursor; X löscht, LB/RB verschiebt; Starten/Stoppen; Autopilot-Kette im HUD mit aktuellem Schritt
- Arbeiter-Logik `TaskList` (später auch für Helfer): läuft zum Ziel, saugt bis voll oder Quelle leer, hämmert und sammelt die losen Teile ein, legt ab und nimmt aus Gebäuden, wartet 5 s bei Problemen mit Spruch (gedrosselt), Schleife endlos; jede Stick-Eingabe unterbricht sofort; Autopilot v0.2 macht ihn 1,5× schneller
- Spielstand-Version 2 mit Aufgaben, Tutorial-Stand und Tor; Migration 1 → 2 verschiebt alte Stände in die Zone „Startlager“ und gilt sie als Tutorial-fertig
- Satellit und Haufen sind als unendliche Rohstoffquellen markiert (Grundsatz: nie ohne Ressourcen)
- Dev: Szenario „auto“ für Screenshot-Tests; 10 neue Tests (144 gesamt)

## [0.7.1] – 2026-10-25 – F7-Fix und Testschutz

### Behoben
- F7 (Beispielkette) baut jetzt drei Kacheln unter Rusty statt an festen Koordinaten unter dem Startpunkt, bringt einen eigenen Schrotthaufen mit, sucht sich eine freie Reihe und meldet, wenn kein Platz ist

### Hinzugefügt
- `tests/shot.sh`: Screenshot-Läufe sichern den echten Spielstand vorher und stellen ihn danach wieder her (nach einem versehentlich gelöschten Spielstand)
- `tests/restore_save.gd`: erzeugt einen Spielstand mit vorgegebenen Werten
- Screenshot-Skript protokolliert Rustys Sprüche

## [0.7.0] – 2026-10-25 – MS7 Speichern und Pause

### Hinzugefügt
- Versionierter JSON-Spielstand (`SaveCodec`, Version 1): Welt mit Objekten, losen Items, Gebäuden samt Puffern, Fortschritt und Band-Items, Respawn-Timer, Spieler, Inventar, Bolts, XP/Level/Skillpunkte, Skills, laufende Forschung, Zufallszustand
- Zwei rotierende Dateien plus Meta-Datei unter `user://saves/`; eine kaputte Datei fällt auf die andere zurück (Test); Migrationsgerüst mit Tests
- Autosave alle 60 s, beim Öffnen des Pause-Menüs, beim Beenden über das Menü und beim Schließen des Fensters; „Gespeichert ✔“ als Sprechblase
- Laden beim Start, wenn ein Spielstand existiert; Rusty begrüßt mit „Alles noch da. Ich habe aufgepasst.“
- Pause-Menü: Sprache Deutsch/English (wird gespeichert, Szene lädt neu), Neues Spiel (zweimal A zur Bestätigung), Speichern und Beenden
- Dev: F5 speichert sofort
- Determinismus-Test: gespeicherte und geladene Welt verhalten sich über 300 Ticks identisch
- 6 neue Tests (134 gesamt)

### Geändert
- Spracheinstellung liegt im SaveManager (Autoload-Reihenfolge), nicht mehr in GameConfig

## [0.6.0] – 2026-10-25 – MS6 Fortschritts-Menü (Techbaum, Skilltree, Nächste Ziele)

### Hinzugefügt
- `data/tech.json` mit 17 Knoten (Kosten, Forschungszeit, Voraussetzungen, Effekte); Forschung kostet Bolts/Chrom sofort und läuft eine Forschung gleichzeitig; Forschungsbalken oben im HUD
- Gebäude sind erst nach der passenden Forschung baubar (Baumenü zeigt nur Freigeschaltetes, Terminal ist von Anfang an frei); Rezepte Zahnrad und Denkbrett werden freigeschaltet; Tech-XP = Kosten / 10
- `data/skills.json` mit 4 Ästen und 13 Skills (48 Stufen), 1 Skillpunkt je Stufe, Voraussetzungen innerhalb des Astes, Test beweist: keine Sackgassen
- `Modifiers`: alle Boni aus Skills und Tech an einem Ort und wirksam: Lauf- und Drehtempo, Turbo-Boost (L3 / Shift), Inventar-Slots und Stapelgröße (Hotbar wächst mit), Magnet (lose Items im Umkreis), Verkaufsboni (Feilschen, Kenner für seltene Items, Großhändler bei vollem Puffer), Hammer-/Sauger-Stufe, Abbau-Tempo, Reichweite (Saugkegel wächst mit), Items pro Hammerschlag, Turbo-Terminal
- Fortschritts-Menü (Select / T) mit Tabs Techbaum, Skilltree, Nächste Ziele; LB/RB wechseln, D-Pad/Fokus, A forscht oder kauft, B schließt; „Nächste Ziele“ zeigt nächste Forschungen mit fehlenden Bolts, nächstes zu hartes Objekt mit dem nötigen Skill, Helfer-Voraussetzung und nächstes Level
- Rusty-Sprüche für Forschung fertig, fehlende Bolts/Material, laufende Forschung, Skill gekauft, gesperrtes Gebäude
- 19 neue Tests (128 gesamt)

### Geändert
- Dev-Cheat F4 gibt jetzt 500 Bolts, Material, 5 Chrom und 100 XP (Werkzeug-Stufen kommen aus dem Skilltree)
- Tech „Kurvenband“ aus dem GDD durch „Saugstation“ ersetzt (Kurven sind seit MS5 automatisch)

## [0.5.0] – 2026-10-25 – MS5 Förderbänder

### Hinzugefügt
- Förderband (1×1, 1 Schrott): Items mit 1/256-Kachel-Offsets, 26 Einheiten pro Tick (≈ 2 Kacheln/s), 4 Items je Kachel, Stau mit Abstand 64
- Automatische Kurven: ein Band mit einem einzigen seitlichen Zulauf wird zur Kurve (Einspeisung am Anfang); sonst Seiteneinspeisung in der Mitte
- Übergabe an Maschinen über Eingangsports (Eingang max. 10 je Item), Terminal per Band max. 10, Kiste von allen Seiten; Maschinen-Ausgänge legen je Tick ein Item auf das Band vor dem Port
- Tick-Reihenfolge „Ziel vor Quelle“ wird nach jeder Bauänderung neu berechnet; Ports drehen mit dem Gebäude
- Saugstation (1×1, 20 Schrott + 5 Kupfer): zieht alle 3 s ein Item aus einem angrenzenden Haufen, Puffer 5, Ausgang vorne
- Band-Ziehen im Baumodus: A/LMB halten und Cursor bewegen legt Bänder in Laufrichtung und dreht das vorherige mit; Befehl „drehen“ für Bänder und Stationen
- Spieler kann per A ein Item auf ein Band legen und vorne eines herunternehmen
- MultiMesh-Renderer für Band-Items mit Tick-Interpolation; Bänder unter allem, blockieren Rusty nicht
- Dev: F6 legt ~480 Bänder mit ~1.900 Items (Perf-Test, Overlay zeigt Band-Items), F7 baut eine Beispielkette Haufen → Saugstation → Band → Ofen → Band → Terminal unterhalb des Starts
- 16 neue Tests (109 gesamt); Test-Runner hängt nicht mehr bei Parse-Fehlern einer Testdatei

### Gemessen
- Perf-Szenario auf dem Entwicklungs-Laptop: 60 FPS, Tick 2,7 ms bei 1.884 Band-Items (Budget 3 ms)

## [0.4.0] – 2026-10-25 – MS4 XP, Level und Schrott-Stufen

### Hinzugefügt
- `data/progression.json`: XP-Quellen (Abbauen 1 × Tier, 1 XP je 5 Bolts Verkaufserlös, Bauen 5, Tech Kosten/10), Level-Kurve 100 × 1,15^(n-1) auf 5 gerundet, Level-Obergrenze 20, 1 Skillpunkt je Level
- XP-Leiste unten links (Level, Balken, Skillpunkte), pulst beim Aufstieg; Konfetti über Rusty und drei Level-Up-Sprüche
- `data/scrap_objects.json`: zehn Schrott-Objekte mit Tier 1–5, Werkzeug, Ausbeute und Respawn (Toaster, Kühlschrank, Einkaufswagen, Raumschiff-Teil, Satellit, Roboter-Arm, Monolith plus die drei Haufen)
- Neue Materialien Chrom (8 Bolts), Titan und Sternenstaub (Tier 4/5, erst nach dem MVP abbaubar)
- Werkzeug-Stufen für Sauger und Hammer: zu harte Objekte lösen Funken, Wackeln und „Zu hart!“ / „Zu schwer!“ aus, kein stiller Fehlschlag; Hinweis höchstens einmal pro Sekunde
- Saugbare Loot-Objekte (Einkaufswagen, Satellit) werden leer und verschwinden; Objekte respawnen nach ihrer Zeit mit Pop-Animation
- Tier-Abzeichen (T2 bis T5) farbig über jedem Objekt ab Stufe 2
- Tutorial-Karte zeigt alle Tiers: 2 Toaster, 2 Kühlschränke, Einkaufswagen, Raumschiff-Teil, Satellit, Roboter-Arm, Monolith
- Dev-Cheat F4 (bis zum Skilltree in MS6): Werkzeug-Stufe +1 und etwas Material; Debug-Overlay zeigt Stufen und XP
- 16 neue Tests (93 gesamt)

### Geändert
- `ResourceNode` ist datengetrieben (Definitionen aus JSON statt im Code); das alte „Wrack“ heißt jetzt „Verbeulter Kühlschrank“ (Tier 2)
- GDD-XP-Tabelle an die exakte Rundung angepasst (Level 20: 1.240 XP, kumuliert 8.815)

## [0.3.0] – 2026-10-25 – MS3 Maschinen

### Hinzugefügt
- `data/recipes.json` mit fünf Rezepten: Eisenbarren (3 Schrott, 4 s), Kupferbarren (2 Kupfer, 4 s), Plastikplatte (2 Plastik, 3 s), Zahnrad und Schaltkreis „Denkbrett“ (bis zur Tech gesperrt)
- Fünf neue Items mit Icons und Verkaufswerten: Eisenbarren 6, Kupferbarren 10, Plastikplatte 7, Zahnrad 20, Denkbrett 30
- Schmelzofen (40 Schrott + 10 Kupfer) und Presse (60 Schrott + 20 Plastik) im Baumenü
- `Machine`: Eingangspuffer max. 10 je Item, Ausgangspuffer max. 10, Rezeptwahl nach Listenreihenfolge, Tech-Sperre je Rezept
- Darstellung: Fortschrittsbalken, Puffer-Icons über dem Gebäude (links Eingang, rechts Ausgang), Status „!“ bei vollem Ausgang und „?“ im Leerlauf
- A mit leerem Slot nimmt zuerst aus dem Ausgang, sonst aus dem Eingang (Fehleinwürfe korrigierbar)
- Rusty-Sprüche: falsches Item („Das passt da nicht rein.“), erste Maschine („Es brummt. Das ist gut. Glaube ich.“)
- 10 neue Tests (77 gesamt)

## [0.2.1] – 2026-10-25 – Maus im Baumodus

### Behoben
- Verkaufsterminal ließ sich per Mausklick nicht platzieren: linke Maustaste platziert/reißt ab, rechte Maustaste bricht ab (Feedback aus MS2-Test)

### Geändert
- Hinweiszeile zeigt je nach Eingabegerät Gamepad-Tasten oder Maus/Tastatur-Belegung

## [0.2.0] – 2026-10-25 – MS2 Bauen und Verkaufen

### Hinzugefügt
- `data/buildings.json`: Verkaufsterminal (2×2, 30 Schrott, Kostenfaktor 1,35) und Kiste (1×1, 10 Schrott, fest)
- Simulation: `Grid` (Belegung), `Building`/`SellTerminal`/`Chest`, `Economy` (Kostenformel, Bezahlen, Erstattung), Befehle place/remove/deposit/withdraw, `bolts`
- Verkaufsterminal verkauft 1 Item / 0,5 s aus einem Puffer (max. 40), Bolts zählen hoch, „+N“ schwebt über dem Terminal
- Kiste: 12 Slots × 20, A legt ein, A mit leerem Slot nimmt heraus
- Baumenü (Y): Gebäude mit Icon und Kosten, „Abreißen“, Fokusnavigation, B schließt
- Bau-Cursor: D-Pad/Pfeiltasten mit Wiederholung, rechter Stick, Maus; Vorschau grün/rot; A platziert, X dreht, B bricht ab; Reichweite 6 Kacheln
- Abreißen erstattet gezahlte Kosten und Inhalt (Rest fällt als lose Items)
- Hotbar-Auswahl (LB/RB) mit orangem Rahmen; Kontexthinweise unten („A: 20 Schrott in Verkaufsterminal einlegen“)
- Rusty-Sprüche bei Baufehlern (zu wenig Material, kein Platz, zu weit weg)
- Gebäude blockieren Rusty (Kollision)
- 24 neue Tests (67 gesamt)

## [0.1.1] – 2026-10-25 – Pause-Menü (aus MS6 vorgezogen)

### Hinzugefügt
- Pause-Menü (Start / Esc): „Fortsetzen“ und „Spiel beenden“, hält Spiel und Simulation an, Gamepad-Fokus mit orangem Rahmen, B/Start schließt
- Button-Stil im Theme (dicke Outline, 28 px Schrift, Fokus-Rahmen) für alle späteren Menüs
- `build.ps1` benennt die EXE nach der Projektversion (`ScrapEmpire_v0.1.1.exe`), damit ein laufendes Spiel den Build nicht blockiert

### Geändert
- Hinweiszeile nennt Start / Esc: Menü

## [0.1.0] – 2026-10-25 – MS1 Sammeln

### Hinzugefügt
- Tutorial-Karte 40×30 aus `data/maps/tutorial.json`: 6 Schrotthaufen, 2 Kabelknäuel, 2 Plastikbröckchen, 3 Wracks
- Simulation: `Inventory` (6×20), `ResourceNode` (Haufen wachsen alle 30 s um 1 bis 10; Wracks endlich), `LooseItem`, `SimRng`, `PlayerState`
- Saugen (RT / linke Maustaste): Kegel 90°, 2,5 Kacheln, 1 Item pro 0,25 s; lose Items vor Haufen; Hinweis bei vollem Inventar
- Hämmern (LT / rechte Maustaste): 1 Kachel Reichweite, 1 Schlag pro 0,5 s, schlägt je ein Item aus dem Wrack, Wrack verschwindet bei 0
- Darstellung: Knoten-Sprites (Haufen schrumpfen mit Menge, Wracks wackeln), lose Items mit Auf-und-ab, Einsammel-Flug zu Rusty, Saugkegel, Hammerschwung
- HUD: Hotbar mit 6 Slots (72 px), Bolts-Anzeige (Platzhalter), Hinweiszeile; Sprechblase über Rusty
- Rusty-Sprüche (`data/quips.json`, 11 Stück) für Start, volles Inventar, erster Schrott/Kupfer/Plastik, Wrack zerlegt, 60 s Leerlauf
- Lokalisierung DE/EN über `locale/strings.csv`, Sprache folgt dem System
- `DataRegistry` lädt `items.json` und `quips.json`; `MapLoader` mit Tests (43 Tests gesamt)

### Geändert
- Rusty dreht sich weich in Laufrichtung (Feedback aus MS0-Test)
- Vollbild im exportierten Build wird per Code gesetzt statt über Projekt-Override

## [0.0.1] – 2026-10-25 – MS0 Projektgerüst

### Hinzugefügt
- Godot-4.7.2-Projekt: 1920×1080, Stretch `canvas_items`, Mobile-Renderer, Vollbild nur im Export-Build
- Ordnerstruktur gemäß docs/02_ARCHITECTURE.md, Git-Repo mit .gitignore (Engine-Ordner, .godot/, export/ ausgeschlossen)
- Simulationskern: `TickAccumulator` (20 Ticks/s, Spiralschutz) und `SimWorld` (Tick-Zähler, Befehlswarteschlange)
- Autoloads: GameConfig, EventBus, DataRegistry (Stub), SimClock, SaveManager (Stub), InputRouter (Geräteerkennung, F11 Vollbild)
- Input-Map zur Laufzeit (`InputMapSetup`): Gamepad + Tastatur/Maus für alle MVP-Aktionen, Deadzone 0,2
- Rusty (SVG-Platzhalter) mit Bewegung per linkem Stick/WASD, Zielmarker per rechtem Stick/Maus, Kamera mit Zoom 1,5 und Begrenzung
- Flache Welt 120×90 Kacheln mit Sandboden und unsichtbaren Wänden
- Debug-Overlay (F3): FPS, Tick-Zeit, Tick-Zähler, Item-Anzahl, Eingabegerät
- Theme mit 24 px Standardschrift
- Headless-Test-Runner (`tests/run_tests.gd`, 10 Tests) und Screenshot-Werkzeug (`tests/screenshot.gd`)
- Export-Preset „Windows Desktop“ und `build.ps1`

## [Unreleased]

### Hinzugefügt
- 2026-10-25: Game Design Document (docs/01_GDD.md) mit Progressionskurve, Ökonomie-Formeln, Techbaum (15 Knoten) mit Forschungszeit, Aufgabenlisten-Konzept
- 2026-10-25: Technische Architektur und Ordnerstruktur (docs/02_ARCHITECTURE.md)
- 2026-10-25: Entwicklungsplan mit 9 Meilensteinen und „fertig, wenn“-Kriterien (docs/03_ROADMAP.md)
- 2026-10-25: TODO.md und CHANGELOG.md angelegt

### Geändert
- 2026-10-25: Entscheidungen Auftraggeber: keine Offline-Progression im MVP, Forschung mit Zeit, Aufgabenliste per Menü statt Aufzeichnung
