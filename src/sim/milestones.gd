class_name MilestoneState
extends RefCounted
## Meilensteine aus data/milestones.json: Zählerstände mit Stufen (z. B. 100 / 1.000 / 10.000 Schrott).
## Jede erreichte Stufe gibt Bolts und XP und meldet sich einmal. Liest Zähler aus QuestState,
## Schmutzkarte und Schiff; speichert nur, wie viele Stufen je Meilenstein erreicht sind.

signal reached(def: Dictionary, step: int, value: int, bolts: int)

var defs: Array = []
var done: Dictionary = {}   # id → Anzahl erreichter Stufen


static func load_defs(path: String = "res://data/milestones.json") -> Array:
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	return parsed.get("milestones", []) if parsed is Dictionary else []


func setup(p_defs: Array) -> void:
	defs = p_defs


## Aktueller Zählerstand eines Meilensteins.
static func stat(w: SimWorld, name: String) -> int:
	var c: Dictionary = w.quests.counters
	match name:
		"collected":
			var n := 0
			for k: String in c:
				if k.begins_with("collect:"):
					n += int(c[k])
			return n
		"bolts_earned":
			return int(c.get("sold_value", 0))
		"cleaned":
			return w.dirt.cleaned_total
		"wrecks":
			return int(c.get("wrecks", 0))
		"deliveries":
			return int(c.get("deliveries", 0))
		"upgrades":
			return ShipSystem.upgrades_total(w) + w.skills.total_bought()
	return 0


func steps_done(id: String) -> int:
	return int(done.get(id, 0))


## Nächste Schwelle oder -1, wenn alle Stufen erreicht sind.
func next_step(def: Dictionary) -> int:
	var steps: Array = def.get("steps", [])
	var i := steps_done(str(def["id"]))
	return int(steps[i]) if i < steps.size() else -1


## Prüft alle Meilensteine; vergibt Belohnungen. Gibt die Zahl neu erreichter Stufen zurück.
func check(w: SimWorld, silent: bool = false) -> int:
	var count := 0
	for def: Dictionary in defs:
		var id := str(def["id"])
		var steps: Array = def.get("steps", [])
		var value := stat(w, str(def.get("stat", "")))
		while steps_done(id) < steps.size() and value >= int(steps[steps_done(id)]):
			var i := steps_done(id)
			done[id] = i + 1
			count += 1
			if silent:
				continue
			var rewards: Array = def.get("bolts", [])
			var bolts := int(rewards[i]) if i < rewards.size() else 0
			if bolts > 0:
				w.bolts += bolts
				w.bolts_changed.emit(w.bolts)
			w.progression.add_xp(int(def.get("xp", 10)) * (i + 1))
			reached.emit(def, i, int(steps[i]), bolts)
	return count


func to_dict() -> Dictionary:
	return done.duplicate()


func from_dict(d: Dictionary) -> void:
	done = {}
	for k in d:
		done[str(k)] = int(d[k])
