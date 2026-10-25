class_name Drone
extends RefCounted
## Logistik-Drohne: fliegt zwischen Quelle (Kiste/Maschine) und Ziel (Kiste/Maschine/Terminal),
## nimmt bis zur Tragkraft ein Item, liefert ab. Optional Material-Filter und Limit („auffüllen bis N im Ziel“).
## Fliegt über alles hinweg (keine Kollision). Deterministisch, rein tickbasiert.

enum State { TO_SOURCE, TO_TARGET, WAIT }

const TILE := 64
const WAIT_TICKS := 60  # 3 s Pause, wenn Quelle leer, Ziel voll oder Limit erreicht

var id: int
var source_id: int = -1
var target_id: int = -1
var item_filter := ""      # "" = alles
var limit := 0             # 0 = kein Limit
var pos := Vector2i.ZERO
var carry_item := ""
var carry_count := 0
var capacity := 10
var speed_px_per_tick := 8
var state := State.TO_SOURCE
var wait_ticks := 0
var wait_reason := ""      # "", "source_empty", "target_full", "limit", "missing"
var trips := 0


func apply_modifiers(m: Dictionary, base_speed_px_per_s: int, base_capacity: int) -> void:
	speed_px_per_tick = maxi(int(round(base_speed_px_per_s * float(m.get("drone_speed_mult", 1.0)) / 20.0)), 1)
	capacity = base_capacity + int(m.get("drone_capacity_add", 0))


func is_carrying() -> bool:
	return carry_count > 0


func tick(world: SimWorld) -> void:
	var src: Building = world.buildings.get(source_id)
	var dst: Building = world.buildings.get(target_id)
	if src == null or dst == null:
		state = State.WAIT
		wait_reason = "missing"
		return
	if state == State.WAIT:
		wait_ticks -= 1
		if wait_ticks > 0:
			return
		state = State.TO_TARGET if is_carrying() else State.TO_SOURCE
		wait_reason = ""
	var goal: Vector2i = (dst if state == State.TO_TARGET else src).center_px()
	if _fly_to(goal):
		if state == State.TO_SOURCE:
			_load_from(src)
			if is_carrying():
				state = State.TO_TARGET
			else:
				_wait("source_empty")
		else:
			_unload_into(world, dst)
			if not is_carrying():
				trips += 1
				state = State.TO_SOURCE
			elif state != State.WAIT:
				_wait("target_full")


func _wait(reason: String) -> void:
	state = State.WAIT
	wait_ticks = WAIT_TICKS
	wait_reason = reason


## true, wenn angekommen.
func _fly_to(goal: Vector2i) -> bool:
	var d := Vector2(goal - pos)
	if d.length() <= speed_px_per_tick:
		pos = goal
		return true
	pos += Vector2i((d.normalized() * speed_px_per_tick).round())
	return false


## Nimmt ein Item-Stapel aus der Quelle: Kiste (beliebiger Slot bzw. Filter), Maschine (nur Ausgang).
func _load_from(src: Building) -> void:
	var want := capacity - carry_count
	if want <= 0:
		return
	if src is Chest:
		var inv: Inventory = (src as Chest).inventory
		var item := carry_item if is_carrying() else _pick_item(inv_contents(inv))
		if item == "":
			return
		var taken := inv.remove(item, want)
		_add_carry(item, taken)
	elif src is Ship:
		var sinv: Inventory = (src as Ship).storage
		var sitem := carry_item if is_carrying() else _pick_item(inv_contents(sinv))
		if sitem == "":
			return
		_add_carry(sitem, sinv.remove(sitem, want))
	elif src is Machine:
		var m := src as Machine
		var item := carry_item if is_carrying() else _pick_item(m.output)
		if item == "" or not m.output.has(item):
			return
		var taken := mini(int(m.output[item]), want)
		m.output[item] = int(m.output[item]) - taken
		if int(m.output[item]) <= 0:
			m.output.erase(item)
		_add_carry(item, taken)


static func inv_contents(inv: Inventory) -> Dictionary:
	var result: Dictionary = {}
	for s in inv.slots:
		if s["item"] != "":
			result[s["item"]] = int(result.get(s["item"], 0)) + int(s["count"])
	return result


func _pick_item(contents: Dictionary) -> String:
	if item_filter != "":
		return item_filter if int(contents.get(item_filter, 0)) > 0 else ""
	for item in contents.keys():
		if int(contents[item]) > 0:
			return str(item)
	return ""


func _add_carry(item: String, n: int) -> void:
	if n <= 0:
		return
	carry_item = item
	carry_count += n


## Liefert ab; beachtet Limit (Zielbestand des Items) und was das Ziel annimmt.
func _unload_into(world: SimWorld, dst: Building) -> void:
	if not is_carrying():
		return
	var allowed := carry_count
	if limit > 0 and dst.has_method("contents"):
		var have := int(dst.contents().get(carry_item, 0))
		allowed = mini(allowed, maxi(limit - have, 0))
		if allowed <= 0:
			_wait("limit")
			return
	if dst is Machine and not (dst as Machine).accepts_item(carry_item):
		_wait("target_full")
		return
	if not dst.has_method("accept_stack"):
		_wait("target_full")
		return
	var accepted: int = dst.accept_stack(carry_item, allowed)
	if accepted > 0 and dst is Ship:
		world.ship_received.emit(carry_item, accepted)
	carry_count -= accepted
	if carry_count <= 0:
		carry_count = 0
		carry_item = ""


## Quelle und Ziel werden als Kacheln gespeichert, weil Gebäude-IDs beim Laden neu vergeben werden.
func to_dict(world: SimWorld) -> Dictionary:
	var src: Building = world.buildings.get(source_id)
	var dst: Building = world.buildings.get(target_id)
	return {
		"source_tile": [src.tile.x, src.tile.y] if src != null else [-1, -1],
		"target_tile": [dst.tile.x, dst.tile.y] if dst != null else [-1, -1],
		"filter": item_filter, "limit": limit,
		"pos": [pos.x, pos.y], "carry_item": carry_item, "carry_count": carry_count,
		"state": int(state), "wait_ticks": wait_ticks, "trips": trips,
	}


func from_dict(d: Dictionary) -> void:
	item_filter = str(d.get("filter", ""))
	limit = int(d.get("limit", 0))
	pos = SaveCodec.to_v2(d.get("pos"))
	carry_item = str(d.get("carry_item", ""))
	carry_count = int(d.get("carry_count", 0))
	state = int(d.get("state", 0)) as State
	wait_ticks = int(d.get("wait_ticks", 0))
	trips = int(d.get("trips", 0))
