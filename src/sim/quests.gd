class_name QuestState
extends RefCounted
## Geführte Aufgabenkette aus data/quests.json: immer genau eine aktive Aufgabe.
## Zähler (gesammelt, verkauft, zerlegt, abgeliefert, gelaufen) füllt die Welt über Signale.
## Zustandsprüfungen (gebaut, erforscht, Band zum Schiff, Zone, Schiffstufe) laufen gegen die Welt.

signal completed(id: String, def: Dictionary)
signal progress_changed

var defs: Array = []
var index := 0
var counters: Dictionary = {}   # "collect:scrap", "ship_delivered", "sold_value", "wrecks", "moved_px"
var _last_pos := Vector2i(-1, -1)
var _last_progress := -1


static func load_defs(path: String = "res://data/quests.json") -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed.get("quests", []) if parsed is Dictionary else []


func setup(p_defs: Array) -> void:
	defs = p_defs


func is_done() -> bool:
	return index >= defs.size()


func current() -> Dictionary:
	return defs[index] if index < defs.size() else {}


func total() -> int:
	return defs.size()


# --- Zähler -----------------------------------------------------------------

func _add(key: String, n: int) -> void:
	counters[key] = int(counters.get(key, 0)) + n


func on_collected(item: String) -> void:
	_add("collect:" + item, 1)


func on_sold(value: int) -> void:
	_add("sold_value", value)


func on_wreck() -> void:
	_add("wrecks", 1)


func on_ship_received(n: int) -> void:
	_add("ship_delivered", n)


func on_delivery() -> void:
	_add("deliveries", 1)




func on_courier() -> void:
	_add("courier_pickups", 1)


func tick_move(pos: Vector2i) -> void:
	if _last_pos.x >= 0:
		var d := int(Vector2(pos - _last_pos).length())
		if d > 0 and d < 400:  # Teleport (Laden, Cheats) nicht zählen
			_add("moved_px", d)
	_last_pos = pos


# --- Bewertung ----------------------------------------------------------------

## [ist, soll] der aktuellen Aufgabe; soll = 1 bei Ja/Nein-Aufgaben.
func progress(w: SimWorld) -> Array:
	var q := current()
	if q.is_empty():
		return [0, 1]
	var amount := int(q.get("amount", 1))
	match str(q.get("type", "")):
		"moved":
			return [mini(int(counters.get("moved_px", 0)), amount), amount]
		"collect":
			return [mini(int(counters.get("collect:" + str(q.get("item", "")), 0)), amount), amount]
		"ship_delivered":
			return [mini(int(counters.get("ship_delivered", 0)), amount), amount]
		"deliveries":
			return [mini(int(counters.get("deliveries", 0)), amount), amount]
		"courier_pickups":
			return [mini(int(counters.get("courier_pickups", 0)), amount), amount]
		"cleaned":
			return [mini(w.dirt.cleaned_total, amount), amount]
		"sold_value":
			return [mini(int(counters.get("sold_value", 0)), amount), amount]
		"wrecks":
			return [mini(int(counters.get("wrecks", 0)), amount), amount]
		"bolts_earned":
			return [mini(int(counters.get("sold_value", 0)), amount), amount]
		"skills_bought":
			return [mini(w.skills.total_bought(), amount), amount]
		"skill_level":
			return [mini(w.skills.level_of(str(q.get("skill", ""))), amount), amount]
		"upgrades_bought":
			return [mini(ShipSystem.upgrades_total(w), amount), amount]
		"upgrade_level":
			return [mini(ShipSystem.upgrade_level(w, str(q.get("upgrade", ""))), amount), amount]
		"build":
			return [mini(w.building_count(str(q.get("def", ""))), amount), amount]
		"zone_gate":
			var cur := w.zones.current_chapter_zone()
			var pct := int(round(w.zones.cleanliness(cur, w.nodes) * 100.0)) if cur != "" else 100
			var goal := int(round(w.zones.unlock_cleanliness * 100.0))
			if cur != "" and w.zones.boss_alive(cur, w.nodes):
				pct = mini(pct, goal - 1)  # erst der Boss, dann geht das Tor auf
			return [mini(pct, goal), goal]
		"bosses":
			var beaten := 0
			for k: String in w.flags:
				if k.begins_with("boss_"):
					beaten += 1
			return [mini(beaten, amount), amount]
		"flag":
			return [1 if w.flags.has(str(q.get("flag", ""))) else 0, 1]
		"zone_clean":
			var pct2 := int(round(w.zones.cleanliness(str(q.get("zone", "")), w.nodes) * 100.0))
			return [mini(pct2, amount), amount]
		"ship_stage":
			var s := ShipSystem.ship(w)
			return [mini(s.stage if s != null else 0, amount), amount]
		"helpers":
			return [mini(w.helpers.size(), amount), amount]
		"drones":
			return [mini(w.drones.size(), amount), amount]
		"collectibles":
			return [mini(w.collectibles_found.size(), amount), amount]
		"planet":
			return [mini(int(round(w.zones.planet_health(w.nodes) * 100.0)), amount), amount]
		"level":
			return [mini(w.progression.level, amount), amount]
	return [0, 1]


func is_satisfied(w: SimWorld) -> bool:
	var p := progress(w)
	return int(p[0]) >= int(p[1])


## Prüft die aktuelle Aufgabe; schließt sie ab (Belohnung, Signal). true, wenn abgeschlossen.
func check(w: SimWorld) -> bool:
	if is_done():
		return false
	var p := progress(w)
	if int(p[0]) != _last_progress:
		_last_progress = int(p[0])
		progress_changed.emit()
	if int(p[0]) < int(p[1]):
		return false
	var q := current()
	w.progression.add_xp(int(q.get("xp", 0)))
	var bonus := int(q.get("bolts", 0))
	if bonus > 0:
		w.bolts += bonus
		w.bolts_changed.emit(w.bolts)
	index += 1
	_last_progress = -1
	completed.emit(str(q.get("id", "")), q)
	return true


## Für alte Spielstände: bereits erfüllte Aufgaben still überspringen; Tutorial-Aufgaben gelten
## als erledigt, wenn das alte Tutorial abgeschlossen war.
func fast_forward(w: SimWorld, tutorial_done: bool) -> int:
	var skipped := 0
	while not is_done():
		var q := current()
		if (tutorial_done and bool(q.get("tutorial", false))) or is_satisfied(w):
			index += 1
			skipped += 1
		else:
			break
	return skipped


func to_dict() -> Dictionary:
	return {"index": index, "current": str(current().get("id", "")), "counters": counters.duplicate()}


func from_dict(d: Dictionary) -> void:
	index = int(d.get("index", 0))
	# Über die ID wiederfinden, damit neu eingefügte Aufgaben alte Stände nicht verschieben
	var cur := str(d.get("current", ""))
	if cur != "":
		for i in defs.size():
			if str(defs[i].get("id", "")) == cur:
				index = i
				break
	counters = {}
	for k in d.get("counters", {}):
		counters[str(k)] = int(d["counters"][k])
