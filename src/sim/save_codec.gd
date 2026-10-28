class_name SaveCodec
extends RefCounted
## Wandelt die SimWorld in ein JSON-taugliches Dictionary und zurück (Architektur 4.8, 12).
## Reine Logik ohne Datei-IO; SaveManager kümmert sich um Dateien, Rotation und Migration.

const VERSION := 10
## Ältere Stände stammen aus der Fabrik-Version und werden nicht mehr geladen (Kurswechsel MS20).
const MIN_VERSION := 10


static func v2(v: Vector2i) -> Array:
	return [v.x, v.y]


static func to_v2(a: Variant, fallback := Vector2i.ZERO) -> Vector2i:
	if a is Array and a.size() >= 2:
		return Vector2i(int(a[0]), int(a[1]))
	return fallback


static func _int_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		out[str(k)] = int(d[k])
	return out


# --- Schreiben --------------------------------------------------------------

static func encode(world: SimWorld, map_name: String, player_pos: Vector2, selected_slot: int) -> Dictionary:
	var nodes: Array = []
	for n: ResourceNode in world.nodes.values():
		nodes.append({
			"kind": n.kind, "tile": v2(n.tile), "amount": n.amount,
			"loot": n.loot.duplicate(), "regen_counter": n.regen_counter,
		})
	var loose: Array = []
	for item: LooseItem in world.loose.values():
		loose.append({"item": item.item_id, "pos": v2(item.pos), "tier": item.tier})
	var buildings: Array = []
	for b: Building in world.buildings.values():
		buildings.append({
			"def": b.def.id, "tile": v2(b.tile), "rot": b.rot,
			"paid_cost": b.paid_cost.duplicate(), "state": _building_state(b),
		})
	var respawns: Array = []
	for r: Dictionary in world.respawns:
		respawns.append({"kind": r["kind"], "tile": v2(r["tile"]), "ticks_left": int(r["ticks_left"])})
	return {
		"version": VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"tick_count": world.tick_count,
		"map": map_name,
		"player": {
			"pos": [player_pos.x, player_pos.y],
			"inventory": world.player.inventory.to_dict(),
			"selected_slot": selected_slot,
		},
		"bolts": world.bolts,
		"progression": world.progression.to_dict(),
		"skills": world.skills.to_dict(),
		"tech": world.tech.to_dict(),
		"rng_state": world.rng.get_state(),
		"nodes": nodes,
		"loose": loose,
		"buildings": buildings,
		"respawns": respawns,
		"helpers": _helpers(world),
		"helper_upgrades": world.helper_upgrades.duplicate(),
		"drones": _drones(world),
		"drone_upgrades": world.drone_upgrades.duplicate(),
		"ship_upgrades": world.ship_upgrades.duplicate(),
		"collectibles_found": world.collectibles_found.keys(),
		"quests": world.quests.to_dict(),
		"milestones": world.milestones.to_dict(),
		"events": world.events_state.duplicate(true),
		"couriers": _couriers(world),
		"courier_cooldown": world.courier_cooldown,
		"bonus_nodes": _bonus_ids(world),
		"dirt": world.dirt.to_dict(),
		"flags": world.flags.duplicate(),
		"unlocked_zones": world.zones.unlocked.keys(),
		"tutorial": {"step": int(world.flags.get("tutorial_step", 0)), "done": bool(world.flags.get("tutorial_done", false))},
	}


static func _drones(world: SimWorld) -> Array:
	var arr: Array = []
	for d: Drone in world.drones.values():
		arr.append(d.to_dict())
	return arr


static func _helpers(world: SimWorld) -> Array:
	var arr: Array = []
	for h: Helper in world.helpers.values():
		arr.append(h.to_dict())
	return arr


static func _couriers(world: SimWorld) -> Array:
	var out: Array = []
	for c: Courier in world.couriers.values():
		out.append(c.to_dict())
	return out


static func _bonus_ids(world: SimWorld) -> Array:
	var out: Array = []
	for n: ResourceNode in world.nodes.values():
		if n.bonus:
			out.append(v2(n.tile))
	return out


## JSON macht aus Zahlen Floats: Ereignis-Zustand wieder mit Ganzzahlen.
static func _events_from(d: Dictionary) -> Dictionary:
	var out := {"next": {}, "warn": [], "drops": []}
	for k in d.get("next", {}):
		out["next"][str(k)] = int(d["next"][k])
	for wv: Dictionary in d.get("warn", []):
		out["warn"].append({"type": str(wv["type"]), "ticks_left": int(wv["ticks_left"]), "tiles": _int_tiles(wv.get("tiles", []))})
	for dv: Dictionary in d.get("drops", []):
		var loot := {}
		for k in dv.get("loot", {}):
			loot[str(k)] = int(dv["loot"][k])
		out["drops"].append({"type": str(dv["type"]), "ticks_left": int(dv["ticks_left"]), "tile": _int_tiles([dv.get("tile", [0, 0])])[0], "loot": loot})
	return out


static func _int_tiles(a: Array) -> Array:
	var out: Array = []
	for t in a:
		out.append([int(t[0]), int(t[1])])
	return out


static func _building_state(b: Building) -> Dictionary:
	if b is Ship:
		return {"stage": (b as Ship).stage, "clean_radius": (b as Ship).clean_radius}
	if b is CollectionPoint:
		return {"store": (b as CollectionPoint).store.duplicate()}
	return {}


# --- Lesen ------------------------------------------------------------------

## Stellt den Zustand in einer vorbereiteten Welt her (Größe, defs, recipes, Tech-/Skilldaten
## müssen bereits gesetzt sein; Nodes/Gebäude müssen leer sein). Liefert die Spielerposition.
## Schrittprotokoll beim Laden (setzt main.gd); Tests bleiben still.
static var log_steps := false


