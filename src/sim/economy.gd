class_name Economy
extends RefCounted
## Kostenformel und Bezahlung (GDD 7.2): kosten(n) = basis × growth^(n-1), auf 5 gerundet.


static func cost_for(def: BuildingDef, existing_count: int) -> Dictionary:
	var result: Dictionary = {}
	for item in def.cost:
		var raw: float = float(def.cost[item]) * pow(def.cost_growth, existing_count)
		var rounded := int(round(raw / 5.0)) * 5
		result[item] = maxi(rounded, 1)
	return result


static func can_afford(inv: Inventory, cost: Dictionary) -> bool:
	for item in cost:
		if inv.count_of(item) < int(cost[item]):
			return false
	return true


static func pay(inv: Inventory, cost: Dictionary) -> void:
	for item in cost:
		inv.remove(item, int(cost[item]))


## Erstattet ins Inventar; liefert, was nicht mehr hineinpasste (item → Menge).
static func refund(inv: Inventory, cost: Dictionary) -> Dictionary:
	var rest: Dictionary = {}
	for item in cost:
		var left := inv.add(item, int(cost[item]))
		if left > 0:
			rest[item] = left
	return rest


## Verkaufswerte aus items.json: item_id → Bolts.
static func load_item_values(path: String) -> Dictionary:
	var result: Dictionary = {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("items.json nicht lesbar: " + path)
		return result
	for entry: Dictionary in parsed.get("items", []):
		result[str(entry["id"])] = int(entry.get("sell_value", 0))
	return result
