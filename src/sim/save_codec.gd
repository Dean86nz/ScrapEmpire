class_name SaveCodec
extends RefCounted
## Wandelt die SimWorld in ein JSON-taugliches Dictionary und zurück (Architektur 4.8, 12).
## Reine Logik ohne Datei-IO; SaveManager kümmert sich um Dateien, Rotation und Migration.

const VERSION := 7


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
		"tasks": world.tasks.to_dict(),
		"helpers": _helpers(world),
		"helper_upgrades": world.helper_upgrades.duplicate(),
		"drones": _drones(world),
		"drone_upgrades": world.drone_upgrades.duplicate(),
		"collectibles_found": world.collectibles_found.keys(),
		"quests": world.quests.to_dict(),
		"flags": world.flags.duplicate(),
		"unlocked_zones": world.zones.unlocked.keys(),
		"tutorial": {"step": int(world.flags.get("tutorial_step", 0)), "done": bool(world.flags.get("tutorial_done", false))},
	}


static func _drones(world: SimWorld) -> Array:
	var arr: Array = []
	for d: Drone in world.drones.values():
		arr.append(d.to_dict(world))
	return arr


static func _helpers(world: SimWorld) -> Array:
	var arr: Array = []
	for h: Helper in world.helpers.values():
		arr.append(h.to_dict())
	return arr


static func _building_state(b: Building) -> Dictionary:
	if b is Machine:
		var m := b as Machine
		return {
			"input": m.input.duplicate(), "output": m.output.duplicate(),
			"progress": m.progress_ticks, "recipe": m.current_recipe.id if m.current_recipe != null else "",
		}
	if b is SellTerminal:
		var t := b as SellTerminal
		return {"buffer": t.buffer.duplicate(), "cooldown": t.get_cooldown()}
	if b is Ship:
		var s := b as Ship
		return {"stage": s.stage, "storage": s.storage.to_dict(), "cooldown": s.get_cooldown()}
	if b is Chest:
		return {"inventory": (b as Chest).inventory.to_dict()}
	if b is Conveyor:
		return {"items": (b as Conveyor).items.duplicate(true)}
	if b is Extractor:
		var e := b as Extractor
		return {"buffer": e.buffer.duplicate(), "counter": e.counter}
	return {}


# --- Lesen ------------------------------------------------------------------

## Stellt den Zustand in einer vorbereiteten Welt her (Größe, defs, recipes, Tech-/Skilldaten
## müssen bereits gesetzt sein; Nodes/Gebäude müssen leer sein). Liefert die Spielerposition.
static func decode(data: Dictionary, world: SimWorld) -> Vector2:
	world.tick_count = int(data.get("tick_count", 0))
	world.bolts = int(data.get("bolts", 0))
	world.rng.set_state(int(data.get("rng_state", 0)))
	world.progression.from_dict(data.get("progression", {}))
	world.skills.from_dict(data.get("skills", {}))
	world.tech.from_dict(data.get("tech", {}))
	for id in world.tech.unlocked.keys():
		world._apply_tech_effects(str(id))

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

	world.tasks.from_dict(data.get("tasks", {}))
	for k in data.get("helper_upgrades", {}):
		world.helper_upgrades[str(k)] = int(data["helper_upgrades"][k])
	for hd: Dictionary in data.get("helpers", []):
		var h := world.add_helper(SaveCodec.to_v2(hd.get("zone")), SaveCodec.to_v2(hd.get("depot")), int(hd.get("name_index", 0)), int(hd.get("color_index", 0)))
		h.from_dict(hd)
	for k in data.get("drone_upgrades", {}):
		world.drone_upgrades[str(k)] = int(data["drone_upgrades"][k])
	for dd: Dictionary in data.get("drones", []):
		var src := world.grid.at(to_v2(dd.get("source_tile")))
		var dst := world.grid.at(to_v2(dd.get("target_tile")))
		if src == null or dst == null:
			push_warning("Spielstand: Drohne ohne Quelle oder Ziel übersprungen")
			continue
		var d := world.add_drone(src.id, dst.id)
		d.from_dict(dd)
	if not data.get("drone_upgrades", {}).is_empty():
		world.recompute_modifiers()
	for cid in data.get("collectibles_found", []):
		world.collectibles_found[str(cid)] = true
	world.quests.from_dict(data.get("quests", {}))
	for k in data.get("flags", {}):
		world.flags[str(k)] = data["flags"][k]
	for z in data.get("unlocked_zones", []):
		world.zones.unlocked[str(z)] = true
	var tut: Dictionary = data.get("tutorial", {})
	world.flags["tutorial_step"] = int(tut.get("step", 0))
	world.flags["tutorial_done"] = bool(tut.get("done", false))
	var pd: Dictionary = data.get("player", {})
	world.player.inventory.from_dict(pd.get("inventory", {}))
	world.recompute_modifiers()
	var pos_arr: Array = pd.get("pos", [0, 0])
	var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
	world.player.pos = Vector2i(pos.round())
	world.bolts_changed.emit(world.bolts)
	return pos


static func _restore_building(b: Building, st: Dictionary, world: SimWorld) -> void:
	if b is Machine:
		var m := b as Machine
		m.input = _int_dict(st.get("input", {}))
		m.output = _int_dict(st.get("output", {}))
		m.progress_ticks = int(st.get("progress", 0))
		var rid := str(st.get("recipe", ""))
		m.current_recipe = null
		for r in world.recipes:
			if r.id == rid:
				m.current_recipe = r
		if m.current_recipe == null:
			m.progress_ticks = 0
	elif b is SellTerminal:
		var t := b as SellTerminal
		for item in st.get("buffer", []):
			t.buffer.append(str(item))
		t.set_cooldown(int(st.get("cooldown", 0)))
	elif b is Ship:
		var s := b as Ship
		s.stage = maxi(int(st.get("stage", 1)), 1)
		ShipSystem.apply_stage(world, s)
		s.storage.from_dict(st.get("storage", {}))
		s.set_cooldown(int(st.get("cooldown", 0)))
	elif b is Chest:
		(b as Chest).inventory.from_dict(st.get("inventory", {}))
	elif b is Conveyor:
		var c := b as Conveyor
		for it: Dictionary in st.get("items", []):
			c.items.append({"item": str(it.get("item", "scrap")), "offset": int(it.get("offset", 0))})
	elif b is Extractor:
		var e := b as Extractor
		for item in st.get("buffer", []):
			e.buffer.append(str(item))
		e.counter = int(st.get("counter", 0))
