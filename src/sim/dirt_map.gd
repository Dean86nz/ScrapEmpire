class_name DirtMap
extends RefCounted
## Schmutz je Kachel (0 = sauber, 255 = sehr schmutzig) und welche Kacheln anfangs schmutzig waren.
## Sauberkeit einer Zone = geputzte / anfangs schmutzige Kacheln. Rein deterministisch:
## Erzeugung aus Karten-Seed und Müll-Positionen, Putzen über die Werkzeuge der Simulation.

var width := 0
var height := 0
var dirt := PackedByteArray()     # aktueller Schmutz je Kachel
var start := PackedByteArray()    # 1 = war beim Start schmutzig (dort wächst später Gras)
var green := PackedByteArray()    # 1 = Wiese (geputzt, von der Schiffswelle geheilt, Zone sauber)
var cfg: Dictionary = {}
var zone_start: Dictionary = {}   # zone_id → anfangs schmutzige Kacheln
var zone_now: Dictionary = {}     # zone_id → noch schmutzige Kacheln
var cleaned_total := 0            # insgesamt sauber geputzte Kacheln (für Kleinschrott)
var changed: Array[Vector2i] = [] # seit der letzten Abfrage geänderte Kacheln (für die Darstellung)
var _zones: ZoneTracker


static func load_config(path: String = "res://data/dirt.json") -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


func is_active() -> bool:
	return width > 0


func _idx(t: Vector2i) -> int:
	return t.y * width + t.x


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < width and t.y < height


func value(t: Vector2i) -> int:
	return dirt[_idx(t)] if in_bounds(t) else 0


func is_green(t: Vector2i) -> bool:
	return in_bounds(t) and green[_idx(t)] == 1


## Macht eine saubere Kachel zur Wiese. true, wenn sich etwas geändert hat.
func heal(t: Vector2i) -> bool:
	if not in_bounds(t):
		return false
	var i := _idx(t)
	if dirt[i] != 0 or green[i] == 1:
		return false
	green[i] = 1
	changed.append(t)
	return true


## Alle sauberen Kacheln eines Rechtecks werden Wiese (Zone ist sauber).
func heal_rect(r: Rect2i) -> int:
	var n := 0
	for y in range(maxi(r.position.y, 0), mini(r.end.y, height)):
		for x in range(maxi(r.position.x, 0), mini(r.end.x, width)):
			if heal(Vector2i(x, y)):
				n += 1
	return n


func was_dirty(t: Vector2i) -> bool:
	return in_bounds(t) and start[_idx(t)] == 1


## Erzeugt den Startschmutz: fleckiger Grundschmutz (Wertrauschen) plus volle Verschmutzung um Müll.
## Das Umfeld des Schiffs bleibt sauber, damit man sieht, wo das Freiputzen beginnt.
func generate(w: int, h: int, zones: ZoneTracker, trash_tiles: Array, ship_center: Vector2i, seed_value: int, p_cfg: Dictionary) -> void:
	width = w
	height = h
	cfg = p_cfg
	_zones = zones
	dirt = PackedByteArray()
	dirt.resize(w * h)
	start = PackedByteArray()
	start.resize(w * h)
	green = PackedByteArray()
	green.resize(w * h)
	var coverage := float(cfg.get("coverage", 0.55))
	var scale := float(cfg.get("noise_scale", 5.0))
	var dmin := int(cfg.get("dirt_min", 120))
	var dmax := int(cfg.get("dirt_max", 230))
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	noise.frequency = 1.0 / maxf(scale, 1.0)
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if zones.zone_id_at(t) == "":
				continue
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5   # 0..1
			if n < coverage:
				dirt[_idx(t)] = clampi(int(lerpf(dmax, dmin, n / maxf(coverage, 0.01))), 1, 255)
	var r := int(cfg.get("trash_radius", 2))
	var full := int(cfg.get("trash_dirt", 255))
	for tt in trash_tiles:
		var c: Vector2i = tt
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := c + Vector2i(dx, dy)
				if in_bounds(t) and zones.zone_id_at(t) != "" and Vector2(dx, dy).length() <= r + 0.5:
					dirt[_idx(t)] = maxi(dirt[_idx(t)], full - (absi(dx) + absi(dy)) * 20)
	# Einzelne saubere Kacheln mitten im Schmutz auffüllen (sähen wie Sternchen aus)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			if dirt[i] == 0 and zones.zone_id_at(Vector2i(x, y)) != "":
				var dirty_n := 0
				var sum := 0
				for o in [-1, 1, -w, w]:
					if dirt[i + o] > 0:
						dirty_n += 1
						sum += dirt[i + o]
				if dirty_n >= 3:
					dirt[i] = sum / dirty_n
	if ship_center.x >= 0:
		var sr := int(cfg.get("ship_clean_radius", 4))
		for dy in range(-sr, sr + 1):
			for dx in range(-sr, sr + 1):
				var t := ship_center + Vector2i(dx, dy)
				if in_bounds(t) and Vector2(dx, dy).length() <= sr + 0.5:
					dirt[_idx(t)] = 0
					green[_idx(t)] = 1
	for i in dirt.size():
		start[i] = 1 if dirt[i] > 0 else 0
	_recount()


