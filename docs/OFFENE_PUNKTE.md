# Offene Punkte nach Phase 2 (Stand v2.0.0, 2026-10-28)

## Balancing (statt MS39-Simulation)
- Die Simulation bis zum Abflug wurde auf Wunsch weggelassen (zu teuer). Die Zahlen stehen alle in JSON (`data/ship.json`, `skills.json`, `helpers.json`, `drones.json`, `scrap_objects.json`, `quests.json`, Karte über `tools/gen_main_map.py`).
- Überschlag aus dem Wirtschaftstest: Kartenwert ca. 44 700 Bolts, mit Ertrag-Upgrades ca. 64 800 verdienbar, Pflicht-Ausgaben (Schiffsstufen + Ertrag) ca. 35 100. Es reicht also bis zum Abflug, auch mit Bots, Drohnen und Sammelstellen.
- Ob 3–4 Stunden und „alle 2–3 Minuten etwas Neues“ stimmen, zeigt erst der Ally-Durchlauf. Bitte Zeiten notieren (siehe Testliste im CHANGELOG 2.0.0); daraus passe ich die Zahlen gezielt an.

## Inhalt und Texte
- Abspann „Idee und Auftrag“ nennt nur „PH“, „Programmierung und Grafik“ nennt „Claude (Anthropic)“. Anpassbar in `data/credits.json`.
- Abspann lässt sich nach dem Abflug nicht erneut ansehen (z. B. über das Pausenmenü).
- Alte, ungenutzte Texte aus der Fabrik-/Techbaum-Zeit (TECH_*, UNLOCK_*) liegen noch in `locale/strings.csv`; harmlos.
- GDD-Kapitel 9 (Autopilot) ist nur noch historisch markiert, nicht umgeschrieben.

## Für Steam (nicht Teil von Phase 2)
- Lizenztexte (Godot MIT, Kenney/Musik CC0) als Datei neben die EXE legen.
- Steam-Seite, Kapsel-Grafiken, Steamworks (Erfolge, Cloud-Speicher) fehlen.
- Weitere Sprachen außer Deutsch/Englisch: keine.
- Test auf anderen Auflösungen als 1920 × 1080 nur grob.
