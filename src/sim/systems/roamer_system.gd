class_name RoamerSystem
extends RefCounted
## Streuner (MS77): Bots ohne Zone. Sie suchen sich selbst den nächsten Müll auf dem ganzen
## Planeten (nur offene Zonen), pressen volle Ladung zu einem Müllwürfel und schießen ihn zum
## nächsten Fangtrichter mit Platz. Zielsuche über ein grobes Raster (CHUNK×CHUNK Kacheln), damit
## auch sehr viele Streuner billig bleiben. Werte in data/helpers.json („roamer“).
## Teilsystem von SimWorld: statische Funktionen, `w` ist die Welt.

const KIND := "roamer"
const HOPPER_DEF := "hopper"
const CHUNK := 8

static var last_too_hard := false   # letzte Suche fand nur zu harten Müll


static func cfg(w: SimWorld) -> Dictionary:
	return w.helper_cfg.get("roamer", {})


static func count(w: SimWorld) -> int:
	var n := 0
	for h: Helper in w.helpers.values():
		if h.kind == KIND:
			n += 1
	return n


static func hoppers(w: SimWorld) -> Array[Hopper]:
	var out: Array[Hopper] = []
	for b: Building in w.buildings.values():
		if b is Hopper:
			out.append(b as Hopper)
	return out


# --- Kauf ------------------------------------------------------------------------------

static func next_cost(w: SimWorld) -> int:
	var c := cfg(w)
	return int(round(float(c.get("cost_base_bolts", 20000)) * pow(float(c.get("cost_growth", 1.08)), count(w)) / 10.0)) * 10


## "" wenn baubar, sonst: locked, max, bolts, no_ship
static func can_buy(w: SimWorld) -> String:
	if not w.unlocked_features.has("roamers"):
		return "locked"
	if count(w) >= int(cfg(w).get("max", 300)):
		return "max"
	if w.bolts < next_cost(w):
		return "bolts"
	if ShipSystem.ship(w) == null:
		return "no_ship"
	return ""


static func _cmd_buy(w: SimWorld, _cmd: Dictionary) -> void:
	var reason := can_buy(w)
	if reason != "":
		w.helper_failed.emit(reason)
		return
	w.bolts -= next_cost(w)
	w.bolts_changed.emit(w.bolts)
	var ship := ShipSystem.ship(w)
	var h := HelperSystem.add_helper(w, ship.tile, ship.tile)
	h.kind = KIND
	h.zone_id = ""


## Fangtrichter in Rustys Nähe abstellen: nächster freier Platz um ihn herum.
static func _cmd_place_hopper(w: SimWorld, _cmd: Dictionary) -> void:
	BuildingSystem.place_near_player(w, HOPPER_DEF)


# --- Zielsuche über das Raster ----------------------------------------------------------

static func chunk_of(tile: Vector2i) -> Vector2i:
	return Vector2i(floori(tile.x / float(CHUNK)), floori(tile.y / float(CHUNK)))


static func _ensure_chunks(w: SimWorld) -> void:
	if not w._chunks_dirty:
		return
	w._chunks_dirty = false
	w._chunk_nodes.clear()
	w._chunk_min_tier.clear()
	for n: ResourceNode in w.nodes.values():
		if n.boss:
			continue   # Bosse nur auf Rustys Ruf, nie Ziel der Suche
		var c := chunk_of(n.tile)
		if not w._chunk_nodes.has(c):
			w._chunk_nodes[c] = []
			w._chunk_min_tier[c] = n.tier
		w._chunk_nodes[c].append(n)
		w._chunk_min_tier[c] = mini(int(w._chunk_min_tier[c]), n.tier)


## Objekt entfernt: nur aus seinem Rasterfeld streichen (kein Neuaufbau).
static func on_node_removed(w: SimWorld, n: ResourceNode) -> void:
	if not w._chunks_dirty:
		(w._chunk_nodes.get(chunk_of(n.tile), []) as Array).erase(n)


## Nächstes Objekt, das der Streuner schafft, in einer offenen Zone. Geht die belegten
## Rasterfelder nach Entfernung durch und hört auf, sobald kein näheres Ziel mehr möglich ist.
static func find_target(w: SimWorld, h: Helper) -> ResourceNode:
	_ensure_chunks(w)
	last_too_hard = false
	var hp := Vector2(h.pos)
	var max_tier := maxi(h.hammer_tier, h.suction_tier)
	var size := float(CHUNK * SimWorld.TILE)
	var order: Array = []
	for cc: Vector2i in w._chunk_nodes:
		if (w._chunk_nodes[cc] as Array).is_empty():
			continue
		# Ganzes Feld zu hart (leichteste Stufe darin): überspringen (bleibt beim Abbau gültig)
		if int(w._chunk_min_tier.get(cc, 1)) > max_tier:
			last_too_hard = true
			continue
		var lo := Vector2(cc) * size
		var q := hp.clamp(lo, lo + Vector2(size, size))
		order.append([hp.distance_to(q), cc])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var best: ResourceNode = null
	var best_d := INF
	var open := {}
	for e: Array in order:
		if float(e[0]) >= best_d:
			break
		for n: ResourceNode in w._chunk_nodes[e[1]]:
			if n.is_depleted() or int(h._avoid.get(n.tile, 0)) > w.tick_count:
				continue
			if int(w._roamer_claims.get(n.tile, 0)) >= (2 if n.nav_size <= 1 else 4):
				continue   # schon genug Streuner dort: verteilen statt klumpen
			if n.tier > (h.hammer_tier if n.uses_hammer() else h.suction_tier):
				last_too_hard = true
				continue
			var d := hp.distance_to(Vector2(n.center_px()))
			if d >= best_d:
				continue
			var zid := w.zones.zone_id_at(n.tile)
			if not open.has(zid):
				open[zid] = (zid == "" or w.zones.is_unlocked(zid)) and int(h.zone_avoid.get(zid, 0)) <= w.tick_count
			if open[zid]:
				best_d = d
				best = n
	return best


