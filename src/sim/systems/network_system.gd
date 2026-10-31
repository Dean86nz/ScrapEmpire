class_name NetworkSystem
extends RefCounted
## Sammelstellen, Bot-Zuweisung und Kurier (MS34). Teilsystem von SimWorld: statische Funktionen,
## `w` ist die Welt. Werte in data/ship.json („courier“) und data/buildings.json („collection_point“).


const POINT_DEF := "collection_point"
const SITE_REACH_PX := 170.0   # so nah muss Rusty am Bauplatz stehen (A baut)

# --- Sammelstellen --------------------------------------------------------------

static func points(w: SimWorld) -> Array[CollectionPoint]:
	var out: Array[CollectionPoint] = []
	for b: Building in w.buildings.values():
		if b is CollectionPoint:
			out.append(b as CollectionPoint)
	return out


static func point_in_zone(w: SimWorld, zone_id: String) -> CollectionPoint:
	for p in points(w):
		if w.zones.zone_id_at(p.tile) == zone_id:
			return p
	return null


## Abgabeort für einen Bot: Sammelstelle seiner Zone, sonst das Schiff.
static func depot_for(w: SimWorld, zone_id: String) -> Building:
	var p := point_in_zone(w, zone_id)
	if p != null:
		return p
	return ShipSystem.ship(w)


## Nächster Abgabeort zu einem Punkt (Kurier): Sammelstelle oder Schiff, was näher liegt.
static func nearest_depot(w: SimWorld, pos: Vector2i) -> Building:
	var best: Building = ShipSystem.ship(w)
	var best_d := INF if best == null else Vector2(pos).distance_to(Vector2(best.center_px()))
	for p in points(w):
		var d := Vector2(pos).distance_to(Vector2(p.center_px()))
		if d < best_d:
			best_d = d
			best = p
	return best


## Eine Sammelstelle je Zone (max_per_zone). "" = erlaubt.
## Fester Bauplatz der Zone (Kachel oben links), (-1, -1) ohne Bauplatz.
static func site_of(w: SimWorld, zone_id: String) -> Vector2i:
	var z := w.zones.zone_by_id(zone_id)
	return z.get("site", Vector2i(-1, -1)) if not z.is_empty() else Vector2i(-1, -1)


## Leerer Bauplatz, an dem Rusty gerade steht (Zonen-ID), sonst "".
static func site_near_player(w: SimWorld, reach_px: float = SITE_REACH_PX) -> String:
	for z in w.zones.zones:
		var site: Vector2i = z.get("site", Vector2i(-1, -1))
		if site.x < 0 or not w.zones.is_unlocked(str(z["id"])) or w.grid.at(site) != null:
			continue
		var center := Vector2(site * Building.TILE + Vector2i(Building.TILE, Building.TILE))
		if center.distance_to(Vector2(w.player.pos)) <= reach_px:
			return str(z["id"])
	return ""


## A am Bauplatz: Sammelstelle genau dort bauen (Kosten, Freischaltung prüft _cmd_place).
static func _cmd_build_point(w: SimWorld, cmd: Dictionary) -> void:
	var site := site_of(w, str(cmd.get("zone", "")))
	if site.x < 0:
		w.place_failed.emit("site")
		return
	BuildingSystem._cmd_place(w, {"def_id": POINT_DEF, "tile": site, "rot": 0})


static func zone_check(w: SimWorld, def: BuildingDef, tile: Vector2i) -> String:
	if def.max_per_zone <= 0:
		return ""
	var zid := w.zones.zone_id_at(tile)
	if zid == "" or not w.zones.is_unlocked(zid):
		return "zone"
	var n := 0
	for b: Building in w.buildings.values():
		if b.def.id == def.id and w.zones.zone_id_at(b.tile) == zid:
			n += 1
	return "zone_full" if n >= def.max_per_zone else ""


## Neue Sammelstelle: bringt eine Drohne mit (Transport zum Schiff).
static func on_point_built(w: SimWorld, _p: CollectionPoint) -> void:
	var free := int(w.drone_cfg.get("free_per_point", 1))
	for i in free:
		if w.drones.size() < int(w.drone_cfg.get("max_drones", 12)):
			DroneSystem.add_drone(w)


# --- Bots: immer automatisch (seit MS42) -------------------------------------------

