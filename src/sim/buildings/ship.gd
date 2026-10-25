class_name Ship
extends Building
## Rustys abgestürztes Raumschiff: zentrale Basis. Nimmt Items von Hand, Band und Drohne ins Lager,
## verkauft automatisch alles über der Reserve je Item (ein Item je sell_interval Ticks) und hat
## Ausbaustufen (ShipSystem). Lager zählt bei Bau- und Forschungskosten mit.

var stage := 1
var storage := Inventory.new(20, 50)
var reserve: Dictionary = {}     # item → behält bis zu dieser Menge
var sell_interval := 10
var sprite_path := ""
var _cooldown := 0
var _sold := ""


func accept_stack(item_id: String, count: int) -> int:
	var rest := storage.add(item_id, count)
	return count - rest


func accept_from_belt(item_id: String) -> bool:
	return storage.add(item_id, 1) == 0


func withdraw_stack() -> Dictionary:
	for s in storage.slots:
		if s["item"] != "":
			var item: String = s["item"]
			var count: int = s["count"]
			storage.remove(item, count)
			return {"item": item, "count": count}
	return {}


## Verkauft je Takt ein Item, das über der Reserve liegt.
func tick() -> bool:
	if _cooldown > 0:
		_cooldown -= 1
		if _cooldown > 0:
			return false
	var item := _sellable_item()
	if item == "":
		return false
	storage.remove(item, 1)
	_sold = item
	_cooldown = sell_interval
	return true


func _sellable_item() -> String:
	for s in storage.slots:
		var item: String = s["item"]
		if item == "":
			continue
		if storage.count_of(item) > int(reserve.get(item, 0)):
			return item
	return ""


func take_sold() -> String:
	var s := _sold
	_sold = ""
	return s


func get_cooldown() -> int:
	return _cooldown


func set_cooldown(v: int) -> void:
	_cooldown = v


func contents() -> Dictionary:
	var result: Dictionary = {}
	for s in storage.slots:
		if s["item"] != "":
			result[s["item"]] = int(result.get(s["item"], 0)) + int(s["count"])
	return result


func summary() -> Dictionary:
	return {"storage": storage.total(), "storage_max": storage.slot_count * storage.stack_size, "stage": stage}
