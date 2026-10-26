class_name Ship
extends Building
## Rustys abgestürztes Raumschiff: das Herz des Spiels. Alles, was abgeliefert wird (Rusty, Bots,
## Drohnen), landet in `pending` und wird im selben Tick von ShipSystem.credit in Bolts umgewandelt.
## Stufen (ShipSystem) ändern Aussehen und schalten Blaupausen frei.

var stage := 1
var sprite_path := ""
var pending: Dictionary = {}   # item → Menge, abgeliefert seit dem letzten Tick
var pending_by_player := false  # die aktuelle Abgabe kam von Rusty (für Effekte)
var clean_radius := 0          # so weit hat die Putzwelle des Schiffs den Boden schon gesäubert (Kacheln)


## Nimmt alles an (das Schiff ist nie voll).
func accept_stack(item_id: String, count: int) -> int:
	if count <= 0 or item_id == "":
		return 0
	pending[item_id] = int(pending.get(item_id, 0)) + count
	return count


func take_pending() -> Dictionary:
	var p := pending
	pending = {}
	return p


## true, wenn etwas zum Gutschreiben bereitliegt.
func tick() -> bool:
	return not pending.is_empty()


func summary() -> Dictionary:
	return {"stage": stage}
