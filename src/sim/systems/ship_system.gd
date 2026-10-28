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
static func _cmd_deliver_all(w: SimWorld, cmd: Dictionary) -> void:
	# Ziel: angegebene Sammelstelle (A an der Sammelstelle) oder das Schiff
	var to: Building = w.buildings.get(int(cmd.get("to", -1)))
	if to is CollectionPoint:
		var stored := 0
		for slot: Dictionary in w.player.inventory.slots.duplicate(true):
			if slot["item"] == "":
				continue
			stored += to.accept_stack(str(slot["item"]), int(slot["count"]))
			w.player.inventory.remove(str(slot["item"]), int(slot["count"]))
		if stored == 0:
			w.ship_failed.emit("empty")
			return
		w.quests.on_delivery()
		w.building_changed.emit(to)
		w.point_stored.emit(to, stored)
		return
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
		return
	s.pending_by_player = true
	w.quests.on_delivery()


## Wandelt die Abgabe eines Ticks in Bolts um (Wert × Ertrag × Kenner-Bonus).
static func credit(w: SimWorld, s: Ship) -> void:
	var p := s.take_pending()
	var by_player := s.pending_by_player
	s.pending_by_player = false
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
	w.ship_delivered.emit(p, total, by_player)


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
	return Costs.upgrade(u, level)


## "" wenn kaufbar, sonst: unknown, locked, max, bolts
static func can_buy_upgrade(w: SimWorld, id: String) -> String:
	var u := upgrade_def(w, id)
	if u.is_empty():
		return "unknown"
	var feat := str(u.get("requires_feature", ""))
	if feat != "" and not w.unlocked_features.has(feat):
		return "locked"
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


## "" wenn reparierbar, sonst: no_ship, max, boss, bolts, planet
static func can_upgrade(w: SimWorld, s: Ship) -> String:
	if s == null:
		return "no_ship"
	if s.stage >= max_stage(w):
		return "max"
	var d := stage_def(w, s.stage + 1)
	var flag := str(d.get("requires_flag", ""))
	if flag != "" and not w.flags.has(flag):
		return "boss"
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
		w.flags["launch_tick"] = w.tick_count
	w.building_changed.emit(s)
	w.ship_upgraded.emit(s)


# --- Putzwelle -------------------------------------------------------------------

## Ziel-Radius der Putzwelle für die aktuelle Stufe.
static func clean_target(w: SimWorld, s: Ship) -> int:
	return int(stage_def(w, s.stage).get("clean_radius", 0))


## Die Putzwelle wächst alle `clean_wave_ticks` um eine Kachel, bis der Radius der Stufe erreicht ist.
## Müll-Kacheln bleiben dreckig, bis der Müll weg ist. Kein Kleinschrott (das Schiff putzt, nicht Rusty).
static func _tick_clean_wave(w: SimWorld) -> void:
	if not w.dirt.is_active():
		return
	var s := ship(w)
	if s == null or s.clean_radius >= clean_target(w, s):
		return
	if w.tick_count % maxi(int(w.ship_cfg.get("clean_wave_ticks", 3)), 1) != 0:
		return
	s.clean_radius += 1
	var r := s.clean_radius
	var c := s.tile + s.size() / 2
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var dist := Vector2(dx, dy).length()
			if dist > r + 0.5 or (r > 1 and dist <= r - 0.5):
				continue
			var t := c + Vector2i(dx, dy)
			if not w._node_tiles.has(t):
				w.dirt.clean(t, 255)
				w.dirt.heal(t)


# --- Baukosten (Bolts und Material aus Rustys Inventar) ----------------------------

static func count_available(w: SimWorld, item: String) -> int:
	return w.player.inventory.count_of(item)


static func can_afford(w: SimWorld, cost: Dictionary) -> bool:
	for item in cost:
		if str(item) == "bolts":
			if w.bolts < int(cost[item]):
				return false
			continue
		if count_available(w, str(item)) < int(cost[item]):
			return false
	return true


## item → fehlende Menge (nur Einträge > 0).
static func missing(w: SimWorld, cost: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in cost:
		var have := w.bolts if str(item) == "bolts" else count_available(w, str(item))
		var m := int(cost[item]) - have
		if m > 0:
			result[str(item)] = m
	return result


static func pay(w: SimWorld, cost: Dictionary) -> void:
	for item in cost:
		if str(item) == "bolts":
			w.bolts -= int(cost[item])
			w.bolts_changed.emit(w.bolts)
			continue
		w.player.inventory.remove(str(item), int(cost[item]))
