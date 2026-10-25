class_name ShipSystem
extends RefCounted
## Raumschiff-Basis: Stufen aus data/ship.json, Ausbau, Lager als Zahlungsquelle.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt.


static func load_config(path: String = "res://data/ship.json") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


## Das (erste) Schiff der Welt oder null.
static func ship(w: SimWorld) -> Ship:
	for b: Building in w.buildings.values():
		if b is Ship:
			return b
	return null


static func stage_def(w: SimWorld, stage: int) -> Dictionary:
	for s: Dictionary in w.ship_cfg.get("stages", []):
		if int(s.get("stage", 0)) == stage:
			return s
	return {}


static func max_stage(w: SimWorld) -> int:
	return w.ship_cfg.get("stages", []).size()


## Stufenwerte (Lager, Verkaufstakt, Sprite, Reserve) auf das Schiff anwenden.
static func apply_stage(w: SimWorld, s: Ship) -> void:
	var d := stage_def(w, s.stage)
	if d.is_empty():
		return
	s.storage.resize(int(d.get("storage_slots", 20)), int(d.get("stack", 50)))
	s.sell_interval = int(d.get("sell_interval", 10))
	s.sprite_path = str(d.get("sprite", s.def.sprite))
	s.reserve = {}
	for k in w.ship_cfg.get("reserve", {}):
		s.reserve[str(k)] = int(w.ship_cfg["reserve"][k])


static func upgrade_cost(w: SimWorld, s: Ship) -> Dictionary:
	return stage_def(w, s.stage).get("upgrade", {})


## "" wenn ausbaubar, sonst: no_ship, max, bolts, items
static func can_upgrade(w: SimWorld, s: Ship) -> String:
	if s == null:
		return "no_ship"
	if s.stage >= max_stage(w):
		return "max"
	var cost := upgrade_cost(w, s)
	if w.bolts < int(cost.get("bolts", 0)):
		return "bolts"
	if not can_afford(w, cost.get("items", {})):
		return "items"
	return ""


static func _cmd_upgrade_ship(w: SimWorld, _cmd: Dictionary) -> void:
	var s := ship(w)
	var reason := can_upgrade(w, s)
	if reason != "":
		w.ship_failed.emit(reason)
		return
	var cost := upgrade_cost(w, s)
	w.bolts -= int(cost.get("bolts", 0))
	pay(w, cost.get("items", {}))
	w.bolts_changed.emit(w.bolts)
	s.stage += 1
	apply_stage(w, s)
	w.progression.add_xp(50 * s.stage)
	w.building_changed.emit(s)
	w.ship_upgraded.emit(s)


# --- Lager als Zahlungsquelle ------------------------------------------------

## Verfügbare Menge: Rustys Inventar plus Schiffslager (Kisten zählen nicht).
static func count_available(w: SimWorld, item: String) -> int:
	var n := w.player.inventory.count_of(item)
	var s := ship(w)
	if s != null:
		n += s.storage.count_of(item)
	return n


static func can_afford(w: SimWorld, cost: Dictionary) -> bool:
	for item in cost:
		if count_available(w, str(item)) < int(cost[item]):
			return false
	return true


## item → fehlende Menge (nur Einträge > 0).
static func missing(w: SimWorld, cost: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in cost:
		var m := int(cost[item]) - count_available(w, str(item))
		if m > 0:
			result[str(item)] = m
	return result


## Zahlt zuerst aus dem Inventar, den Rest aus dem Schiffslager.
static func pay(w: SimWorld, cost: Dictionary) -> void:
	var s := ship(w)
	for item in cost:
		var need := int(cost[item])
		var from_inv := mini(need, w.player.inventory.count_of(str(item)))
		if from_inv > 0:
			w.player.inventory.remove(str(item), from_inv)
			need -= from_inv
		if need > 0 and s != null:
			s.storage.remove(str(item), need)
	if s != null:
		w.building_changed.emit(s)


## Inventare, die bei Kosten zählen (für TechState.can_start).
static func extra_inventories(w: SimWorld) -> Array:
	var s := ship(w)
	return [s.storage] if s != null else []
