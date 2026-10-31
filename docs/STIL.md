# Stil-Leitfaden Scrap Empire (MS65)

Ziel: bunt, fröhlich, cartoonig (Geist von Dinkum), auf Screenshots neben Steam-Spielen wie Shelldiver oder Sludgineers nicht als Hobbyprojekt erkennbar. Wir entwickeln den eigenen Vektor-Stil weiter (Entscheidung Auftraggeber 2026-10-29), kein Fremdpaket für Spielgrafik; Menüs nutzen das Kenney UI Pack.

## Palette (12 Farben)
| Rolle | Farbe |
|---|---|
| Umriss / Tinte | `#2A2A33` |
| Rusty-Orange | `#F28C28` |
| Gold / Highlight | `#FFC83C` |
| Bot-Türkis | `#4FC3B0` |
| Super-Blau | `#5B8CFF` |
| Akzent-Rot | `#FF5A6E` |
| Wiese hell / satt | `#7BD45A` / `#4CAF3E` |
| Himmel / Glas | `#BFE8FF` |
| Stahl | `#B8C0CA` |
| Schmutz (gedeckt) | `#5C4A38` |
| Creme (Flächen, Blasen) | `#FFF8EC` |

## Formen und Linien
- Umriss 4 px (`#2A2A33`), bei sehr kleinen Teilen 3 px; nie schwarz.
- Weiche Formen, große Radien; keine spitzen Ecken außer bei Schrottkanten.
- Ein heller Glanzbogen oben links auf runden Körpern (weiß, 45 % Deckkraft).
- Schatten: ein flaches Oval unter jeder Figur (`#2A2A33`, 22 % Deckkraft), Licht von oben links.

## Kontrast dreckig / sauber
- Schmutz: gedeckt, 35 % entsättigt, 22 % dunkler (Shader in `dirt_view.gd`).
- Sauber: kräftiges Grün, Blumen, Tiere; jede Zone mit eigenem Bodenton (`data/zone_themes.json`).

## Figuren
- **Rusty:** Größe fix, nie verzerrt. Reichweite nur über den Saugwirbel, nicht über die Rüssellänge. 5 Ausbaustufen über Plakette und Anbauteile (Ketten, Hammer, Lampen, Tank).
- **Werkzeuge (MS74, ersetzen den Hammer):** 1 Pömpel (Rot), 2 Greifzange (Grün), 3 Magnetkran (Orange), 4 Schrottpresse (Blau), 5 Laser (Lila/Pink). Je eigenes Bild (`assets/sprites/tools/`), Animation, Ton und Treffer-Effekt (`ToolLook`). Bots tragen ihr Werkzeug vorne. Der Sauger bleibt unverändert.
- **Bot (seit MS73):** immer dieselbe kleine Figur (rund mit einem Auge, etwas kleiner als Rusty). Bessere Werkzeugstufe = schönere Farbe (Türkis → Grün → Blau → Lila → Gold), nie größer. Keine Fusion mehr.
- **Müll:** eindeutig Müll (Dellen, Risse, Klebeband), Farben passend zur Zone, immer mit Umriss und Schatten-Oval.

## UI
- Kenney UI Pack (CC0) über `KenneySkin`; Sprechblasen: eine Zeile, max. 25 % Breite, 22 px, leicht transparent.
