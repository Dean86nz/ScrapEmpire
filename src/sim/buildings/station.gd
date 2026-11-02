class_name Station
extends CollectionPoint
## Bot-Station (MS78): kleine Heimat für Stations-Bots. Ihre Bots arbeiten nur im Umkreis
## (`radius_tiles`) und liefern hier ab. Steht die Station nah am Schiff, schießt sie ihre
## Ladung als Würfel selbst hinüber, sonst holt eine Drohne ab (geerbt von der Sammelstelle).

var radius_tiles := 7
var slots := 3          # so viele Bots gehören höchstens zu dieser Station


func summary() -> Dictionary:
	return {"stored": total(), "station": true}
