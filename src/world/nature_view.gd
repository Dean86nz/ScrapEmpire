class_name NatureView
extends Node2D
## Zonen-Heilung: Gras, Blumen, Büsche, Teiche und Tiere je Reinigungsstufe. Rein kosmetisch.
## Reagiert auf stage_changed und zone_unlocked der Sim; Dekor erscheint mit kleiner Pop-Animation.

signal critters_appeared(zone_id: String)

var _world: SimWorld
var _player: Node2D
var _cfg: Dictionary = {}
var _decor: Dictionary = {}     # zone id → {tile_key → Sprite2D}
var _critters: Dictionary = {}  # zone id → Array[CritterView]
var _textures: Dictionary = {}
var _plants: Dictionary = {}    # Vector2i → Sprite2D (Gras und Blumen auf geputzten Kacheln)

const DECOR_Z := -8


func bind(world: SimWorld, player: Node2D, cfg: Dictionary) -> void:
	_world = world
	_player = player
	_cfg = cfg
	for z in world.zones.summary(world.nodes):
		_refresh_zone(str(z["id"]), int(z["stage"]), false)
	world.zones.stage_changed.connect(func(id: String, st: int) -> void: _refresh_zone(id, st, true))
	world.zone_unlocked.connect(func(id: String) -> void: _refresh_zone(id, world.zones.stage(id, world.nodes), true))
	# Bereits geputzte Kacheln (Spielstand) sofort begrünen
	if world.dirt.is_active():
		for y in world.dirt.height:
			for x in world.dirt.width:
				var t := Vector2i(x, y)
				if world.dirt.is_green(t) and world.zones.is_unlocked(world.zones.zone_id_at(t)):
					_grow(t, false)


## Von DirtView: geputzte Kacheln bekommen nach kurzer Zeit vielleicht Gras oder Blumen,
## wieder verschmutzte verlieren sie.
func on_tiles_changed(tiles: Array) -> void:
	for t: Vector2i in tiles:
		var g := _world.dirt.is_green(t)
		if g:
			if not _plants.has(t):
				_grow(t, true)
		elif _plants.has(t):
			var s: Sprite2D = _plants[t]
			_plants.erase(t)
			if s != null:
				s.queue_free()


## Deterministisch je Kachel: ob und was wächst, Versatz und Verzögerung kommen aus einem Hash.
## Einstellungen einer Zone: Grundwerte aus nature.json, Pflanzen/Deko/Tiere aus dem Thema.
func _zone_cfg(zone_id: String) -> Dictionary:
	var th := DataRegistry.zone_theme(str(_world.zones.zone_by_id(zone_id).get("theme", "")))
	if th.is_empty():
		return _cfg
	var c := _cfg.duplicate()
	if th.has("plants"):
		var pt: Dictionary = th["plants"].duplicate()
		pt["delay_s"] = _cfg.get("per_tile", {}).get("delay_s", [0.6, 2.4])
		c["per_tile"] = pt
	for k in ["decor", "animals"]:
		if th.has(k):
			c[k] = th[k]
	return c


func _grow(t: Vector2i, animate: bool) -> void:
	var pt: Dictionary = _zone_cfg(_world.zones.zone_id_at(t)).get("per_tile", {})
	var h := absi(hash(t))
	var roll := float(h % 10000) / 10000.0
	var kind := ""
	var acc := 0.0
	var plant_kinds := pt.keys()
	plant_kinds.sort()
	for k in plant_kinds:
		if str(k) == "delay_s":
			continue
		acc += float(pt.get(k, 0.0))
		if roll < acc:
			kind = k
			break
	_plants[t] = null
	if kind == "":
		return
	var s := Sprite2D.new()
	s.texture = _tex(kind)
	s.position = Vector2(t * 64) + Vector2(32 + (h / 7 % 33) - 16, 32 + (h / 131 % 33) - 16)
	s.z_index = DECOR_Z
	s.flip_h = h % 2 == 0
	add_child(s)
	_plants[t] = s
	if animate:
		var d: Array = pt.get("delay_s", [1.0, 5.0])
		var delay := lerpf(float(d[0]), float(d[1]), float(h / 977 % 1000) / 1000.0)
		s.scale = Vector2.ZERO
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(s, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func plant_count() -> int:
	var n := 0
	for v in _plants.values():
		if v != null:
			n += 1
	return n


func _tex(kind: String) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind] = load("res://assets/sprites/nature/%s.svg" % kind)
	return _textures[kind]


