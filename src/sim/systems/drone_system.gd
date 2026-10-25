class_name DroneSystem
extends RefCounted
## Logistik-Drohnen: Kauf, Filter, Limit, Upgrades, Tick.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt (Daten und Signale bleiben dort).


static func next_drone_cost(w: SimWorld) -> Dictionary:
	var n := w.drones.size()
	var base := float(w.drone_cfg.get("cost_base_bolts", 600))
	var growth := float(w.drone_cfg.get("cost_growth", 1.4))
	return {"bolts": int(round(base * pow(growth, n) / 10.0)) * 10, "circuit": int(w.drone_cfg.get("cost_circuit", 3))}


static func _is_drone_source(b: Building) -> bool:
	return b is Chest or b is Machine


static func _is_drone_target(b: Building) -> bool:
	return b is Chest or b is Machine or b is SellTerminal


## "" wenn kaufbar, sonst: locked, max, bolts, circuit, no_source, no_target, same
static func can_buy_drone(w: SimWorld, source_tile: Vector2i, target_tile: Vector2i) -> String:
	if not w.unlocked_features.has("drones"):
		return "locked"
	if w.drones.size() >= int(w.drone_cfg.get("max_drones", 4)):
		return "max"
	var cost := next_drone_cost(w)
	if w.bolts < int(cost["bolts"]):
		return "bolts"
	if w.player.inventory.count_of("circuit") < int(cost["circuit"]):
		return "circuit"
	if source_tile.x < 0:
		return ""
	var src := w.grid.at(source_tile)
	if src == null or not _is_drone_source(src):
		return "no_source"
	var dst := w.grid.at(target_tile)
	if dst == null or not _is_drone_target(dst):
		return "no_target"
	if src.id == dst.id:
		return "same"
	return ""


static func _apply_drone_mods(w: SimWorld, d: Drone) -> void:
	d.apply_modifiers(w.mods, int(w.drone_cfg.get("base_speed_px_per_s", 160)), int(w.drone_cfg.get("base_capacity", 10)))


static func add_drone(w: SimWorld, source_id: int, target_id: int) -> Drone:
	var d := Drone.new()
	d.id = w.next_id()
	d.source_id = source_id
	d.target_id = target_id
	var src: Building = w.buildings.get(source_id)
	d.pos = src.center_px() if src != null else w.player.pos
	_apply_drone_mods(w, d)
	w.drones[d.id] = d
	w.drone_added.emit(d)
	return d


static func _cmd_buy_drone(w: SimWorld, cmd: Dictionary) -> void:
	var source_tile: Vector2i = cmd.get("source", Vector2i(-1, -1))
	var target_tile: Vector2i = cmd.get("target", Vector2i(-1, -1))
	var reason := can_buy_drone(w, source_tile, target_tile)
	if reason != "":
		w.drone_failed.emit(reason)
		return
	var cost := next_drone_cost(w)
	w.bolts -= int(cost["bolts"])
	w.player.inventory.remove("circuit", int(cost["circuit"]))
	w.bolts_changed.emit(w.bolts)
	add_drone(w, w.grid.at(source_tile).id, w.grid.at(target_tile).id)


static func _cmd_remove_drone(w: SimWorld, cmd: Dictionary) -> void:
	var id := int(cmd.get("id", -1))
	if not w.drones.has(id):
		return
	var d: Drone = w.drones[id]
	for i in mini(d.carry_count, 20):
		w.add_loose(d.carry_item, d.pos + w._scatter())
	w.drones.erase(id)
	w.drone_removed.emit(id)


static func _cmd_set_drone_filter(w: SimWorld, cmd: Dictionary) -> void:
	var d: Drone = w.drones.get(int(cmd.get("id", -1)))
	if d == null:
		return
	d.item_filter = str(cmd.get("item", ""))
	w.drone_changed.emit(d)


static func _cmd_set_drone_limit(w: SimWorld, cmd: Dictionary) -> void:
	var d: Drone = w.drones.get(int(cmd.get("id", -1)))
	if d == null:
		return
	d.limit = maxi(int(cmd.get("limit", 0)), 0)
	w.drone_changed.emit(d)


static func drone_upgrade_def(w: SimWorld, id: String) -> Dictionary:
	for u: Dictionary in w.drone_cfg.get("upgrades", []):
		if str(u["id"]) == id:
			return u
	return {}


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
	if w.player.inventory.count_of("circuit") < int(u["cost_circuit"][level]):
		return "circuit"
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
	w.player.inventory.remove("circuit", int(u["cost_circuit"][level]))
	w.bolts_changed.emit(w.bolts)
	w.drone_upgrades[id] = level + 1
	w.recompute_modifiers()
	w.drone_upgrade_bought.emit(id, level + 1)


static func _tick_drones(w: SimWorld) -> void:
	for d: Drone in w.drones.values():
		var before := d.state
		var before_carry := d.carry_count
		d.tick(w)
		if d.state != before or d.carry_count != before_carry:
			w.drone_changed.emit(d)
