class_name Conveyor
extends Building
## Förderband (1×1). Items liegen als {item, offset} mit offset 0..255 (1/256 Kachel),
## vorderstes Item zuerst. rot ist die Laufrichtung (0 rechts, 1 unten, 2 links, 3 oben).

const LEN := 256
const SPACING := 64
const SPEED := 26          # ≈ 2 Kacheln/s bei 20 Ticks/s
const SIDE_OFFSET := 128   # Seiteneinspeisung

enum Shape { STRAIGHT, TURN_FROM_LEFT, TURN_FROM_RIGHT }

const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var items: Array[Dictionary] = []
var shape: Shape = Shape.STRAIGHT


func dir() -> Vector2i:
	return DIRS[posmod(rot, 4)]


## Seite links der Laufrichtung (im Bildschirm-Koordinatensystem, y nach unten).
func left_dir() -> Vector2i:
	var d := dir()
	return Vector2i(d.y, -d.x)


func right_dir() -> Vector2i:
	var d := dir()
	return Vector2i(-d.y, d.x)


func front_tile() -> Vector2i:
	return tile + dir()


func back_tile() -> Vector2i:
	return tile - dir()


func rear_free() -> bool:
	return items.is_empty() or int(items.back()["offset"]) >= SPACING


func has_room_at(offset: int) -> bool:
	for it in items:
		if absi(int(it["offset"]) - offset) < SPACING:
			return false
	return true


## Fügt ein Item bei `offset` ein, wenn Platz ist. Hält die Sortierung (vorne zuerst).
func try_insert(item_id: String, offset: int) -> bool:
	if not has_room_at(offset):
		return false
	var entry := {"item": item_id, "offset": offset}
	var i := 0
	while i < items.size() and int(items[i]["offset"]) > offset:
		i += 1
	items.insert(i, entry)
	return true


func front_item() -> Dictionary:
	return items[0] if not items.is_empty() else {}


## True, wenn das vorderste Item in diesem Tick das Bandende erreichen würde.
func front_wants_transfer() -> bool:
	return not items.is_empty() and int(items[0]["offset"]) + SPEED >= LEN


func pop_front() -> String:
	if items.is_empty():
		return ""
	return str(items.pop_front()["item"])


## Bewegt alle Items; das vorderste bleibt bei 255 stehen, Nachfolger halten Abstand.
func advance() -> void:
	var limit := LEN - 1
	for it in items:
		var o := mini(int(it["offset"]) + SPEED, limit)
		it["offset"] = o
		limit = o - SPACING


# --- Building-Schnittstelle (Spieler legt per A ein Item auf das Band / nimmt vorne eines) ---

func accept_stack(item_id: String, _count: int) -> int:
	return 1 if try_insert(item_id, 0) else 0


func withdraw_stack() -> Dictionary:
	var item := pop_front()
	return {"item": item, "count": 1} if item != "" else {}


func contents() -> Dictionary:
	var result: Dictionary = {}
	for it in items:
		result[it["item"]] = result.get(it["item"], 0) + 1
	return result


func summary() -> Dictionary:
	return {"shape": shape, "count": items.size()}
