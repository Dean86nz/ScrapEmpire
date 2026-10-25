class_name Chest
extends Building
## Kiste: 12 Slots × 20, von allen Seiten befüllbar. Puffer für Aufgabenlisten (MS7).

const SLOTS := 12
const STACK := 20

var inventory := Inventory.new(SLOTS, STACK)


func accept_stack(item_id: String, count: int) -> int:
	var rest := inventory.add(item_id, count)
	return count - rest


func withdraw_stack() -> Dictionary:
	for s in inventory.slots:
		if s["item"] != "":
			var item: String = s["item"]
			var count: int = s["count"]
			inventory.remove(item, count)
			return {"item": item, "count": count}
	return {}


func contents() -> Dictionary:
	var result: Dictionary = {}
	for s in inventory.slots:
		if s["item"] != "":
			result[s["item"]] = result.get(s["item"], 0) + s["count"]
	return result


func summary() -> Dictionary:
	return {"total": inventory.total(), "capacity": SLOTS * STACK}
