class_name FinaleStats
extends RefCounted
## Kennzahlen für den Abspann (MS37). Liefert Zeilen [Text-Schlüssel, Wert als Text].


static func rows(w: SimWorld) -> Array:
	var ticks := int(w.flags.get("launch_tick", w.tick_count))
	var minutes := ticks / 20 / 60
	var bosses := 0
	for k: String in w.flags:
		if k.begins_with("boss_"):
			bosses += 1
	var clean := 0
	for z in w.zones.summary(w.nodes):
		if int(z["stage"]) >= 3:
			clean += 1
	var c: Dictionary = w.quests.counters
	return [
		["STAT_TIME", "%d:%02d h" % [minutes / 60, minutes % 60]],
		["STAT_BOLTS", Fmt.int_str(int(c.get("sold_value", 0)))],
		["STAT_WRECKS", Fmt.int_str(int(c.get("wrecks", 0)))],
		["STAT_TILES", Fmt.int_str(w.dirt.cleaned_total)],
		["STAT_BOSSES", "%d / %d" % [bosses, w.zones.zones.size()]],
		["STAT_ZONES", "%d / %d" % [clean, w.zones.zones.size()]],
		["STAT_PLANET", "%d %%" % int(round(w.zones.planet_health(w.nodes) * 100.0))],
		["STAT_LEVEL", str(w.progression.level)],
		["STAT_BOTS", str(w.helpers.size())],
		["STAT_DRONES", str(w.drones.size())],
		["STAT_FINDS", str(w.collectibles_found.size())],
	]
