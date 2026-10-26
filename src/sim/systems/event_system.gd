class_name EventSystem
extends RefCounted
## Nachschub-Ereignisse (MS30): Weltraum-Touristen werfen Müllsäcke ab, Meteoritenschauer bringen
## glitzernde Brocken. Alles aus data/events.json, deterministisch über w.rng. Ablauf je Ereignis:
## fällig → Vorwarnung (Ziel-Kacheln stehen fest) → Start (Abwürfe gestaffelt) → Objekte landen.
## Neuer Müll landet nur in freigeschalteten Zonen und verschmutzt den Boden nicht.
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt.

const TPS := 20


## Gleitkomma-Zufall aus dem deterministischen Sim-Zufall (SimRng kennt nur Ganzzahlen).
static func _randf(w: SimWorld) -> float:
	return w.rng.randi_range(0, 1000000) / 1000000.0


static func _randf_range(w: SimWorld, a: float, b: float) -> float:
	return lerpf(a, b, _randf(w))


static func load_config(path: String = "res://data/events.json") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


static func _cfg(w: SimWorld, type: String) -> Dictionary:
	return w.events_cfg.get("events", {}).get(type, {})


static func _range(w: SimWorld, a: Variant, def: float) -> float:
	if a is Array and a.size() >= 2:
		return _randf_range(w, float(a[0]), float(a[1]))
	return float(a) if a != null else def


## Startzeiten für ein neues Spiel oder einen alten Stand ohne Ereignisse.
static func ensure_state(w: SimWorld) -> void:
	if w.events_state.has("next"):
		return
	var nxt := {}
	for type: String in w.events_cfg.get("events", {}):
		var c := _cfg(w, type)
		nxt[type] = w.tick_count + int(float(c.get("first_s", _range(w, c.get("gap_s"), 300.0))) * TPS)
	w.events_state = {"next": nxt, "warn": [], "drops": []}


static func bonus_count(w: SimWorld) -> int:
	var n := 0
	for node: ResourceNode in w.nodes.values():
		if node.bonus:
			n += 1
	for d: Dictionary in w.events_state.get("drops", []):
		n += 1
	return n


static func _tick(w: SimWorld) -> void:
	if w.events_cfg.is_empty():
		return
	ensure_state(w)
	var st := w.events_state
	# fällige Ereignisse ankündigen
	for type: String in st["next"]:
		if w.tick_count < int(st["next"][type]):
			continue
		var c := _cfg(w, type)
		st["next"][type] = w.tick_count + int(_range(w, c.get("gap_s"), 300.0) * TPS)
		if not _allowed(w, type, c):
			continue
		var tiles := _pick_tiles(w, c)
		if tiles.is_empty():
			continue
		var warn_ticks := int(float(c.get("warn_s", 5)) * TPS)
		st["warn"].append({"type": type, "ticks_left": warn_ticks, "tiles": tiles})
		w.event_warning.emit(type, float(c.get("warn_s", 5)), _center_px(tiles))
	# Vorwarnung abgelaufen: Abwürfe planen
	var i := (st["warn"] as Array).size() - 1
	while i >= 0:
		var wv: Dictionary = st["warn"][i]
		wv["ticks_left"] = int(wv["ticks_left"]) - 1
		if int(wv["ticks_left"]) <= 0:
			st["warn"].remove_at(i)
			_start(w, str(wv["type"]), wv["tiles"])
		i -= 1
	# Abwürfe landen
	i = (st["drops"] as Array).size() - 1
	while i >= 0:
		var dv: Dictionary = st["drops"][i]
		dv["ticks_left"] = int(dv["ticks_left"]) - 1
		if int(dv["ticks_left"]) <= 0:
			st["drops"].remove_at(i)
			_land(w, dv)
		i -= 1


static func _allowed(w: SimWorld, type: String, c: Dictionary) -> bool:
	var s := w.ship()
	if s != null and s.stage < int(c.get("min_ship_stage", 1)):
		return false
	if bool(w.flags.get("launched", false)) and not bool(c.get("after_launch", true)):
		return false
	return bonus_count(w) < int(w.events_cfg.get("max_bonus_objects", 40))


