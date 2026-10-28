# Changelog – Scrap Empire

Format: [Keep a Changelog](https://keepachangelog.com/de/1.1.0/). Versionen folgen den Meilensteinen aus docs/03_ROADMAP.md (0.MS.Schritt).

## [1.22.0] – 2026-10-28 – MS33 Fehler aus dem Test, natürlicher Klang, Musik (Phase 2, Punkt 0)

### Behoben
- **Der letzte Müll war unzerstörbar:** Der Skill „Werkzeug“ hat jetzt 4 Stufen (T2 bis T5), damit knackt Rusty auch die Monolithen. Neuer Test: Jedes Objekt der Karte ist mit der höchsten Werkzeugstufe erreichbar, Ereignis-Müll schon mit dem Startwerkzeug
- **Das Geld reichte nie:** Übergangs-Wirtschaft, bis die neuen Zonen kommen: Schiffsstufen 300 / 1.200 / 2.000 / 2.800 Bolts, Ertrag 6 Stufen (40 bis 300 Bolts, je +15 %). Neuer Test vergleicht den Wert aller Karten-Objekte plus Kleinschrott (mit halbem Ertrags-Bonus) mit den Pflichtkosten bis zum Abflug: 8.428 verdienbar, 7.200 nötig. Ereignisse sind Bonus
- **Bots, die nichts tun, sagt man es jetzt an:** „Langweilig! Hier ist alles sauber.“ oder „Zu hart für mich! Ich brauch besseres Werkzeug.“ (alle 15 s), Rusty sagt einmal, was man tun kann, der Bots-Tab zeigt den Grund. Das eigentliche Umsetzen kommt mit MS34
- Weiterspielen-Prüfung zählte Fehler aus dem ersten Durchlauf nicht mit; jetzt schon

### Neu
- **Natürlicher Klang statt Piepsen:** dumpfes Plopp beim Einsammeln, kräftiger Schlag bei jedem Hammerschlag (auch von Bots in Rustys Nähe), Münzen beim Abliefern, weiche Pizzicato- und Steeldrum-Jingles für Kauf, Aufgabe, Meilenstein und Reparatur, Saxofon-Hupe der Touristen. Klick-Töne nur noch leise in Menüs
- **Fahrgeräusch:** sanftes Motorsummen mit leichtem Kettenrattern, Tonhöhe und Lautstärke folgen dem Tempo
- **Musik:** „Apple Cider“ von Zane Little Music (CC0) läuft in Schleife; Lautstärke im Pause-Menü
- `docs/CREDITS.md` aktualisiert

### Technik
- `Helper.bored`, Signal `helper_bored`, `Sfx.set_driving`; Preistests lesen ihre Zahlen jetzt aus den Daten
- 192 Unit-Tests (3 neue: Erreichbarkeit, Ereignis-Müll, Wirtschaft; 1 neuer zur Bot-Langeweile), 44 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Hören: Einsammeln, Hammer, Abliefern, Fahren. Klingt das weich und natürlich?
2. Musik läuft, im Pause-Menü leiser/lauter stellbar
3. Bot an einer sauberen Stelle bauen: Nach kurzer Zeit sagt er „Langweilig!“
4. Mit Werkzeug 4 einen Monolithen zerlegen
5. Reicht das Geld jetzt bis zum Abflug?

## [1.21.0] – 2026-10-26 – MS32 Echte Sounds, Lautstärke, Musik vorbereitet (Spielgefühl, Punkt 8)

### Neu
- **Echte Soundeffekte statt Piepsen:** 22 weiche, eher tiefe CC0-Sounds von Kenney (Interface Sounds, Impact Sounds): Plopp beim Einsaugen, Metallklirren beim Abliefern, Glocke bei erledigter Aufgabe, aufsteigender Ton beim Meilenstein, freundliche Bestätigung beim Kauf-Jubel, tiefe Glocke bei der Reparatur, Fragezeichen-Ton als Touristen-Hupe, weicher Aufprall bei Säcken und Meteoren, leise Klicks beim Öffnen, Schließen und Tabwechsel des Menüs. Jeder Effekt mit mehreren Varianten und leichter Tonhöhen-Variation, alle leise abgemischt
- **Dauersaugen:** sanftes Rauschen, das weich ein- und ausblendet, statt Einzeltönen
- **Lautstärke im Pause-Menü:** „Musik“ und „Effekte“, mit dem D-Pad links/rechts in 10-%-Schritten (A springt im Kreis). Wird gespeichert
- **Musik vorbereitet:** Eigener Musik-Kanal, das Stück wird in `data/audio.json` eingetragen. Noch keine Musik drin: Die Auswahl triffst du (Vorschläge unten)
- `docs/CREDITS.md` mit allen Quellen und Lizenzen

### Musik-Vorschläge (alle CC0, fröhlich; bitte eins auswählen)
1. **Feel Good Island** von Brandon75689: Marimba, Klavier, Bass, leichte Drums; verspielt und gut gelaunt. https://opengameart.org/content/feel-good-island
2. **Happy Lullaby (song17)** von cynicmusic: Glöckchen und Arpeggios, ruhig-fröhlich, nahtlos loopbar. https://opengameart.org/content/happy-lullaby-song17
3. **Happy Clappy Loop** von OwlishMedia: Klavier, beschwingt, nahtloser Loop. https://opengameart.org/content/happy-clappy-loop
4. **Apple Cider** von Zane Little Music: Akustikgitarre, Flöte, Pfeifen, gemütlich (leichter Retro-Klang). https://opengameart.org/content/apple-cider
5. **Green Hills** von Igor Gundarev: fröhliche Plattformer-Musik. https://opengameart.org/content/green-hills

Eine echte CC0-Ukulele-Nummer habe ich nicht gefunden; die Ukulele-Stücke auf OpenGameArt verlangen eine Namensnennung (CC-BY). Wenn das okay ist, suche ich gern danach.

### Behoben
- Pause-Menü: Die Reihenfolge für D-Pad hoch/runter läuft jetzt im Kreis über alle Einträge (vorher feste Nachbarn aus der Szene)

### Technik
- `Sfx` lädt `assets/audio/sfx/<id>_<n>.ogg` als Varianten, Busse `SFX` und `Music`, `set_volume`, `set_sucking`, Musik aus `data/audio.json`; Lautstärken in den Einstellungen (`vol_music`, `vol_sfx`)
- 188 Unit-Tests, 44 Gamepad-Prüfungen (neu: Lautstärke per D-Pad), 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Saugen, abliefern, kaufen, Aufgabe erledigen: Klingt alles weich und angenehm? Ist etwas zu laut oder nervig?
2. RT lange halten: sanftes Rauschen, beim Loslassen blendet es aus
3. Start: „Effekte“ auswählen, D-Pad links/rechts ändert die Lautstärke, Spiel neu starten: Wert bleibt
4. Musik-Vorschläge oben anhören und eins auswählen

## [1.20.0] – 2026-10-26 – MS31 Menüs schöner (Spielgefühl, Punkt 2)

### Neu
- **Ziele-Tab neu aufgebaut:** Oben groß die aktuelle Aufgabe mit Bild und Fortschrittsbalken („Jetzt dran“), darunter die nächsten zwei Aufgaben nebeneinander. Erledigte Aufgaben sind eingeklappt („12 Aufgaben erledigt · A: anzeigen“). Darunter Kapitel und nächste Schiffsstufe als kleine Karten mit Balken, der Werkzeug-Tipp und die Meilensteine als Kacheln mit Sternen und Balken
- **Schiff-Tab entschlackt:** Nur noch vier große Karten im 2×2-Raster
- **Nur eine Hinweiszeile:** Bei offenem Menü verschwindet die zweite Zeile unten
- **Verspielter:** Karten runder mit weichem Schatten, Fokus orange mit Glühen; die fokussierte Karte hebt sich leicht an. Das Menü ploppt beim Öffnen auf, beim Tabwechsel blendet der Inhalt weich ein

### Technik
- `_hero_card`, `_mini_card`, `_bar`, `_quest_icon`; der Ziele-Tab baut nur bei Änderung neu, der Fokus bleibt auch in verschachtelten Reihen erhalten
- 188 Unit-Tests, 41 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Select, Tab „Ziele“: Ist auf einen Blick klar, was jetzt zu tun ist?
2. D-Pad nach unten bis zu den Meilensteinen und zurück; auf „Aufgaben erledigt“ A drücken klappt auf und zu
3. Unten nur eine Hinweiszeile
4. Fühlen sich die Animationen beim Öffnen und Tabwechsel flott an oder bremsen sie?

## [1.19.0] – 2026-10-26 – MS30 Müll ist endlich, Nachschub kommt per Ereignis (Spielgefühl, Punkt 7)

### Geändert
- **Aller Müll ist endlich:** Haufen wachsen nicht mehr nach und verschwinden ganz, wenn sie leer sind (auch Treibholz, Geröll, Satellit). Nichts respawnt mehr
- **Haufen sehen nach Müll aus** statt nach grauen Bergen: Schrotthaufen mit Reifen, Dosen und Blech, Kupfer-Kabelsalat mit Steckern, bunter Plastikhaufen mit Flaschen und Bechern

### Neu
- **Weltraum-Touristen** (erstmals nach 4 Minuten, dann alle 4–6 Minuten): „Hup hup!“, 5 s später fliegt ein knallbuntes Camping-UFO vorbei und wirft 4–6 Müllsäcke ab. Rusty schimpft („Hey! Das ist kein Mülleimer!“). Säcke mit dem Hammer öffnen
- **Meteoritenschauer** (ab Schiffsstufe 2, alle 7–10 Minuten): Der Himmel färbt sich orange, 20 s Vorwarnung, dann stürzen 5–8 Brocken mit Feuerschweif herab. Sie enthalten Chrom, Titan und Sternenstaub
- **Bonus-Müll liegt obendrauf:** Er verschmutzt den Boden nicht, die Wiese bleibt Wiese. Er ist ergiebiger als normaler Müll: Ein Sack enthält 15–22 Teile (Toaster: 10), ein Meteor 16–24
- Höchstens 40 Bonus-Objekte gleichzeitig; alle Werte in `data/events.json`

### Hinweis zur Umsetzung
- Den „Wert ×1,5 / ×2“ aus dem Vorschlag habe ich als **mehr Inhalt** umgesetzt (Teile × 1,5 bzw. × 2), nicht als höheren Preis je Teil. Sonst müsste sich jedes einzelne Teil merken, woher es kommt

### Technik
- `EventSystem` (Sim, deterministisch, Zustand im Spielstand), `EventView` (Schild, UFO, fallende Säcke, Meteore, Staub, Himmel), `NodeSystem.after_take`, `ResourceNode.bonus/is_used_up`; Sounds `honk`, `thud` vorläufig selbst erzeugt
- 188 Unit-Tests (5 neue für Ereignisse, Regeltests auf „endlich“ umgestellt), 41 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Einen Schrotthaufen leer saugen: Er verschwindet ganz
2. Nach 4 Minuten: „Hup hup!“, UFO fliegt vorbei, Säcke fallen neben Rusty. Mit LT öffnen
3. Ab Schiffsstufe 2: orange Himmel, Meteore. Sind die Abstände gut, zu oft, zu selten?
4. Bleibt nach dem Aufräumen genug zu tun, oder wird es zwischen den Ereignissen zu leer?

## [1.18.0] – 2026-10-26 – MS29 Sauber wird Wiese (Spielgefühl, Punkt 6)

### Neu
- **Geputzter Boden wird saftige Wiese** statt gelbem Sand: kräftiges Grün mit Grashalmen und Blütenpunkten, Kachel für Kachel weich eingeblendet (ca. 2,5 s, leicht versetzt). Der Unterschied dreckig/sauber ist jetzt riesig
- **Ums Schiff beginnt die Wiese schon beim Start**, und die Putzwelle des Schiffs macht alles, was sie berührt, grün
- **Saubere Zone (ab 90 %):** Der ganze saubere Boden der Zone wird Wiese, auch anfangs sandige Stellen
- **Mehr Pflanzen:** hohes Gras und blaue Blumen dazu, dichter und schneller (0,6 bis 2,4 s)
- Minimap und Karte zeigen Wiese grün
- Kommt Müll zurück, wird die Stelle wieder dreckig und die Wiese verschwindet dort

### Technik
- `DirtMap.green` (gespeichert; ältere Stände leiten es aus „geputzt“ ab), `heal`, `heal_rect`; `MeadowView` (Shader-Maske wie beim Schmutz)
- 183 Unit-Tests (3 neue zur Wiese), 41 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Neues Spiel: Ums Schiff liegt eine grüne Wiese mitten im Dreck
2. RT über Dreck ziehen: Die Spur wird in 2 bis 3 s grün, Blumen poppen auf
3. Nach längerem Spielen mit viel Wiese: Bleibt es flüssig (60 FPS)?

## [1.17.0] – 2026-10-26 – MS28 Man sieht Rusty seine Skills an (Spielgefühl, Punkt 4)

### Neu
- **Anbauteile an Rusty**, je Skill in drei Stufen (angefangen, ab der Hälfte, voll ausgebaut):
  - Fahrtempo: breitere, gerippte Ketten, voll mit Goldrand
  - Taschen: kleiner Rucksack, dann grüner Tank mit Gurten, voll ein großer Tank mit Goldbändern und Anzeige
  - Saugtempo: Saugdüse vorne, wird größer, Rand orange, voll verchromt mit blauem Ring; Reichweite macht sie länger
  - Werkzeug: Hammer auf der Schulter, Stahl, voll golden
  - Magnet: ein bis drei Lampen, voll ausgebaut pulsieren sie
  - Boost: ein bis drei Auspuffrohre, beim Boost mit Flamme
  - Lackierung: Rennstreifen ab 12 Skill-Stufen, goldener Stern ab 28
- **Hotbar bricht nach 6 Plätzen um** (zweite Reihe), damit sie mit vielen Taschen nicht über der Aufgabenzeile liegt

### Technik
- `RustyLook` (zeichnet unter und über dem Körper, dreht sich mit), `Player.setup_look`; Screenshot-Cheats `skills=` und `zoom=`
- 180 Unit-Tests, 41 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Ersten Skill lernen: Am Rusty erscheint sofort ein Teil (z. B. Düse oder Rucksack)
2. Nach einer Stunde Spiel: Sieht Rusty deutlich anders aus als am Anfang?
3. Sind die Teile auf 7" erkennbar, oder wird Rusty zu unruhig?

## [1.16.0] – 2026-10-26 – MS27 Saugen fühlt sich gut an (Spielgefühl, Punkt 5)

### Neu
- **Eingesaugte Teile** fliegen im kleinen Bogen und drehend zu Rusty, schrumpfen und verschwinden mit einem Plopp-Wölkchen und einem leisen, tiefen Plopp (höchstens alle 60 ms, mit Tonhöhen-Variation)
- **Rusty bläht sich** bei jedem eingesaugten Teil kurz auf
- **Hotbar:** Kommt ein Teil dazu, springt die Zahl hoch und das Icon hüpft
- **Nächstes Ziel immer im HUD** (unter dem Planet-Balken): „Noch 40 Bolts bis Ertrag 3“, grün „Ertrag 3: jetzt leistbar!“, oder „Skillpunkt frei!“. Gezeigt wird das günstigste Schiff-Ziel (Reparatur, Ertrag, Bot, Drohne)

### Technik
- `GoalHint.next_goal`, `Player.gulp()`, `Sfx.play_throttled`; 179 Unit-Tests (2 neue fürs Ziel), 41 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. RT auf einen Schrotthaufen halten: Teile fliegen zu Rusty, Plopp, Rusty pumpt, Hotbar-Zahl hüpft. Macht das Saugen allein schon Spaß?
2. Links oben unter „Planet“: Stimmt das nächste Ziel, wird es grün, sobald es leistbar ist?
3. Ist das Plopp beim Dauersaugen angenehm oder nervig? (Echte Sounds kommen in MS32)

## [1.15.0] – 2026-10-26 – MS26 Jubel nach dem Kauf (Spielgefühl, Punkt 3)

### Neu
- **Nach jedem Kauf jubelt Rusty:** Upgrade, Skill, Schiffsstufe, Bot, Drohne, Bot- und Drohnen-Upgrades. Das Menü schließt sich, Rusty hüpft zweimal, dreht sich einmal um sich selbst, Sterne sprühen, dazu ein kurzer, weicher Dreiklang. Dauer 0,9 s, währenddessen ruht die Steuerung, danach geht es sofort weiter
- Bei einer Schiffsreparatur schaut die Kamera nur noch gut 1 s zum Schiff (vorher 3 s); Schild, Konfetti und Putzwelle bleiben
- Während des Jubels ist die Hinweiszeile leer

### Technik
- `Player.cheer()` / `is_cheering()`, `Main._celebrate_purchase()`; Sound `cheer` (vorläufig selbst erzeugt, echte Sounds in MS32)
- 177 Unit-Tests, 41 Gamepad-Prüfungen (neu: Menü schließt nach Kauf, Steuerung nach höchstens 1 s zurück, auch nach Bot und Drohne) und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Skill lernen, Ertrag kaufen, Bot bauen: Menü geht zu, Rusty dreht sich mit Sternen, nach etwa 1 s fährt er wieder
2. Mehrere Käufe hintereinander: Ist das Wieder-Öffnen (X oder Select) okay, oder stört das Schließen?
3. Ist der Jubel-Ton angenehm oder zu hoch?

## [1.14.0] – 2026-10-26 – MS25 Skill und Schiff getrennt (Runde „Spielgefühl“, Punkt 1)

Neue Regel: **XP verbessert Rusty, Bolts verbessern das Schiff.** Nichts gibt es mehr doppelt.

### Geändert
- **Skills (XP):** Fahrtempo (8, +8 % Tempo und wendiger), Boost (3), Saugtempo (8, +12 % Saug- und Hammertempo), Reichweite (4), Magnet (3), Taschen (8, +1 Platz und +2 je Stapel), Werkzeug (3, kostet je 3 Punkte, knackt T2 bis T4). Jede Karte mit Icon, Stufen-Punkten und Punktkosten
- **Schiff (Bolts):** Reparatur, Ertrag (enthält jetzt den Bonus für seltene Teile), Sammel-Bots, Drohnen. Laderaum, Tempo, Saugtempo und Werkzeugstufe sind vom Schiff in die Skills gewandert, „Wendigkeit“, „Stapler“, „Tempo“ und „Kenner“ sind darin aufgegangen
- **2 Skillpunkte je Level, bis Level 25** (48 Punkte; alle Skills voll kosten 43)
- Aufgabenkette angepasst: erstes Ertrag-Upgrade, erster Skill, Taschen 2, Fahrtempo 1, Werkzeug-Skill, Saugtempo 2. Der Ziele-Tab verweist beim härteren Müll auf den Skill „Werkzeug“
- Skill-Texte stark gekürzt

### Spielstände
- Version 9. Alte Stände werden umgerechnet: Jede gekaufte Stufe bleibt (aus altem Skill und altem Schiff-Upgrade zählt die höhere), alle Skillpunkte kommen nach der neuen Regel zurück. Ausgegebene Bolts für ehemalige Schiff-Upgrades werden nicht erstattet, die Stufen bleiben aber geschenkt

### Technik
- `cost_points` je Skill, `SkillState.cost/total_bought`, neue Aufgabentypen `skills_bought` und `skill_level`, `SaveMigrations.v8_to_v9`
- 177 Unit-Tests (neu: keine Überschneidung Skill/Schiff, Werkzeug kostet 3 Punkte, Migration behält alle Stufen), 37 Gamepad-Prüfungen, 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Alten Spielstand laden: Rusty hat dieselben Taschen, dasselbe Tempo und Werkzeug wie vorher; unter Skills sind Punkte frei
2. Schiff-Tab: nur noch Reparatur, Ertrag, Sammel-Bot, Drohne
3. Skills-Tab: vier Spalten, jede Karte mit Bild, Punkten und Kosten
4. Fühlt sich der Weg zum ersten Skill (Level 2) zu lang an?

## [1.13.0] – 2026-10-26 – MS24 Menüs entschlacken (Kurswechsel Block 6)

Weniger lesen, mehr sehen.

### Neu
- **Am Anfang nur drei Tabs:** Schiff, Ziele, Karte. Skills erscheinen ab Level 2, Journal mit dem ersten Fundstück, Bots ab Schiffsstufe 2, Drohnen ab Stufe 3. Ein neuer Tab trägt einen orangen Punkt, bis man ihn besucht hat, und die Hinweiszeile unten sagt „Neu im Menü! · Select: ansehen“
- **Tabs mit Icons** (Schiff, Fahne, Stern, Karte, Bot, Drohne, Buch). „Kapitel“ heißt jetzt „Ziele“
- **Karten mit großen Icons:** Jedes Schiff-Upgrade hat ein eigenes Bild (Kiste, Bolt-Mutter, Rad, Saugdüse, Hammer). Stufen als Punkte (●●○○○), Kosten mit Bolt-Symbol: grün = leistbar, rot = fehlt noch. Kein „Fehlen noch X Bolts“-Text mehr. Die Reparatur-Karte zeigt das Schiff der nächsten Stufe und was es bringt
- **Bots- und Drohnen-Tab** im selben Stil; Texte gekürzt („+20 % Tempo“, „+10 Teile je Platz“, „Knackt härteren Müll“), aus „Helfer“ wird überall „Bot“
- Große Zahlen mit Tausenderpunkt (HUD, Kosten, Stufenleiste)

### Geändert
- **Bot abbauen jetzt mit LT** statt mit A (wie bei Drohnen). Vorher reichte ein versehentliches A auf der Bot-Karte, und der Bot war weg

### Behoben
- Bots-Tab: Der Fokus sprang alle halbe Sekunde zurück, weil die Liste neu gebaut wurde. Jetzt bleibt er auf dem gewählten Bot

### Technik
- `_make_card(title, icon)` mit Icon, Stufen-Punkten und Kostenzeile; `_set_cost`, `_set_pips`, `_refresh_upgrade_card`. Besuchte Tabs stehen in `flags.tab_seen_<n>`
- 175 Unit-Tests, 37 Gamepad-Prüfungen (neu: drei Tabs am Anfang, RB läuft rundherum, A baut keinen Bot ab, LT schon) und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Neues Spiel, Select: nur Schiff, Ziele, Karte. LB/RB wechselt im Kreis
2. Schiff-Tab: Sind die Icons auf 7" gut erkennbar? Ist grün/rot bei den Kosten klar?
3. Nach dem ersten Level-Aufstieg: unten „Neu im Menü!“, im Menü „Skills“ mit orangem Punkt
4. Bots-Tab: D-Pad auf einen Bot, A tut nichts, LT baut ihn ab
5. Fehlt irgendwo noch eine Information, die vorher im Text stand?

## [1.12.0] – 2026-10-26 – MS23 Erfolgserlebnisse (Kurswechsel Block 5)

Öfter ein kleines „Yes!“: mehr kurze Ziele, Meilensteine, sichtbares und hörbares Abliefern.

### Neu
- **Abliefern fühlt sich gut an:** Die Teile fliegen im Bogen von Rusty ins Schiff, das Schiff wippt, ein großer goldener Betrag springt über dem Schiff auf, Münzklang. Die Bolts oben links zählen hoch und hüpfen. Bots und Drohnen zeigen nur eine kleine Zahl (kein Klang)
- **Meilensteine** (6 Zähler mit 3 bis 4 Stufen): Teile gesammelt (100, 1.000, 5.000, 20.000), Bodenkacheln geputzt, Abgaben am Schiff, Bolts verdient, Müll zerlegt, Upgrades gekauft. Jede Stufe zeigt ein Pokal-Schild mit Zahl und Belohnung (Bolts und XP), dazu Konfetti und ein kleines Arpeggio. Liste mit Sternen und Fortschritt im Tab „Kapitel“. Zahlen in `data/milestones.json`
- **Sieben neue kurze Aufgaben** zwischen den großen (26 statt 19): 30 Kacheln putzen, dreimal abliefern, erstes Tempo-Upgrade, 300 Kacheln putzen, Saugtempo 2, Ertrag 3, 2.000 Kacheln putzen
- **Erste Soundeffekte**, im Spiel selbst erzeugt (keine fremden Dateien, keine Lizenzfragen): Münzen beim Abliefern, Glocke bei erledigter Aufgabe, Arpeggio beim Meilenstein, Fanfare bei der Reparatur, Plopp beim Kaufen, Grollen beim Abflug. Eigener Lautstärkekanal; der Regler kommt in MS25

### Behoben
- **Tab „Kapitel“ und Journal ließen sich mit dem D-Pad nicht scrollen:** Die Liste wurde jede halbe Sekunde neu gebaut, dabei ging der Fokus verloren. Jetzt wird nur bei Änderungen neu gebaut und der Fokus bleibt

### Technik
- `MilestoneState` (Sim, prüft alle 20 Ticks), Spielstand-Schlüssel `milestones`; alte Stände bekommen Erreichtes still nachgetragen. Aufgaben werden jetzt über ihre ID gespeichert, neue Aufgaben verschieben alte Stände nicht
- `ship_delivered` meldet, ob Rusty geliefert hat. `Sfx`-Autoload, `Fmt.int_str` für Tausenderpunkte
- 175 Unit-Tests (8 neue für Meilensteine und Aufgaben), 31 Gamepad-Prüfungen und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Taschen füllen, am Schiff A: Teile fliegen ins Schiff, goldene Zahl, Münzklang, Bolts zählen hoch
2. Ton: Sind die Effekte zu laut, zu leise, zu piepsig? (Lautstärke-Regler folgt in MS25)
3. Nach 5 zerlegten Müllteilen: Pokal-Schild „5 Müllteile zerlegt · +25 Bolts“
4. Select, Tab „Kapitel“, mit dem D-Pad bis ganz nach unten: Meilensteine mit Sternen
5. Kommen die Aufgaben jetzt oft genug? Gibt es Stellen, wo lange nichts passiert?

## [1.11.0] – 2026-10-26 – MS22 Schiff als Herz (Kurswechsel Block 4)

Jede Reparatur ist jetzt ein Ereignis, und am Ende hebt das Schiff wirklich ab.

### Neu
- **Fünf Schiffsbilder:** Wrack (schief, verbeult, raucht), notdürftig geflickt (Flicken, Klebeband), Funk geht wieder (Antenne, Blinklichter), glänzend (Solarflügel, Schüssel), startklar (Landebeine, glühende Düsen, Fähnchen)
- **Das Schiff heilt seine Umgebung:** Nach jeder Reparatur läuft eine Putzwelle vom Schiff aus (Radius 4, 7, 10, 13, 16 Kacheln). Dort wächst danach Gras. Zählt zur Sauberkeit der Zone
- **Jubel bei jeder Reparatur:** Das Menü schließt sich, die Kamera schaut zum Schiff, Konfetti, das Schiff hüpft und blitzt, ein Ring läuft über den Boden, und ein großes Schild zeigt „Schiff repariert! Stufe 3 · Funkt wieder · Neu: Drohne · Deko“
- **Stufenleiste im Schiff-Menü:** Oben das Schiff in der aktuellen Stufe und alle fünf Stufen mit Namen und Geschenken. Ein Balken zeigt die Bolts bis zur nächsten Reparatur (oder wie weit der Planet für den Abflug noch fehlt)
- **Abflug als Endszene:** Nach der letzten Reparatur rüttelt das Schiff, die Düsen zünden, Staub wirbelt, das Schiff steigt aus dem Bild, die Kamera folgt, Weißblende, dann der Endbildschirm. Mit „Weiterspielen“ steht das Schiff wieder da und es geht weiter

### Technik
- `ShipSystem._tick_clean_wave` (Sim, Radius in `data/ship.json` je Stufe), `Ship.clean_radius` im Spielstand (Version bleibt 8)
- `ShipFx` (Rauch, Lichter, Düsen, Feier, Abflug), `StageBanner` im HUD, `StageTrack` im Schiff-Tab
- 167 Unit-Tests, 31 Gamepad-Prüfungen (jetzt: Menü schließt nach der Reparatur, X öffnet es wieder) und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Neues Spiel: Das Wrack steht schief und raucht
2. 500 Bolts sammeln, X am Schiff, oberste Karte „Schiff reparieren“: Menü geht zu, Konfetti, großes Schild, Boden rund ums Schiff wird sauber, Gras wächst
3. X erneut: Oben im Menü die Stufenleiste mit Haken bei 1, Stufe 2 orange, Balken zur nächsten Reparatur
4. Gefühl: Ist die Feier zu lang, zu kurz, zu laut für die Augen?
5. Wer es bis Stufe 5 schafft: Abflug anschauen, dann „Weiterspielen“. Das Schiff steht wieder und Rusty kann weiterfahren

## [1.10.0] – 2026-10-26 – MS21 Sichtbar sauber (Kurswechsel Block 3)

Der Planet sieht jetzt so dreckig aus, wie er ist, und man sieht jede geputzte Stelle.

### Neu
- **Schmutz je Kachel:** Der Boden ist fleckig verdreckt (graubraun, Ölpfützen, Kleinmüll), unter und um jeden Müll voll verschmutzt. Rund ums Schiff ist es zu Beginn sauber, damit man sieht, wo das Aufräumen anfängt
- **Saugen putzt den Boden:** Der Saugkegel nimmt Schmutz von den Kacheln vor Rusty mit. Etwa jede 5. sauber geputzte Kachel bringt ein Stück Kleinschrott. Sammel-Bots putzen in ihrer Nähe mit
- **Zerlegter Müll** hinterlässt sauberen Boden (die Kachel und ihre Nachbarn). Kommt Müll zurück, wird die Stelle wieder dreckig
- **Gras wächst nach:** Wo es sauber ist, sprießen nach 1 bis 5 Sekunden Gras und Blumen, Kachel für Kachel. Büsche und Teiche kommen weiter mit den Zonen-Stufen
- **Sauberkeit = geputzte Fläche:** Der Prozentwert einer Zone, der Planet-Balken und die Tore richten sich jetzt nach dem Anteil sauberer Kacheln
- Minimap und Karte zeigen den Schmutz; Zonennamen auf der Karte stehen auf einem hellen Schild

### Technik
- `DirtMap` (Sim, deterministisch aus Karten-Seed und Müll-Positionen), Einstellungen in `data/dirt.json`; `DirtView` zeichnet eine weiche Maske mit Shader, höchstens 15 Aktualisierungen pro Sekunde
- Spielstand speichert den Schmutz komprimiert (Version bleibt 8; Stände ohne Schmutz bekommen ihn beim Laden neu erzeugt)
- 165 Unit-Tests (10 neue für Schmutz), 29 Gamepad-Prüfungen und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Neues Spiel: Boden ist dreckig, ums Schiff herum sauber
2. RT halten und herumfahren: Hinter Rusty bleibt eine saubere Spur, kurz danach wächst Gras. Ab und zu fliegt ein Schrottteil in die Taschen
3. Einen Toaster zerhämmern: Die Stelle darunter wird sauber
4. Planet-Balken und Zonen-Prozent steigen beim Putzen
5. Läuft es flüssig (60 FPS) auch beim langen Saugen über große Flächen?
6. Speichern und Beenden, Weiterspielen: Die geputzten Stellen sind noch sauber

## [1.9.0] – 2026-10-26 – MS20 Neuer Kern-Ablauf: sammeln, abliefern, aufrüsten (Kurswechsel Block 2)

Weniger Fabrik, mehr Incremental. Alte Spielstände passen nicht mehr: Beim Start werden sie gesichert (`save_a.json.bak_…`) und ein neues Spiel beginnt.

### Neu
- **Grundschleife:** Rusty startet mit 4 Inventarplätzen à 10 Teile. Volle Taschen bringt er zum Schiff, **A am Schiff liefert alles auf einmal ab** und zahlt sofort Bolts (Schrott 1, Holz, Stein, Plastik 2, Kupfer 3, Chrom 8, Titan 12, Sternenstaub 20). Die erste volle Ladung reicht für das erste Upgrade
- **Schiff-Menü** (X am Schiff, oder Select): Reparatur und fünf Upgrades, alles nur gegen Bolts. Laderaum +1 Platz (8 Stufen, ab 25 Bolts), Ertrag +10 % (10 Stufen, ab 60), Fahrtempo +8 % (8 Stufen, ab 40), Saugtempo +12 % und etwas Reichweite (8 Stufen, ab 50), Werkzeugstufe für härteren Müll (300, 1.500, 6.000, 20.000). Zahlen in `data/ship.json`
- **Schiffsreparatur mit Blaupausen:** Stufe 2 (500 Bolts) Sammel-Bot, Stufe 3 (3.000) Drohne und Deko, Stufe 4 (12.000) bessere Bots und Museum, Stufe 5 (40.000, Planet ab 80 % geheilt) hebt das Schiff ab und zeigt das Ende mit neuem Text ohne Entwicklersprache
- **Sammel-Bots** (die bisherigen Helfer) werden am Schiff gebaut, arbeiten dort, wo Rusty beim Bau steht (Radius 8 Kacheln), und liefern ans Schiff. 150 Bolts, jeder weitere ×1,5, höchstens 10
- **Drohnen** fliegen jetzt selbstständig: vom Schiff zu losen Teilen (Vorrang, z. B. Beute aus zerhämmertem Müll) oder Rohstoffhaufen in freigeschalteten Zonen, tragen 6 Teile, liefern am Schiff ab. 400 Bolts, ×1,5, höchstens 6. Kein Quelle-Ziel-Einstellen mehr
- **Neue Aufgabenkette** (19 Aufgaben): fahren, sammeln, abliefern, erstes Upgrade, Toaster zerlegen, Laderaum 2, 300 Bolts, Werkzeug 2, Tor öffnen, Schiff 2, erster Bot, 2.000 Bolts, Schiff 3, erste Drohne, 3 Fundstücke, 3 Bots, Schiff 4, Planet 80 %, Abflug
- Der Titel erklärt, wenn ein alter Spielstand gesichert wurde. Spielstand-Version 8

### Entfernt (Code bleibt in der Git-Historie)
- Förderbänder, Saugstation, Schmelzofen, Presse, Verkaufsterminal, Kiste, alle Rezepte und Produkte (Barren, Platten, Zahnräder, Schaltkreise)
- Forschungsbaum: Freischaltungen kommen über Schiffsstufen. Tab „Forschung“ ist durch „Schiff“ ersetzt
- Skills, die ins Schiff umgezogen sind (Taschen, Schnelle Räder, Feilschen, Schlagkraft, Saugkraft) und Großhändler. Es bleiben Turbo, Wendigkeit, Stapler, Magnet, Kenner, Tempo, Reichweite
- Das Baumenü zeigt nur noch Deko und Museum und meldet sich vorher mit einem Spruch, statt leer aufzugehen

### Behoben
- **Doppelte Käufe mit A:** Seit v1.5.0 löste A in Menüs den fokussierten Knopf zweimal aus (der Knopf selbst plus meine Absicherung). Bei Käufen hätte das doppelt bezahlt. Gefunden im erweiterten Gamepad-Test; die Absicherung greift jetzt nur noch für die Tastatur

### Technik
- `ShipSystem` (Abliefern, Upgrades, Stufen), `Drone` als Sammler, `ResearchSystem` ohne Forschung, `BuildingSystem` ohne Fabrik; `ConveyorSystem`, `Conveyor`, `Extractor`, `Machine`, `SellTerminal`, `Chest`, `RecipeDef` entfernt
- Tests neu: Schiff (12), Bots (11), Drohnen (9), Aufgaben (5), Skills (6), Spielstand (6), Gebäude (4); `tests/worlds.gd` als gemeinsame Test-Welt; `tools/compile_all.gd` prüft, dass jedes Skript kompiliert
- 155 Unit-Tests, 29 Gamepad-Prüfungen (jetzt mit Abliefern per A, Schiff-Menü per X, Kauf von Reparatur, Upgrade, Bot und Drohne) und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Start: Der Titel sagt, dass der alte Spielstand gesichert wurde. Neues Spiel startet
2. Schrott saugen, bis die 4 Plätze voll sind (40 Teile), zum Schiff fahren, A: Taschen leer, Bolts steigen
3. X am Schiff: Schiff-Menü. Laderaum kaufen (25 Bolts), danach hat die Hotbar 5 Plätze. Jeder Kauf darf nur einmal abbuchen
4. Nach 500 Bolts: „Schiff reparieren“, dann „Sammel-Bot bauen“. Der Bot sammelt neben dir und bringt alles zum Schiff
5. Tempo-Gefühl: Wie lange bis zum ersten Upgrade, bis Schiffsstufe 2? Bitte grob die Minuten notieren

## [1.8.0] – 2026-10-26 – MS19 Weiterspielen absichern (Kurswechsel Block 1)

### Behoben
- **Menüs nach einem Szenenwechsel:** Wenn A am Titel „Weiterspielen“, „Neues Spiel“ oder „Sprache“ auslöste, griff der Titel danach noch auf seinen bereits entfernten Bildschirm zu (Skriptfehler). Jetzt wird die Eingabe vor dem Auslösen als erledigt markiert; das gilt für alle Menüs
- Den Absturz vom Ally konnte ich hier nicht nachstellen: fünf gespielte Partien laden fehlerfrei, auch mit einer Debug-EXE. Die Ally-Logs enthielten keinen Fehler, weil das Log bisher gepuffert geschrieben wurde. Für die genaue Ursache brauche ich die Spielstand-Dateien vom Ally

### Hinzugefügt
- **Lade-Protokoll:** Jeder Ladeschritt steht mit Zeitstempel im Log (`[Laden … ms] …`), und das Log wird jetzt sofort geschrieben. Stürzt das Spiel beim Laden ab, zeigt die letzte Zeile im Log, wo
- **Ladeschutz mit Rettung:** Während des Ladens liegt eine Schutzdatei im Spielstand-Ordner; sie verschwindet erst nach 3 s fehlerfreiem Spiel. War das letzte Laden nicht fertig, bietet der Titel „Vorherigen Spielstand laden“ (falls ein zweiter, lesbarer Stand existiert) oder „Neu beginnen (alter Stand wird gesichert)“ an. Der alte Stand wird umbenannt (`save_a.json.bak_…`), nicht gelöscht. So endet kein Start mehr in einer Absturzschleife
- **Entwickler-Tasten F3 bis F7 nur in Debug-Builds:** In der Release-EXE sind sie ohne Belegung
- `tests/continue_check.sh`: drei echte Programmstarts. 1) Neues Spiel, spielen, Start, D-Pad zu „Speichern und Beenden“, A. 2) Titel, A auf „Weiterspielen“, Zustand vergleichen, weiterspielen, Ladeschutz verschwindet. 3) Abgestürztes Laden simulieren, Rettung wählen, alter Stand gesichert. Schützt den echten Spielstand
- Unit-Test: Entwickler-Tasten in Release ohne Belegung; 213 Tests, 31 Gamepad-Prüfungen und 16 Weiterspielen-Prüfungen grün

