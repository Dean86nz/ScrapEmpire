class_name Courier
extends RefCounted
## Kurier (MS34): kleine Lastdrohne vom Schiff. Fliegt zu Rusty, nimmt ihm die Ladung ab und bringt
## sie zur nächsten Sammelstelle oder zum Schiff; dann fliegt er heim und verschwindet. Rusty
## arbeitet dabei weiter. Deterministisch, rein tickbasiert.

enum State { TO_PLAYER, TO_DEPOT, HOME }

const ARRIVE_PX := 28

var id: int
var pos := Vector2i.ZERO
var home := Vector2i.ZERO
var state := State.TO_PLAYER
var carry: Dictionary = {}
var load_max := 40            # 0 = alles
var speed_px_per_tick := 18
var depot_id := -1


func carry_total() -> int:
	var n := 0
	for k in carry:
		n += int(carry[k])
	return n


## true, wenn angekommen.
func fly_to(goal: Vector2i) -> bool:
	var d := Vector2(goal - pos)
	if d.length() <= maxf(speed_px_per_tick, ARRIVE_PX):
		pos = goal
		return true
	pos += Vector2i((d.normalized() * speed_px_per_tick).round())
	return false


func to_dict() -> Dictionary:
	return {"pos": [pos.x, pos.y], "home": [home.x, home.y], "state": int(state), "carry": carry.duplicate(),
		"load": load_max, "speed": speed_px_per_tick, "depot": depot_id}


func from_dict(d: Dictionary) -> void:
	pos = SaveCodec.to_v2(d.get("pos"))
	home = SaveCodec.to_v2(d.get("home"))
	state = int(d.get("state", 0)) as State
	carry = {}
	for k in d.get("carry", {}):
		carry[str(k)] = int(d["carry"][k])
	load_max = int(d.get("load", 40))
	speed_px_per_tick = int(d.get("speed", 18))
	depot_id = int(d.get("depot", -1))