static func _start(w: SimWorld, type: String, tiles: Array) -> void:
	var c := _cfg(w, type)
	var first := float(c.get("first_drop_s", 1.0))
	var step := float(c.get("drop_step_s", 0.3))
	var delays: Array = []
	for k in tiles.size():
		var ticks := int((first + k * step) * TPS)
		delays.append(ticks / float(TPS))
		w.events_state["drops"].append({"type": type, "tile": tiles[k], "ticks_left": ticks, "loot": _roll_loot(w, c)})
	var px: Array = []
	for t in tiles:
		px.append(Vector2(SaveCodec.to_v2(t)) * SimWorld.TILE + Vector2(32, 32))
	w.event_started.emit(type, px, delays)


static func _land(w: SimWorld, dv: Dictionary) -> void:
	var c := _cfg(w, str(dv["type"]))
	var tile := _free_near(w, SaveCodec.to_v2(dv["tile"]))
	if tile.x < 0:
		return
	var node := w.add_wreck(tile, dv["loot"], str(c.get("kind", "trash_bag")))
	node.bonus = true
	w.event_landed.emit(str(dv["type"]), node)


## Beute: Anzahl aus items × value_mult (mehr wert = mehr drin), Sorten nach Gewicht.
static func _roll_loot(w: SimWorld, c: Dictionary) -> Dictionary:
	var n := int(round(_range(w, c.get("items", [10, 15]), 12.0) * float(c.get("value_mult", 1.0))))
	var mix: Dictionary = c.get("loot", {"scrap": 1})
	var keys := mix.keys()
	keys.sort()
	var total := 0.0
	for k in keys:
		total += float(mix[k])
	var loot := {}
	for j in n:
		var r: float = _randf(w) * total
		for k in keys:
			r -= float(mix[k])
			if r <= 0.0:
				loot[str(k)] = int(loot.get(str(k), 0)) + 1
				break
	return loot


static func _pick_tiles(w: SimWorld, c: Dictionary) -> Array:
	var count := int(round(_range(w, c.get("count", [4, 6]), 5.0)))
	count = mini(count, int(w.events_cfg.get("max_bonus_objects", 40)) - bonus_count(w))
	var near := float(c.get("near_player", 1.0))
	var rmin := int(c.get("radius", [4, 9])[0])
	var rmax := int(c.get("radius", [4, 9])[1])
	var ptile := w.player_tile()
	var tiles: Array = []
	var taken := {}
	var tries := 0
	while tiles.size() < count and tries < count * 40:
		tries += 1
		var t: Vector2i
		if _randf(w) < near:
			var ang: float = _randf(w) * TAU
			var dist: float = _randf_range(w, rmin, rmax)
			t = ptile + Vector2i(roundi(cos(ang) * dist), roundi(sin(ang) * dist))
		else:
			t = Vector2i(w.rng.randi_range(1, w.width_tiles - 2), w.rng.randi_range(1, w.height_tiles - 2))
		if taken.has(t) or not _free(w, t):
			continue
		taken[t] = true
		tiles.append([t.x, t.y])
	return tiles


static func _free(w: SimWorld, t: Vector2i) -> bool:
	if t.x < 1 or t.y < 1 or t.x >= w.width_tiles - 1 or t.y >= w.height_tiles - 1:
		return false
	var zid := w.zones.zone_id_at(t)
	if zid == "" or not w.zones.is_unlocked(zid):
		return false
	var r: Rect2i = w.zones.zone_by_id(zid).get("rect", Rect2i())
	if t.x <= r.position.x or t.y <= r.position.y or t.x >= r.end.x - 1 or t.y >= r.end.y - 1:
		return false  # nicht auf den Zaun
	return not w._node_tiles.has(t) and not w._tile_blocked(t)


static func _free_near(w: SimWorld, t: Vector2i) -> Vector2i:
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if _free(w, t + Vector2i(dx, dy)):
					return t + Vector2i(dx, dy)
	return Vector2i(-1, -1)


static func _center_px(tiles: Array) -> Vector2:
	var s := Vector2.ZERO
	for t in tiles:
		s += Vector2(SaveCodec.to_v2(t))
	return s / maxf(tiles.size(), 1) * SimWorld.TILE + Vector2(32, 32)
