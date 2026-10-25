class_name Inventory
extends RefCounted
## Slot-Inventar: feste Slot-Anzahl, feste Stapelgröße je Slot.
## Leerer Slot: {"item": "", "count": 0}.

signal changed

var slot_count: int
var stack_size: int
var slots: Array[Dictionary] = []


func _init(p_slot_count: int = 6, p_stack_size: int = 20) -> void:
	slot_count = p_slot_count
	stack_size = p_stack_size
	for i in slot_count:
		slots.append({"item": "", "count": 0})


## Fügt bis zu `count` Stück hinzu. Liefert den Rest, der nicht mehr passte.
func add(item_id: String, count: int) -> int:
	var remaining := count
	for s in slots:
		if remaining == 0:
			break
		if s["item"] == item_id and s["count"] < stack_size:
			var take: int = mini(stack_size - s["count"], remaining)
			s["count"] += take
			remaining -= take
	for s in slots:
		if remaining == 0:
			break
		if s["item"] == "":
			var take: int = mini(stack_size, remaining)
			s["item"] = item_id
			s["count"] = take
			remaining -= take
	if remaining != count:
		changed.emit()
	return remaining


## Entfernt bis zu `count` Stück (von hinten nach vorne). Liefert die entfernte Menge.
func remove(item_id: String, count: int) -> int:
	var removed := 0
	for i in range(slots.size() - 1, -1, -1):
		if removed == count:
			break
		var s := slots[i]
		if s["item"] != item_id:
			continue
		var take: int = mini(s["count"], count - removed)
		s["count"] -= take
		removed += take
		if s["count"] == 0:
			s["item"] = ""
	if removed > 0:
		changed.emit()
	return removed


func count_of(item_id: String) -> int:
	var n := 0
	for s in slots:
		if s["item"] == item_id:
			n += s["count"]
	return n


func total() -> int:
	var n := 0
	for s in slots:
		n += s["count"]
	return n


## True, wenn mindestens ein Stück dieses Items noch Platz findet.
func can_add(item_id: String) -> bool:
	for s in slots:
		if s["item"] == "" or (s["item"] == item_id and s["count"] < stack_size):
			return true
	return false


## True, wenn kein Slot irgendein Item mehr aufnehmen kann.
func is_full() -> bool:
	for s in slots:
		if s["item"] == "" or s["count"] < stack_size:
			return false
	return true


## Vergrößert Slots und/oder Stapelgröße (nie verkleinern; Inhalt bleibt erhalten).
func resize(new_slots: int, new_stack: int) -> void:
	slot_count = maxi(new_slots, slot_count)
	stack_size = maxi(new_stack, stack_size)
	while slots.size() < slot_count:
		slots.append({"item": "", "count": 0})
	changed.emit()


func to_dict() -> Dictionary:
	return {"slot_count": slot_count, "stack_size": stack_size, "slots": slots.duplicate(true)}
