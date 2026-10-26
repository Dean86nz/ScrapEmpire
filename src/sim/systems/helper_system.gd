class_name HelperSystem
extends RefCounted
## Helfer-Roboter: Kauf, Upgrades, Steckenbleiben, Tick.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


static func helper_count(w: SimWorld) -> int:
	return w.helpers.size()


static func next_helper_cost(w: SimWorld) -> Dictionary:
	var n := helper_count(w)
	var base := float(w.helper_cfg.get("cost_base_bolts", 400))
	var growth := float(w.helper_cfg.get("cost_growth", 1.5))
	var bolts_cost := int(round(base * pow(growth, n) / 10.0)) * 10
	return {"bolts": bolts_cost}


## "" wenn baubar, sonst Grund: locked, max, bolts, no_ship
static func can_buy_helper(w: SimWorld) -> String:
	if not w.unlocked_features.has("helpers"):
		return "locked"
	if helper_count(w) >= int(w.helper_cfg.get("max_helpers", 10)):
		return "max"
	if w.bolts < int(next_helper_cost(w)["bolts"]):
		return "bolts"
	if ShipSystem.ship(w) == null:
		return "no_ship"
	return ""


static func _apply_helper_mods(w: SimWorld, h: Helper) -> void:
	h.apply_modifiers(w.mods, int(w.helper_cfg.get("base_speed_px_per_s", 224)), int(w.helper_cfg.get("base_slots", 3)), int(w.helper_cfg.get("base_stack", 10)))


static func _schedule_stuck(w: SimWorld, h: Helper) -> void:
	var lo := int(w.helper_cfg.get("stuck_min_s", 240)) * 20
	var hi := int(w.helper_cfg.get("stuck_max_s", 360)) * 20
	h.stuck_timer = w.rng.randi_range(lo, hi)


static func add_helper(w: SimWorld, zone_tile: Vector2i, depot_tile: Vector2i, name_index: int = -1, color_index: int = -1) -> Helper:
	var h := Helper.new()
	h.id = w.next_id()
	var n := helper_count(w)
	h.name_index = n if name_index < 0 else name_index
	h.color_index = n if color_index < 0 else color_index
	h.zone_tile = zone_tile
	h.radius_tiles = int(w.helper_cfg.get("zone_radius_tiles", 6))
	h.depot_tile = depot_tile
	var depot := w.grid.at(depot_tile)
	h.pos = depot.center_px() + Vector2i(0, 48) if depot != null else zone_tile * SimWorld.TILE
	_apply_helper_mods(w, h)
	_schedule_stuck(w, h)
	w.helpers[h.id] = h
	w.helper_added.emit(h)
	return h


## Bot bauen: arbeitet im Umkreis der Stelle, an der Rusty gerade ist (oder `zone`), liefert ans Schiff.
static func _cmd_buy_helper(w: SimWorld, cmd: Dictionary) -> void:
	var reason := can_buy_helper(w)
	if reason != "":
		w.helper_failed.emit(reason)
		return
	var zone_tile: Vector2i = cmd.get("zone", w.player_tile())
	w.bolts -= int(next_helper_cost(w)["bolts"])
	w.bolts_changed.emit(w.bolts)
	var h := add_helper(w, zone_tile, ShipSystem.ship(w).tile)
	var hired: Array = w.helper_cfg.get("quips_hired", [])
	if not hired.is_empty():
		w.helper_quip.emit(h, str(hired[h.id % hired.size()]))


static func _cmd_remove_helper(w: SimWorld, cmd: Dictionary) -> void:
	var id := int(cmd.get("id", -1))
	if not w.helpers.has(id):
		return
	var h: Helper = w.helpers[id]
	# Inhalt fällt als lose Items am Standort
	for s: Dictionary in h.inventory.slots:
		for i in int(s["count"]):
			if i < 20:
				w.add_loose(s["item"], h.pos + w._scatter())
	w.helpers.erase(id)
	w.helper_removed.emit(id)


static func helper_upgrade_def(w: SimWorld, id: String) -> Dictionary:
	for u: Dictionary in w.helper_cfg.get("upgrades", []):
		if str(u["id"]) == id:
			return u
	return {}


## "" wenn kaufbar, sonst: unknown, max, locked, bolts, chrome
static func can_buy_helper_upgrade(w: SimWorld, id: String) -> String:
	var u := helper_upgrade_def(w, id)
	if u.is_empty():
		return "unknown"
	var level := int(w.helper_upgrades.get(id, 0))
	if level >= int(u.get("max_level", 1)):
		return "max"
	var feature := str(u.get("requires_feature", ""))
	if feature != "" and not w.unlocked_features.has(feature):
		return "locked"
	if w.bolts < int(u["cost_bolts"][level]):
		return "bolts"
	return ""


static func _cmd_buy_helper_upgrade(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := can_buy_helper_upgrade(w, id)
	if reason != "":
		w.helper_failed.emit(reason)
		return
	var u := helper_upgrade_def(w, id)
	var level := int(w.helper_upgrades.get(id, 0))
	w.bolts -= int(u["cost_bolts"][level])
	w.helper_upgrades[id] = level + 1
	w.bolts_changed.emit(w.bolts)
	w.recompute_modifiers()
	w.helper_upgrade_bought.emit(id, level + 1)


static func _tick_helpers(w: SimWorld) -> void:
	for h: Helper in w.helpers.values():
		h.idle_quip_timer -= 1
		if h.idle_quip_timer <= 0:
			h.idle_quip_timer = w.rng.randi_range(60 * 20, 120 * 20)
			var idle: Array = w.helper_cfg.get("quips_idle", [])
			if not idle.is_empty():
				w.helper_quip.emit(h, str(idle[w.rng.randi_range(0, idle.size() - 1)]))
		if h.stuck_timer == 1:
			h.pause_for_stuck(int(w.helper_cfg.get("stuck_pause_s", 5)) * 20)
			var stuck: Array = w.helper_cfg.get("quips_stuck", [])
			if not stuck.is_empty():
				w.helper_quip.emit(h, str(stuck[w.rng.randi_range(0, stuck.size() - 1)]))
			_schedule_stuck(w, h)
		h.tick(w)
		w.helper_work(h)