static func _log(msg: String) -> void:
	if log_steps:
		print("[Laden %6d ms] decode: %s" % [Time.get_ticks_msec(), msg])


static func decode(data: Dictionary, world: SimWorld) -> Vector2:
	_log("Version %d, Fortschritt" % int(data.get("version", 0)))
	world.tick_count = int(data.get("tick_count", 0))
	world.bolts = int(data.get("bolts", 0))
	world.rng.set_state(int(data.get("rng_state", 0)))
	world.progression.from_dict(data.get("progression", {}))
	world.progression.skill_points += world.skills.from_dict(data.get("skills", {}))
	world.tech.from_dict(data.get("tech", {}))
	for id in world.tech.unlocked.keys():
		world._apply_tech_effects(str(id))

	_log("Objekte: %d" % data.get("nodes", []).size())
	for nd: Dictionary in data.get("nodes", []):
		var kind := str(nd.get("kind", ""))
		if not ResourceNode.has_kind(kind):
			continue
		var n := world.add_object(kind, to_v2(nd.get("tile")))
		n.amount = int(nd.get("amount", n.amount))
		if nd.has("loot"):
			n.loot = _int_dict(nd["loot"])
		n.regen_counter = int(nd.get("regen_counter", 0))
	for ld: Dictionary in data.get("loose", []):
		world.add_loose(str(ld.get("item", "scrap")), to_v2(ld.get("pos")), int(ld.get("tier", 1)))
	_log("lose Items: %d, Gebäude: %d" % [data.get("loose", []).size(), data.get("buildings", []).size()])
	for bd: Dictionary in data.get("buildings", []):
		var def_id := str(bd.get("def", ""))
		if not world.defs.has(def_id):
			continue
		var b := world.place_free(def_id, to_v2(bd.get("tile")), int(bd.get("rot", 0)))
		if b == null:
			push_warning("Spielstand: Gebäude %s bei %s konnte nicht platziert werden" % [def_id, str(bd.get("tile"))])
			continue
		b.paid_cost = _int_dict(bd.get("paid_cost", {}))
		_restore_building(b, bd.get("state", {}), world)
	for rd: Dictionary in data.get("respawns", []):
		world.respawns.append({"kind": str(rd.get("kind", "")), "tile": to_v2(rd.get("tile")), "ticks_left": int(rd.get("ticks_left", 100))})

	# Rustys alte Aufgabenliste ("tasks", bis MS37) wird still ignoriert.
	_log("Helfer: %d, Drohnen: %d" % [data.get("helpers", []).size(), data.get("drones", []).size()])
	for k in data.get("helper_upgrades", {}):
		world.helper_upgrades[str(k)] = int(data["helper_upgrades"][k])
	for hd: Dictionary in data.get("helpers", []):
		var h := world.add_helper(SaveCodec.to_v2(hd.get("zone")), SaveCodec.to_v2(hd.get("depot")), int(hd.get("name_index", 0)), int(hd.get("color_index", 0)))
		h.from_dict(hd)
	for k in data.get("drone_upgrades", {}):
		world.drone_upgrades[str(k)] = int(data["drone_upgrades"][k])
	for k in data.get("ship_upgrades", {}):
		world.ship_upgrades[str(k)] = int(data["ship_upgrades"][k])
	for dd: Dictionary in data.get("drones", []):
		var d := world.add_drone()
		d.from_dict(dd)
	for cid in data.get("collectibles_found", []):
		world.collectibles_found[str(cid)] = true
	world.quests.from_dict(data.get("quests", {}))
	if data.has("milestones"):
		world.milestones.from_dict(data["milestones"])
	for cd: Dictionary in data.get("couriers", []):
		var c := Courier.new()
		c.id = world.next_id()
		c.from_dict(cd)
		world.couriers[c.id] = c
	world.courier_cooldown = int(data.get("courier_cooldown", 0))
	if data.has("events"):
		world.events_state = _events_from(data["events"])
	for t in data.get("bonus_nodes", []):
		var tile := to_v2(t)
		if world._node_tiles.has(tile):
			(world.nodes[world._node_tiles[tile]] as ResourceNode).bonus = true
	if data.has("dirt") and not (data["dirt"] as Dictionary).is_empty():
		_log("Schmutzkarte")
		if world.dirt_cfg.is_empty():
			world.dirt_cfg = DirtMap.load_config()
		world.dirt.from_dict(data["dirt"], world.zones, world.dirt_cfg)
	for k in data.get("flags", {}):
		world.flags[str(k)] = data["flags"][k]
	for z in data.get("unlocked_zones", []):
		world.zones.unlocked[str(z)] = true
	var tut: Dictionary = data.get("tutorial", {})
	world.flags["tutorial_step"] = int(tut.get("step", 0))
	world.flags["tutorial_done"] = bool(tut.get("done", false))
	_log("Spieler")
	var pd: Dictionary = data.get("player", {})
	world.player.inventory.from_dict(pd.get("inventory", {}))
	world.recompute_modifiers()
	var pos_arr: Array = pd.get("pos", [0, 0])
	var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
	world.player.pos = Vector2i(pos.round())
	world.bolts_changed.emit(world.bolts)
	return pos


static func _restore_building(b: Building, st: Dictionary, world: SimWorld) -> void:
	if b is Ship:
		var s := b as Ship
		s.stage = maxi(int(st.get("stage", 1)), 1)
		ShipSystem.apply_stage(world, s)
		s.clean_radius = int(st.get("clean_radius", ShipSystem.clean_target(world, s)))
	elif b is CollectionPoint:
		for k in st.get("store", {}):
			(b as CollectionPoint).store[str(k)] = int(st["store"][k])