func _recount() -> void:
	zone_start.clear()
	zone_now.clear()
	for z in _zones.zones:
		zone_start[z["id"]] = 0
		zone_now[z["id"]] = 0
	for z in _zones.zones:
		var rect: Rect2i = z["rect"]
		var s := 0
		var n := 0
		for y in range(rect.position.y, mini(rect.end.y, height)):
			for x in range(rect.position.x, mini(rect.end.x, width)):
				var i := y * width + x
				if start[i] == 1:
					s += 1
				if dirt[i] > 0:
					n += 1
		zone_start[z["id"]] = s
		zone_now[z["id"]] = n


## Putzt eine Kachel um `amount`. true, wenn sie dadurch sauber wurde.
func clean(t: Vector2i, amount: int) -> bool:
	if not in_bounds(t):
		return false
	var i := _idx(t)
	var v := dirt[i]
	if v == 0:
		return false
	var nv := maxi(v - amount, 0)
	dirt[i] = nv
	changed.append(t)
	if nv == 0:
		green[i] = 1
		var zid := _zones.zone_id_at(t)
		if zone_now.has(zid):
			zone_now[zid] = maxi(int(zone_now[zid]) - 1, 0)
		cleaned_total += 1
		return true
	return false


## Neu verschmutzen (Müll respawnt).
func soil(t: Vector2i, amount: int) -> void:
	if not in_bounds(t):
		return
	var i := _idx(t)
	if dirt[i] == 0 and amount > 0:
		var zid := _zones.zone_id_at(t)
		if zone_now.has(zid):
			zone_now[zid] = int(zone_now[zid]) + 1
		if start[i] == 0:
			start[i] = 1
			if zone_start.has(zid):
				zone_start[zid] = int(zone_start[zid]) + 1
	dirt[i] = maxi(dirt[i], amount)
	if amount > 0:
		green[i] = 0
	changed.append(t)


## Anteil sauberer Fläche einer Zone (0..1); -1, wenn die Zone keinen Schmutz kennt.
func zone_cleanliness(zone_id: String) -> float:
	var s := int(zone_start.get(zone_id, 0))
	if s <= 0:
		return -1.0
	return clampf(1.0 - float(zone_now.get(zone_id, 0)) / float(s), 0.0, 1.0)


func planet_cleanliness() -> float:
	var s := 0
	var n := 0
	for k in zone_start:
		s += int(zone_start[k])
		n += int(zone_now.get(k, 0))
	return 1.0 if s <= 0 else clampf(1.0 - float(n) / float(s), 0.0, 1.0)


func take_changed() -> Array[Vector2i]:
	var c := changed
	changed = []
	return c


func to_dict() -> Dictionary:
	if not is_active():
		return {}
	return {"w": width, "h": height, "dirt": Marshalls.raw_to_base64(dirt.compress(FileAccess.COMPRESSION_DEFLATE)),
		"start": Marshalls.raw_to_base64(start.compress(FileAccess.COMPRESSION_DEFLATE)), "cleaned": cleaned_total,
		"green": Marshalls.raw_to_base64(green.compress(FileAccess.COMPRESSION_DEFLATE))}


func from_dict(d: Dictionary, zones: ZoneTracker, p_cfg: Dictionary) -> bool:
	var w := int(d.get("w", 0))
	var h := int(d.get("h", 0))
	if w <= 0 or h <= 0:
		return false
	var a := Marshalls.base64_to_raw(str(d.get("dirt", ""))).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	var b := Marshalls.base64_to_raw(str(d.get("start", ""))).decompress(w * h, FileAccess.COMPRESSION_DEFLATE)
	if a.size() != w * h or b.size() != w * h:
		return false
	width = w
	height = h
	dirt = a
	start = b
	var g := Marshalls.base64_to_raw(str(d.get("green", ""))).decompress(w * h, FileAccess.COMPRESSION_DEFLATE) if d.has("green") else PackedByteArray()
	if g.size() != w * h:
		# Ältere Stände: geputzte, anfangs schmutzige Kacheln sind Wiese
		g = PackedByteArray()
		g.resize(w * h)
		for i in w * h:
			g[i] = 1 if start[i] == 1 and dirt[i] == 0 else 0
	green = g
	cfg = p_cfg
	_zones = zones
	cleaned_total = int(d.get("cleaned", 0))
	_recount()
	return true
