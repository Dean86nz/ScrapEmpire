class_name ZoneTracker
extends RefCounted
## Zonen und Reinigungsgrad (GDD Kap. 23). Müll = Items in Loot-Objekten ohne "resource"-Flag.
## reinigungsgrad = 1 − müll_jetzt / müll_start. Stufen: 0 vermüllt (< 25 %), 1 unordentlich
## (< 50 %), 2 aufgeräumt (< 90 %), 3 sauber (≥ 90 %). Ab 50 % respawnt kein Müll mehr.

signal stage_changed(zone_id: String, stage: int)
signal zone_unlocked(zone_id: String)

const RESPAWN_STOP := 0.5
const STAGE_THRESHOLDS := [0.25, 0.5, 0.9]

var zones: Array[Dictionary] = []     # {id, name, rect: Rect2i, tutorial}
var start_trash: Dictionary = {}      # zone_id → int
var order: Array[String] = []         # Kapitel-Reihenfolge
var unlock_cleanliness := 0.5
var unlocked: Dictionary = {}         # zone_id → true (entdeckt/freigeschaltet)
var _stages: Dictionary = {}          # zone_id → int


func setup(zone_defs: Array, map_nodes: Array, zone_order: Array = [], p_unlock: float = 0.5) -> void:
	zones.clear()
	start_trash.clear()
	_stages.clear()
	order.clear()
	for id in zone_order:
		order.append(str(id))
	unlock_cleanliness = p_unlock
	unlocked.clear()
	if not order.is_empty():
		unlocked[order[0]] = true
	for z: Dictionary in zone_defs:
		var id := str(z.get("id", ""))
		zones.append({
			"id": id, "name": str(z.get("name", id)),
			"rect": Rect2i(int(z.get("x", 0)), int(z.get("y", 0)), int(z.get("w", 1)), int(z.get("h", 1))),
			"tutorial": bool(z.get("tutorial", false)),
		})
		start_trash[id] = 0
	# Müll-Start aus der Kartendefinition (deterministisch, unabhängig vom Spielstand)
	for n: Dictionary in map_nodes:
		var kind := str(n.get("kind", ""))
		if not ResourceNode.has_kind(kind):
			continue
		var d: Dictionary = ResourceNode.defs[kind]
		if str(d.get("type", "pile")) != "loot" or bool(d.get("resource", false)):
			continue
		var tile := Vector2i(int(n.get("x", 0)), int(n.get("y", 0)))
		var zid := zone_id_at(tile)
		if zid == "":
			continue
		var amount := 0
		if n.has("loot"):
			for k in n["loot"]:
				amount += int(n["loot"][k])
		else:
			for k in d.get("yield", {}):
				amount += int(d["yield"][k])
		start_trash[zid] = int(start_trash[zid]) + amount


func is_unlocked(zone_id: String) -> bool:
	return order.is_empty() or unlocked.has(zone_id)


## Index der Zone in der Kapitelreihenfolge (-1 wenn unbekannt).
func chapter_index(zone_id: String) -> int:
	return order.find(zone_id)


## Aktuelles Kapitel = letzte freigeschaltete Zone in der Reihenfolge.
func current_chapter_zone() -> String:
	var last := ""
	for id in order:
		if unlocked.has(id):
			last = id
	return last


func next_chapter_zone() -> String:
	var found_current := false
	var cur := current_chapter_zone()
	for id in order:
		if found_current:
			return id
		if id == cur:
			found_current = true
	return ""


## Prüft, ob die nächste Zone freigeschaltet werden darf (vorherige zu unlock_cleanliness sauber).
func check_unlocks(nodes: Dictionary) -> void:
	var cur := current_chapter_zone()
	var next := next_chapter_zone()
	if cur == "" or next == "" or unlocked.has(next):
		return
	if cleanliness(cur, nodes) >= unlock_cleanliness:
		unlocked[next] = true
		zone_unlocked.emit(next)


func zone_id_at(tile: Vector2i) -> String:
	for z in zones:
		if (z["rect"] as Rect2i).has_point(tile):
			return str(z["id"])
	return ""


func zone_by_id(id: String) -> Dictionary:
	for z in zones:
		if z["id"] == id:
			return z
	return {}


## Aktueller Müll je Zone aus den lebenden Knoten.
func current_trash(nodes: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for z in zones:
		result[z["id"]] = 0
	for n: ResourceNode in nodes.values():
		if not n.is_wreck() or n.is_resource():
			continue
		var zid := zone_id_at(n.tile)
		if zid != "":
			result[zid] = int(result[zid]) + n.amount
	return result


func cleanliness(zone_id: String, nodes: Dictionary) -> float:
	var start := int(start_trash.get(zone_id, 0))
	if start <= 0:
		return 1.0
	var now := int(current_trash(nodes).get(zone_id, 0))
	return clampf(1.0 - float(now) / float(start), 0.0, 1.0)


static func stage_for(value: float) -> int:
	var stage := 0
	for t in STAGE_THRESHOLDS:
		if value >= float(t):
			stage += 1
	return stage


func stage(zone_id: String, nodes: Dictionary) -> int:
	return stage_for(cleanliness(zone_id, nodes))


func allows_trash_respawn(tile: Vector2i, nodes: Dictionary) -> bool:
	var zid := zone_id_at(tile)
	if zid == "":
		return true
	return cleanliness(zid, nodes) < RESPAWN_STOP


## Nach Änderungen aufrufen: meldet Stufenwechsel.
func refresh(nodes: Dictionary) -> void:
	for z in zones:
		var id: String = z["id"]
		var st := stage(id, nodes)
		if _stages.get(id, -1) != st:
			var had := _stages.has(id)
			_stages[id] = st
			if had:
				stage_changed.emit(id, st)


## Übersicht für Karte/Minimap: {id, name, rect, cleanliness, stage, trash_by_tier}
func summary(nodes: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var trash_now := current_trash(nodes)
	for z in zones:
		var id: String = z["id"]
		var by_tier: Dictionary = {}
		for n: ResourceNode in nodes.values():
			if n.is_wreck() and not n.is_resource() and zone_id_at(n.tile) == id:
				by_tier[n.tier] = int(by_tier.get(n.tier, 0)) + 1
		var c := cleanliness(id, nodes)
		result.append({"id": id, "name": z["name"], "rect": z["rect"], "cleanliness": c, "stage": stage_for(c),
			"trash_now": int(trash_now.get(id, 0)), "trash_start": int(start_trash.get(id, 0)), "trash_by_tier": by_tier, "tutorial": z["tutorial"]})
	return result