## Ziel belegen bzw. freigeben (Verteilung der Streuner, nicht gespeichert).
static func claim(w: SimWorld, h: Helper, tile: Vector2i) -> void:
	release(w, h)
	h.claim_tile = tile
	w._roamer_claims[tile] = int(w._roamer_claims.get(tile, 0)) + 1


static func release(w: SimWorld, h: Helper) -> void:
	if h.claim_tile.x < 0:
		return
	var n := int(w._roamer_claims.get(h.claim_tile, 0)) - 1
	if n > 0:
		w._roamer_claims[h.claim_tile] = n
	else:
		w._roamer_claims.erase(h.claim_tile)
	h.claim_tile = Vector2i(-1, -1)


# --- Müllwürfel ------------------------------------------------------------------------

## Nächster Fangtrichter in Wurfweite, in den `n` Teile noch passen.
static func nearest_hopper(w: SimWorld, pos: Vector2i, n: int) -> Hopper:
	var reach := float(cfg(w).get("throw_range_px", 1600))
	var best: Hopper = null
	var best_d := INF
	for hop in hoppers(w):
		if hop.free_space() < n:
			continue
		var d := Vector2(pos).distance_to(Vector2(hop.center_px()))
		if d <= reach and d < best_d:
			best_d = d
			best = hop
	return best


## Ladung pressen und zum Trichter schießen. false: kein Trichter mit Platz in Reichweite.
static func throw_cube(w: SimWorld, h: Helper) -> bool:
	var n := h.inventory.total()
	if n <= 0:
		return true
	var hop := nearest_hopper(w, h.pos, n)
	if hop == null:
		return false
	var items := {}
	for sl: Dictionary in h.inventory.slots:
		if str(sl["item"]) != "" and int(sl["count"]) > 0:
			items[str(sl["item"])] = int(items.get(str(sl["item"]), 0)) + int(sl["count"])
	for item in items:
		h.inventory.remove(str(item), int(items[item]))
	launch_cube(w, items, h.pos, hop)
	w.perf.add("roamer", n, w.tick_count)   # MS79
	return true


## Würfel mit `items` von `from` zum Gebäude `target` schießen (Trichter oder Schiff).
static func launch_cube(w: SimWorld, items: Dictionary, from: Vector2i, target: Building) -> TrashCube:
	var cube := TrashCube.new()
	cube.id = w.next_id()
	cube.items = items.duplicate()
	cube.from = from
	cube.to = target.center_px()
	cube.hopper_id = target.id
	var speed := float(cfg(w).get("throw_speed_px_s", 900)) / 20.0
	cube.dur = maxi(10, int(Vector2(cube.to - cube.from).length() / speed))
	if target is Hopper:
		(target as Hopper).incoming += cube.count()
	w.cubes[cube.id] = cube
	w.cube_thrown.emit(cube)
	return cube


static func _tick_cubes(w: SimWorld) -> void:
	for cube: TrashCube in w.cubes.values():
		cube.t += 1
		if cube.t < cube.dur:
			continue
		w.cubes.erase(cube.id)
		var hop: Building = w.buildings.get(cube.hopper_id)
		var left := cube.items.duplicate()
		if hop != null:
			if hop is Hopper:
				(hop as Hopper).incoming = maxi(0, (hop as Hopper).incoming - cube.count())
			for item in cube.items:
				left[item] = int(left[item]) - hop.accept_stack(str(item), int(cube.items[item]))
			w.building_changed.emit(hop)
		# Was nicht passt (Trichter weg oder doch voll), fällt daneben auf den Boden
		for item in left:
			if int(left[item]) > 0:
				NodeSystem.add_loose(w, str(item), cube.to + Vector2i(0, 72), 1, int(left[item]))
		w.cube_landed.emit(cube, hop)


static func cubes_to_list(w: SimWorld) -> Array:
	var out: Array = []
	for cube: TrashCube in w.cubes.values():
		out.append(cube.to_dict())
	return out


static func cubes_from_list(w: SimWorld, arr: Array) -> void:
	for d: Dictionary in arr:
		var cube := TrashCube.new()
		cube.id = w.next_id()
		cube.from_dict(d)
		w.cubes[cube.id] = cube
		var hop := w.buildings.get(cube.hopper_id) as Hopper
		if hop != null:
			hop.incoming += cube.count()
