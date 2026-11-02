class_name ArmyReport
extends RefCounted
## Bot-Menü-Übersicht (MS79): Anzahl und Leistung je Bot-Art plus Engpässe, die der Spieler
## beheben kann. Rein lesend.

const ISSUES := ["hopper_full", "no_hopper", "few_drones", "too_hard", "station_empty"]


## {"station": [Anzahl, Teile/min], "roamer": [Anzahl, Teile/min], "issues": [Schlüssel …]}
static func summary(w: SimWorld) -> Dictionary:
	var n_station := 0
	var n_roamer := 0
	var bored_empty := 0
	var too_hard := false
	var no_hopper := false
	for h: Helper in w.helpers.values():
		if h.kind == RoamerSystem.KIND:
			n_roamer += 1
			no_hopper = no_hopper or h.bored == "no_hopper"
		else:
			n_station += 1
			if h.bored == "empty" and h.inventory.total() == 0:
				bored_empty += 1
		too_hard = too_hard or h.bored == "too_hard"
	var issues: Array[String] = []
	for hop in RoamerSystem.hoppers(w):
		if hop.is_full():
			issues.append("hopper_full")
			break
	if no_hopper:
		issues.append("no_hopper")
	if few_drones(w):
		issues.append("few_drones")
	if too_hard:
		issues.append("too_hard")
	if bored_empty >= 3:
		issues.append("station_empty")
	return {
		"station": [n_station, w.perf.per_min("station", w.tick_count)],
		"roamer": [n_roamer, w.perf.per_min("roamer", w.tick_count)],
		"issues": issues,
	}


## Wartet in fernen Stationen und Trichtern deutlich mehr, als die Drohnen tragen können?
static func few_drones(w: SimWorld) -> bool:
	var waiting := 0
	for b: Building in w.buildings.values():
		if b is Hopper or (b is Station and not StationSystem.linked_to_ship(w, b as Station)):
			waiting += (b as CollectionPoint).total()
	if waiting < 40:
		return false
	var cap := 0
	for d: Drone in w.drones.values():
		cap += d.capacity
	return waiting > 4 * maxi(cap, 1)
