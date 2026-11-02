class_name TrashCube
extends RefCounted
## Müllwürfel im Flug (MS77): ein Streuner presst seine Ladung und schießt sie im Bogen zu einem
## Fangtrichter. Die Sim kennt nur Start, Ziel und Flugzeit; den Bogen zeichnet die Ansicht.

var id: int
var items: Dictionary = {}     # item → Menge
var from := Vector2i.ZERO
var to := Vector2i.ZERO
var hopper_id := -1
var t := 0
var dur := 20


func count() -> int:
	var n := 0
	for k in items:
		n += int(items[k])
	return n


func to_dict() -> Dictionary:
	return {"items": items.duplicate(), "from": [from.x, from.y], "to": [to.x, to.y], "hopper": hopper_id, "t": t, "dur": dur}


func from_dict(d: Dictionary) -> void:
	for k in d.get("items", {}):
		items[str(k)] = int(d["items"][k])
	from = SaveCodec.to_v2(d.get("from"))
	to = SaveCodec.to_v2(d.get("to"))
	hopper_id = int(d.get("hopper", -1))
	t = int(d.get("t", 0))
	dur = maxi(1, int(d.get("dur", 20)))