### Ally-Testliste
1. Spielen, Start, „Speichern und Beenden“. Spiel neu starten, A auf „Weiterspielen“: Spiel lädt
2. Stürzt es trotzdem ab: Spiel nochmal starten. Der Titel zeigt einen roten Hinweis und die Rettung. Bitte vorher `%APPDATA%\Godot\app_userdata\Scrap Empire\saves\` und `...\logs\godot.log` kopieren und mir schicken; die letzte Zeile `[Laden …]` zeigt die Absturzstelle
3. F3 bis F7 tun in dieser EXE nichts

## [1.7.0] – 2026-10-25 – MS18a Raumschiff-Basis, Heilungsbalken, Aufgabenkette (Überarbeitung Block 2, Teil 1)

### Hinzugefügt
- **Rustys abgestürztes Raumschiff** als zentrale Basis neben dem Start (3×3, nicht abreißbar). Es nimmt Items von Hand (A), per Förderband und per Drohne ins Lager und **verkauft von allein alles über der Reserve je Item** (`data/ship.json`: Schrott 0, Kupfer und Plastik 20, Holz und Stein 40, Produkte 30 bis 50). Das Lager zählt bei allen Bau-, Forschungs-, Helfer- und Drohnenkosten mit; bezahlt wird zuerst aus Rustys Inventar, dann aus dem Schiff. Drohnen nutzen das Schiff als Quelle und Ziel, Helfer als Lager
- **Drei Ausbaustufen** mit eigener Optik (Wrack mit Rauch → notdürftig repariert mit Antenne → startklar mit Solarflügeln und Lichtern): X am Schiff baut aus, wenn Bolts und Material reichen (Stufe 2: 300 Bolts, 20 Eisenbarren, 5 Kupferbarren; Stufe 3: 2000 Bolts, 20 Zahnräder, 10 Schaltkreise, 20 Chrom). Jede Stufe vergrößert das Lager (20 → 30 → 40 Slots à 50) und verkauft schneller. Die Hinweiszeile am Schiff zeigt Stufe, Lager, Kosten und was fehlt
- **Planeten-Heilungsbalken** dauerhaft im HUD unter den Bolts: Anteil des weggeräumten Mülls über alle Zonen
- **Geführte Aufgabenkette** (`data/quests.json`, 24 Aufgaben) ersetzt Tutorial und Fließtext-Tipps: immer genau eine Aufgabe mit Kästchen oben im HUD, mit Zähler („(12/30)“), Haken-Moment mit Konfetti und Spruch, XP und teils Bolts als Belohnung. Die Kette führt vom ersten Schritt über Ofen, Barren, Band zum Schiff, Saugstation, Schiffsausbau, Tor, Presse, Autopilot, Helfer, Drohnen, Fundstücke bis zum geheilten Planeten. Tab „Kapitel“ zeigt erledigte, aktuelle und kommende Aufgaben
- **Außenposten:** Verkaufsterminals kosten fest 40 Schrott + 5 Eisenbarren (keine Steigerung) und sind auf eines je Zone begrenzt
- Alte Spielstände bekommen das Schiff automatisch neben dem Start; erledigte Aufgaben werden still übersprungen (Tutorial-Aufgaben gelten als erledigt, wenn das alte Tutorial fertig war). Spielstand-Version 7, Migration 6 → 7
- Tests: `tests/test_ship.gd` (12) und `tests/test_quests.gd` (6); 212 Tests grün, 31 Gamepad-Prüfungen grün

### Entfernt
- Tutorial-System (`tutorial.gd`, `tutorial.json`) und Kapitel-Tipps (`chapters.json`)

### Ally-Testliste
1. Neues Spiel: Schiffswrack links neben Rusty, oben „☐ Bewege dich mit dem linken Stick (0/200)“, links „Planet 0 %“
2. 30 Schrott saugen, zum Schiff fahren, A: Schrott landet im Schiff und wird in den nächsten Sekunden verkauft (Bolts steigen)
3. Am Schiff: Hinweiszeile unten zeigt Stufe 1 und die Ausbaukosten; X ohne Material gibt einen Spruch
4. Select → Kapitel: Aufgabenliste mit Haken; Forschung Schmelzofen kostet Bolts, Material darf im Schiffslager liegen
5. Alter Spielstand (Weiterspielen): Schiff steht neben dem Start, keine Aufgabe des alten Tutorials wird erneut verlangt

## [1.6.0] – 2026-10-25 – MS17 Sim-Aufteilung (Überarbeitung Block 7)

Reiner Umbau ohne Verhaltensänderung; Vorbereitung für die Raumschiff-Basis (MS18a).

### Geändert
- `src/sim/world.gd` von 1.259 auf 388 Zeilen. Die Logik liegt jetzt in acht Teilsystemen unter `src/sim/systems/`: Forschung (`ResearchSystem`: Tech, Skills, Modifikatoren, Rezepte, Verkaufswert), Objekte (`NodeSystem`: Haufen, Wracks, lose Items, Respawn), Bauen (`BuildingSystem`), Förderbänder (`ConveyorSystem`), Werkzeuge (`ToolSystem`: Saugen, Hämmern, Magnet, Helfer-Arbeit), Helfer (`HelperSystem`), Drohnen (`DroneSystem`), Fundstücke (`CollectibleSystem`)
- Teilsysteme sind statische Funktionen mit der Welt als erstem Parameter: keine Referenzzyklen, kein Zustand außerhalb von `SimWorld`. `SimWorld` behält Daten, Signale, Tick-Reihenfolge und Befehlsverteilung und leitet 36 öffentliche Funktionen weiter, damit Tests, Ansichten und Spielstand unverändert bleiben
- Alle 194 Tests und die 31 Gamepad-Prüfungen laufen unverändert; Spielstand-Format unverändert (Version 6)

## [1.5.0] – 2026-10-25 – MS16 Ally-Bugs (Überarbeitung Block 1)

Erste Runde der Überarbeitung nach dem Praxistest auf dem ROG Ally X. Keine neuen Systeme.

### Behoben
- **A bestätigt in allen Menüs:** Jedes Menü (Baumenü, Fortschritt mit Helfer- und Drohnen-Tab, Aufgaben-Editor, Pause, Endbildschirm, Titel) löst den fokussierten Knopf zusätzlich über die eigene A-Aktion aus, falls Godots Menü-Bestätigung den Druck nicht verarbeitet. A und B sind außerdem fest auf Godots `ui_accept` und `ui_cancel` gebunden, D-Pad auf `ui_up` bis `ui_right`. B geht in jedem Menü zurück
- **Dauersaugen:** RT und LT haben jetzt eine eigene Schwelle von 0,5 (Sticks bleiben bei 0,2). Der Ally X liefert in Ruhe Werte über 0,2. Zusätzlich setzt der Sauger `suck_held` zurück, sobald der Autopilot endet, egal auf welchem Weg; `TaskList.stop()` gibt den Körper frei
- **Baumenü bei zu wenig Material:** rote Einträge zeigen „(fehlt: 5 Eisenbarren, 3 Kupfer)“, darüber steht der Hinweis, dass nur Rustys Inventar zählt (nicht Kisten)

### Hinzugefügt
- `tests/gamepad_check.sh`: spielt mit simulierten Joypad-Ereignissen (A, B, Y kurz und lang, Start, Select, RB, RT) 31 Schritte durch alle Menüs und prüft den Zustand; schützt den echten Spielstand wie `shot.sh`
- Unit-Tests: Trigger-Schwelle 0,3 nicht gedrückt, 0,6 gedrückt; A ist `ui_accept`, B ist `ui_cancel`; Stopp des Autopiloten gibt den Sauger frei
- `src/ui/menu_input.gd` als gemeinsame Gamepad-Logik der Menüs

### Hinweis für den Ally X
Wenn das Spiel die Tastatur-Hinweise (WASD, E, Tab) statt der Gamepad-Hinweise (Stick, A, Y) zeigt, steht der Controller in Armoury Crate im Desktop-Modus. Dann auf Gamepad-Modus stellen, sonst sendet A Mausklicks statt Tastendrücke.

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
