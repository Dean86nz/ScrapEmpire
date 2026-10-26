class_name DroneSystem
extends RefCounted
## Sammel-Drohnen: Bau am Schiff (Blaupause ab Schiffsstufe 3), Upgrades, Tick.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt. Zahlen aus data/drones.json.


static func next_drone_cost(w: SimWorld) -> Dictionary:
	var n := w.drones.size()
	var base := float(w.drone_cfg.get("cost_base_bolts", 400))
	var growth := float(w.drone_cfg.get("cost_growth", 1.5))
	return {"bolts": int(round(base * pow(growth, n) / 10.0)) * 10}


## "" wenn baubar, sonst: locked, max, bolts, no_ship
static func can_buy_drone(w: SimWorld) -> String:
	if not w.unlocked_features.has("drones"):
		return "locked"
	if w.drones.size() >= int(w.drone_cfg.get("max_drones", 6)):
		return "max"
	if w.bolts < int(next_drone_cost(w)["bolts"]):
		return "bolts"
	if ShipSystem.ship(w) == null:
		return "no_ship"
	return ""


static func _apply_drone_mods(w: SimWorld, d: Drone) -> void:
	d.apply_modifiers(w.mods, int(w.drone_cfg.get("base_speed_px_per_s", 260)), int(w.drone_cfg.get("base_capacity", 6)))
	d.collect_interval = int(w.drone_cfg.get("collect_interval_ticks", 4))
	d.search_radius_px = int(w.drone_cfg.get("search_radius_tiles", 30)) * SimWorld.TILE


static func add_drone(w: SimWorld) -> Drone:
	var d := Drone.new()
	d.id = w.next_id()
	var s := ShipSystem.ship(w)
	d.home = s.center_px() if s != null else w.player.pos
	d.pos = d.home
	_apply_drone_mods(w, d)
	w.drones[d.id] = d
	w.drone_added.emit(d)
	return d


static func _cmd_buy_drone(w: SimWorld, _cmd: Dictionary) -> void:
	var reason := can_buy_drone(w)
	if reason != "":
		w.drone_failed.emit(reason)
		return
	w.bolts -= int(next_drone_cost(w)["bolts"])
	w.bolts_changed.emit(w.bolts)
	add_drone(w)


static func _cmd_remove_drone(w: SimWorld, cmd: Dictionary) -> void:
	var id := int(cmd.get("id", -1))
	if not w.drones.has(id):
		return
	var d: Drone = w.drones[id]
	for item in d.carry:
		for i in mini(int(d.carry[item]), 20):
			w.add_loose(str(item), d.pos + w._scatter())
	w.drones.erase(id)
	w.drone_removed.emit(id)


static func drone_upgrade_def(w: SimWorld, id: String) -> Dictionary:
	for u: Dictionary in w.drone_cfg.get("upgrades", []):
		if str(u["id"]) == id:
			return u
	return {}


## "" wenn kaufbar, sonst: unknown, max, locked, bolts
static func can_buy_drone_upgrade(w: SimWorld, id: String) -> String:
	var u := drone_upgrade_def(w, id)
	if u.is_empty():
		return "unknown"
	var level := int(w.drone_upgrades.get(id, 0))
	if level >= int(u.get("max_level", 1)):
		return "max"
	if not w.unlocked_features.has(str(u.get("requires_feature", "drones"))):
		return "locked"
	if w.bolts < int(u["cost_bolts"][level]):
		return "bolts"
	return ""


static func _cmd_buy_drone_upgrade(w: SimWorld, cmd: Dictionary) -> void:
	var id := str(cmd.get("id", ""))
	var reason := can_buy_drone_upgrade(w, id)
	if reason != "":
		w.drone_failed.emit("upgrade_" + reason)
		return
	var u := drone_upgrade_def(w, id)
	var level := int(w.drone_upgrades.get(id, 0))
	w.bolts -= int(u["cost_bolts"][level])
	w.bolts_changed.emit(w.bolts)
	w.drone_upgrades[id] = level + 1
	w.recompute_modifiers()
	w.drone_upgrade_bought.emit(id, level + 1)


static func _tick_drones(w: SimWorld) -> void:
	for d: Drone in w.drones.values():
		var before := d.state
		var before_carry := d.carry_total()
		d.tick(w)
		if d.state != before or d.carry_total() != before_carry:
			w.drone_changed.emit(d)
