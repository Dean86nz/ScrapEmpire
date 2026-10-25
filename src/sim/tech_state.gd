class_name TechState
extends RefCounted
## Techbaum: Knoten aus data/tech.json, Forschung kostet Bolts (+ Items) sofort und dauert
## Zeit (nur bei laufendem Spiel). Nur eine Forschung gleichzeitig.

signal research_started(id: String, ticks: int)
signal research_progress(id: String, remaining: int, total: int)
signal tech_unlocked(id: String)

const TICKS_PER_SECOND := 20

var defs: Array = []            # Array[Dictionary], Dateireihenfolge
var by_id: Dictionary = {}
var unlocked: Dictionary = {}   # id → true
var current_id := ""
var remaining_ticks := 0
var total_ticks := 0


static func load_defs(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if parsed == null or not (parsed is Dictionary):
		push_error("tech.json nicht lesbar: " + path)
		return []
	return parsed.get("tech", [])


func setup(p_defs: Array) -> void:
	defs = p_defs
	by_id.clear()
	for d: Dictionary in defs:
		by_id[str(d["id"])] = d
	# Gratis-Knoten ohne Zeit (Verkaufsterminal) sind von Anfang an frei.
	for d: Dictionary in defs:
		if int(d.get("cost_bolts", 0)) == 0 and float(d.get("time_s", 0)) == 0.0 and _requirements_met(d):
			unlocked[str(d["id"])] = true


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func is_researching() -> bool:
	return current_id != ""


func _requirements_met(d: Dictionary) -> bool:
	for r in d.get("requires", []):
		if not unlocked.has(str(r)):
			return false
	return true


## "" wenn startbar, sonst Grund: unknown, done, busy, requires, bolts, items
func can_start(id: String, bolts: int, inventory: Inventory) -> String:
	if not by_id.has(id):
		return "unknown"
	if unlocked.has(id):
		return "done"
	if is_researching():
		return "busy"
	var d: Dictionary = by_id[id]
	if not _requirements_met(d):
		return "requires"
	if bolts < int(d.get("cost_bolts", 0)):
		return "bolts"
	for item in d.get("cost_items", {}):
		if inventory.count_of(str(item)) < int(d["cost_items"][item]):
			return "items"
	return ""


## Startet die Forschung; der Aufrufer hat Bolts/Items bereits geprüft und bezahlt.
func start(id: String) -> void:
	var d: Dictionary = by_id[id]
	current_id = id
	total_ticks = maxi(int(float(d.get("time_s", 0)) * TICKS_PER_SECOND), 1)
	remaining_ticks = total_ticks
	research_started.emit(id, total_ticks)


## Liefert die id, wenn in diesem Tick eine Forschung fertig wurde, sonst "".
func tick() -> String:
	if current_id == "":
		return ""
	remaining_ticks -= 1
	if remaining_ticks > 0:
		if remaining_ticks % 5 == 0:
			research_progress.emit(current_id, remaining_ticks, total_ticks)
		return ""
	var done := current_id
	current_id = ""
	remaining_ticks = 0
	unlocked[done] = true
	tech_unlocked.emit(done)
	return done


func progress_fraction() -> float:
	if current_id == "" or total_ticks <= 0:
		return 0.0
	return 1.0 - float(remaining_ticks) / float(total_ticks)


## Alle Knoten, deren Voraussetzungen erfüllt, aber noch nicht erforscht sind.
func available() -> Array[String]:
	var result: Array[String] = []
	for d: Dictionary in defs:
		var id := str(d["id"])
		if not unlocked.has(id) and _requirements_met(d):
			result.append(id)
	return result


func effects_of(id: String) -> Array:
	return by_id.get(id, {}).get("effects", [])


func to_dict() -> Dictionary:
	return {"unlocked": unlocked.keys(), "current": current_id, "remaining_ticks": remaining_ticks, "total_ticks": total_ticks}