func _occupied() -> Dictionary:
	var used := {}
	for n: ResourceNode in _world.nodes.values():
		for dx in 2:
			for dy in 2:
				used[n.tile + Vector2i(dx, dy)] = true
	for b: Building in _world.buildings.values():
		for dx in b.def.size.x:
			for dy in b.def.size.y:
				used[b.tile + Vector2i(dx, dy)] = true
	for t in _world.blocked_tiles.keys():
		used[t] = true
	# Büsche und Teiche nur auf geputztem Boden
	if _world.dirt.is_active():
		for y in _world.dirt.height:
			for x in _world.dirt.width:
				if _world.dirt.dirt[y * _world.dirt.width + x] > 0:
					used[Vector2i(x, y)] = true
	return used


func _refresh_zone(zone_id: String, stage: int, animate: bool) -> void:
	if not _world.zones.is_unlocked(zone_id):
		return
	var z := _world.zones.zone_by_id(zone_id)
	if z.is_empty():
		return
	var rect: Rect2i = z["rect"]
	var zcfg := _zone_cfg(zone_id)
	var plan := NaturePlanner.plan(rect, stage, NaturePlanner.zone_seed(zone_id), zcfg, _occupied())
	if not _decor.has(zone_id):
		_decor[zone_id] = {}
	var existing: Dictionary = _decor[zone_id]
	var wanted := {}
	var delay := 0.0
	for d in plan:
		var key := "%s:%d:%d" % [d["kind"], d["tile"].x, d["tile"].y]
		wanted[key] = true
		if existing.has(key):
			continue
		var s := Sprite2D.new()
		s.texture = _tex(str(d["kind"]))
		var size := NaturePlanner._footprint(str(d["kind"]), _cfg.get("decor_size", {}))
		s.position = Vector2(d["tile"] * 64) + Vector2(size * 64) * 0.5
		s.z_index = DECOR_Z
		s.flip_h = (d["tile"].x + d["tile"].y) % 2 == 0
		add_child(s)
		existing[key] = s
		if animate:
			s.scale = Vector2.ZERO
			delay = minf(delay + 0.02, 1.5)
			var tw := create_tween()
			tw.tween_interval(delay)
			tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Nicht mehr gewolltes Dekor (Stufe gesunken) verschwindet
	for key in existing.keys():
		if not wanted.has(key):
			var s: Sprite2D = existing[key]
			existing.erase(key)
			if animate:
				var tw := create_tween()
				tw.tween_property(s, "scale", Vector2.ZERO, 0.3)
				tw.tween_callback(s.queue_free)
			else:
				s.queue_free()
	_refresh_critters(zone_id, stage, rect, animate, zcfg)


func _refresh_critters(zone_id: String, stage: int, rect: Rect2i, animate: bool, zcfg: Dictionary = {}) -> void:
	var wanted: Dictionary = (zcfg if not zcfg.is_empty() else _cfg).get("animals", {}).get(str(stage), {})
	var speeds: Dictionary = _cfg.get("animal_speed", {})
	if not _critters.has(zone_id):
		_critters[zone_id] = []
	var list: Array = _critters[zone_id]
	var have := {}
	for c: CritterView in list:
		have[c.kind] = int(have.get(c.kind, 0)) + 1
	var rect_px := Rect2(Vector2(rect.position * 64), Vector2(rect.size * 64))
	var added := false
	var seed_base := NaturePlanner.zone_seed(zone_id)
	for kind in wanted.keys():
		var need := int(wanted[kind]) - int(have.get(kind, 0))
		for i in maxi(need, 0):
			var c := CritterView.new()
			c.setup(str(kind), rect_px, float(speeds.get(kind, 60)), _player, seed_base + list.size() * 31 + i)
			add_child(c)
			list.append(c)
			added = true
	# Zu viele (Stufe gesunken): entfernen
	for c: CritterView in list.duplicate():
		if int(wanted.get(c.kind, 0)) < int(have.get(c.kind, 0)):
			have[c.kind] = int(have[c.kind]) - 1
			list.erase(c)
			c.queue_free()
	if added and animate:
		critters_appeared.emit(zone_id)


## Anzahl Dekor-Objekte (Debug/Tests).
func decor_count() -> int:
	var n := 0
	for z in _decor.values():
		n += z.size()
	return n


func critter_count() -> int:
	var n := 0
	for l in _critters.values():
		n += l.size()
	return n