## Automatik: nächste freigeschaltete Zone mit Müll, den der Bot schafft.
static func _auto_pick(w: SimWorld, h: Helper) -> void:
	var best := ""
	var best_d := INF
	for z: Dictionary in w.zones.zones:
		var zid := str(z["id"])
		if not w.zones.is_unlocked(zid) or int(h.zone_avoid.get(zid, 0)) > w.tick_count:
			continue
		var has_work := false
		for n: ResourceNode in w.nodes.values():
			if n.is_depleted() or w.zones.zone_id_at(n.tile) != zid:
				continue
			if not n.boss and n.tier <= (h.hammer_tier if n.uses_hammer() else h.suction_tier):
				has_work = true
				break
		if not has_work:
			continue
		var r: Rect2i = z["rect"]
		var c := Vector2(r.get_center()) * SimWorld.TILE
		var d := c.distance_to(Vector2(h.pos))
		if d < best_d:
			best_d = d
			best = zid
	if best != "" and best != h.zone_id:
		h.zone_id = best
		h.request_replan()


static func _tick_auto(w: SimWorld) -> void:
	if w.tick_count % 20 != 7:
		return
	for h: Helper in w.helpers.values():
		if h.bored != "" and h.inventory.total() == 0 and h.rally_id < 0:
			_auto_pick(w, h)


# --- Kurier ------------------------------------------------------------------------

static func courier_level(w: SimWorld) -> int:
	if not w.unlocked_features.has("courier"):
		return 0
	return 1 + int(w.ship_upgrades.get("courier", 0))


static func courier_stats(w: SimWorld) -> Dictionary:
	var levels: Array = w.ship_cfg.get("courier", {}).get("levels", [])
	var lv := courier_level(w)
	if lv <= 0 or levels.is_empty():
		return {}
	return levels[mini(lv, levels.size()) - 1]


## "" wenn ein Kurier gerufen werden kann, sonst: locked, cooldown, busy, empty.
static func can_call(w: SimWorld) -> String:
	var st := courier_stats(w)
	if st.is_empty():
		return "locked"
	if w.player.inventory.total() <= 0:
		return "empty"
	if w.couriers.size() >= int(st.get("count", 1)):
		return "busy"
	if w.courier_cooldown > 0:
		return "cooldown"
	return ""


static func _cmd_call_courier(w: SimWorld, _cmd: Dictionary) -> void:
	var reason := can_call(w)
	if reason != "":
		w.courier_failed.emit(reason)
		return
	_dispatch(w)


static func _dispatch(w: SimWorld) -> void:
	var st := courier_stats(w)
	var c := Courier.new()
	c.id = w.next_id()
	var s := ShipSystem.ship(w)
	c.home = s.center_px() if s != null else w.player.pos
	c.pos = c.home
	c.load_max = int(st.get("load", 40))
	c.speed_px_per_tick = int(round(float(st.get("speed", 360)) / 20.0))
	w.couriers[c.id] = c
	w.courier_cooldown = int(float(st.get("wait_s", 90)) * 20)
	w.courier_added.emit(c)


static func _tick_couriers(w: SimWorld) -> void:
	if w.courier_cooldown > 0:
		w.courier_cooldown -= 1
	# Automatik: volle Taschen rufen den Kurier
	if bool(w.flags.get("courier_auto", true)) and w.player.inventory.is_full() and can_call(w) == "":
		_dispatch(w)
	for c: Courier in w.couriers.values():
		match c.state:
			Courier.State.TO_PLAYER:
				if c.fly_to(w.player.pos):
					_load(w, c)
			Courier.State.TO_DEPOT:
				var dep: Building = w.buildings.get(c.depot_id)
				if dep == null:
					dep = nearest_depot(w, c.pos)
					if dep == null:
						continue
					c.depot_id = dep.id
				if c.fly_to(dep.center_px()):
					for item in c.carry:
						dep.accept_stack(str(item), int(c.carry[item]))
					c.carry = {}
					w.building_changed.emit(dep)
					w.courier_unloaded.emit(c, dep)
					c.state = Courier.State.HOME
			Courier.State.HOME:
				if c.fly_to(c.home):
					w.couriers.erase(c.id)
					w.courier_removed.emit(c.id)


## Am Spieler: Ladung übernehmen (größte Stapel zuerst), dann zum nächsten Abgabeort.
static func _load(w: SimWorld, c: Courier) -> void:
	var left := c.load_max if c.load_max > 0 else 1000000
	var taken := {}
	for s: Dictionary in w.player.inventory.slots.duplicate(true):
		if left <= 0:
			break
		if s["item"] == "":
			continue
		var n := mini(int(s["count"]), left)
		w.player.inventory.remove(str(s["item"]), n)
		taken[s["item"]] = int(taken.get(s["item"], 0)) + n
		left -= n
	c.carry = taken
	var dep := nearest_depot(w, w.player.pos)
	c.depot_id = dep.id if dep != null else -1
	c.state = Courier.State.TO_DEPOT
	w.quests.on_courier()
	w.courier_loaded.emit(c, taken)
