class_name ShipSystem
extends RefCounted
## Raumschiff: Abliefern (sofort Bolts), Upgrades für Rusty, Reparaturstufen mit Blaupausen.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt. Zahlen kommen aus data/ship.json.


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


# --- Abliefern ---------------------------------------------------------------

## Legt Rustys ganzes Inventar ins Schiff (A am Schiff).
static func _cmd_deliver_all(w: SimWorld, _cmd: Dictionary) -> void:
	var s := ship(w)
	if s == null:
		return
	var moved := 0
	for slot: Dictionary in w.player.inventory.slots.duplicate(true):
		if slot["item"] == "":
			continue
		var n := s.accept_stack(str(slot["item"]), int(slot["count"]))
		w.player.inventory.remove(str(slot["item"]), n)
		moved += n
	if moved == 0:
		w.ship_failed.emit("empty")


## Wandelt die Abgabe eines Ticks in Bolts um (Wert × Ertrag × Kenner-Bonus).
static func credit(w: SimWorld, s: Ship) -> void:
	var p := s.take_pending()
	var total := 0
	for item in p:
		var n := int(p[item])
		var value := int(round(float(w.item_values.get(item, 0)) * n * float(w.mods["sell_mult"]) * (float(w.mods["rare_mult"]) if w.rare_items.has(item) else 1.0)))
		total += value
		w.ship_received.emit(str(item), n)
		w.item_sold.emit(str(item), value, s.center_px())
	if total <= 0:
		return
	w.bolts += total
	w.progression.on_sale(total)
	w.bolts_changed.emit(w.bolts)
	w.ship_delivered.emit(p, total)


# --- Upgrades ------------------------------------------------------------------

static func upgrade_defs(w: SimWorld) -> Array:
	return w.ship_cfg.get("upgrades", [])


static func upgrade_def(w: SimWorld, id: String) -> Dictionary:
	for u: Dictionary in upgrade_defs(w):
		if str(u["id"]) == id:
			return u
	return {}


static func upgrade_level(w: SimWorld, id: String) -> int:
	return int(w.ship_upgrades.get(id, 0))


## Kosten der nächsten Stufe oder -1 bei Maximum.
static func upgrade_cost(w: SimWorld, id: String) -> int:
	var u := upgrade_def(w, id)
	var level := upgrade_level(w, id)
	if u.is_empty() or level >= int(u.get("max_level", 1)):
		return -1
	return int(u["cost_bolts"][level])


## "" wenn kaufbar, sonst: unknown, max, bolts
static func can_buy_upgrade(w: SimWorld, id: String) -> String:
	var u := upgrade_def(w, id)
	if u.is_empty():
		return "unknown"
	var cost := upgrade_cost(w, id)
	if cost < 0:
		return "max"
	if w.bolts < cost:
		return "bolts"
	return ""


static func _cmd_buy_upgrade(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := can_buy_upgrade(w, id)
	if reason != "":
		w.ship_failed.emit("upgrade_" + reason)
		return
	w.bolts -= upgrade_cost(w, id)
	w.ship_upgrades[id] = upgrade_level(w, id) + 1
	w.bolts_changed.emit(w.bolts)
	w.recompute_modifiers()
	w.ship_upgrade_bought.emit(id, upgrade_level(w, id))


static func upgrades_total(w: SimWorld) -> int:
	var n := 0
	for k in w.ship_upgrades:
		n += int(w.ship_upgrades[k])
	return n


# --- Reparaturstufen -------------------------------------------------------------

static func stage_def(w: SimWorld, stage: int) -> Dictionary:
	for s: Dictionary in w.ship_cfg.get("stages", []):
		if int(s.get("stage", 0)) == stage:
			return s
	return {}


static func max_stage(w: SimWorld) -> int:
	return w.ship_cfg.get("stages", []).size()


## Aussehen setzen und alle Blaupausen bis zur aktuellen Stufe freischalten.
static func apply_stage(w: SimWorld, s: Ship) -> void:
	var d := stage_def(w, s.stage)
	s.sprite_path = str(d.get("sprite", s.def.sprite))
	for st in range(1, s.stage + 1):
		for f in stage_def(w, st).get("unlocks", []):
			w.unlocked_features[str(f)] = true


## Kosten der nächsten Stufe (Bolts) oder -1 bei Maximum.
static func next_stage_cost(w: SimWorld, s: Ship) -> int:
	if s == null or s.stage >= max_stage(w):
		return -1
	return int(stage_def(w, s.stage + 1).get("cost_bolts", 0))


## Was die nächste Stufe freischaltet.
static func next_stage_unlocks(w: SimWorld, s: Ship) -> Array:
	if s == null or s.stage >= max_stage(w):
		return []
	return stage_def(w, s.stage + 1).get("unlocks", [])


## "" wenn reparierbar, sonst: no_ship, max, bolts, planet
static func can_upgrade(w: SimWorld, s: Ship) -> String:
	if s == null:
		return "no_ship"
	if s.stage >= max_stage(w):
		return "max"
	var d := stage_def(w, s.stage + 1)
	if w.bolts < int(d.get("cost_bolts", 0)):
		return "bolts"
	if w.zones.planet_health(w.nodes) < float(d.get("requires_planet", 0.0)):
		return "planet"
	return ""


static func _cmd_upgrade_ship(w: SimWorld, _cmd: Dictionary) -> void:
	var s := ship(w)
	var reason := can_upgrade(w, s)
	if reason != "":
		w.ship_failed.emit(reason)
		return
	w.bolts -= next_stage_cost(w, s)
	w.bolts_changed.emit(w.bolts)
	s.stage += 1
	apply_stage(w, s)
	w.progression.add_xp(50 * s.stage)
	if s.stage >= max_stage(w):
		w.flags["launched"] = true
	w.building_changed.emit(s)
	w.ship_upgraded.emit(s)


# --- Kosten für Deko (Material aus Rustys Inventar) ---------------------------------

static func count_available(w: SimWorld, item: String) -> int:
	return w.player.inventory.count_of(item)


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


static func pay(w: SimWorld, cost: Dictionary) -> void:
	for item in cost:
		w.player.inventory.remove(str(item), int(cost[item]))
