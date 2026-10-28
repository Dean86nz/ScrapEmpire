class_name SecretSystem
extends RefCounted
## Secrets und Easter Eggs (MS60). Fortschritt steht in `SimWorld.flags` („secret_<id>“ = Zähler,
## „secret_<id>_done“ = gefunden) und wird damit automatisch gespeichert. Jedes gefundene Secret
## gibt einen kleinen Bolts-Bonus (`bonus_sell` je Secret); `steam_id` dient später als Steam-Erfolg.

static var defs: Array = []


static func load_defs() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/secrets.json"))
	defs = (d as Dictionary).get("secrets", []) if d is Dictionary else []


static func def_of(id: String) -> Dictionary:
	if defs.is_empty():
		load_defs()
	for s: Dictionary in defs:
		if str(s["id"]) == id:
			return s
	return {}


static func is_found(w: SimWorld, id: String) -> bool:
	return bool(w.flags.get("secret_%s_done" % id, false))


static func found_count(w: SimWorld) -> int:
	if defs.is_empty():
		load_defs()
	var n := 0
	for s: Dictionary in defs:
		if is_found(w, str(s["id"])):
			n += 1
	return n


## Einen Fortschritt melden (z. B. eine von 12 Enten). Gibt true zurück, wenn das Secret jetzt fertig ist.
static func progress(w: SimWorld, id: String, step: int = 1) -> bool:
	if is_found(w, id):
		return false
	var d := def_of(id)
	if d.is_empty():
		return false
	var n := int(w.flags.get("secret_" + id, 0)) + step
	w.flags["secret_" + id] = n
	if n >= int(d.get("count", 1)):
		w.flags["secret_%s_done" % id] = true
		w.recompute_modifiers()
		w.secret_found.emit(id)
		return true
	w.secret_progress.emit(id, n, int(d.get("count", 1)))
	return false


## Bolts-Bonus je gefundenem Secret (multiplikativ auf sell_mult).
static func sell_bonus(w: SimWorld) -> float:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/secrets.json"))
	var per := float((d as Dictionary).get("bonus_sell", 0.02)) if d is Dictionary else 0.02
	return 1.0 + per * found_count(w)


## Objekt mit `secret` im Def wurde abgebaut.
static func on_node_removed(w: SimWorld, n: ResourceNode) -> void:
	var sid := str(ResourceNode.defs.get(n.kind, {}).get("secret", ""))
	if sid != "":
		progress(w, sid)


## Prüfungen je Sekunde: goldene Statue (Planet 100 %), Speedrun (Abflug < 2 h).
static func tick(w: SimWorld) -> void:
	if w.tick_count % 20 != 3:
		return
	var had_trash := false
	for k in w.zones.start_trash:
		if int(w.zones.start_trash[k]) > 0:
			had_trash = true
	if not is_found(w, "statue") and had_trash and w.zones.planet_health(w.nodes) >= 0.999:
		progress(w, "statue")
	if not is_found(w, "speedrun") and w.flags.has("launch_tick") and int(w.flags["launch_tick"]) < 20 * 3600 * 2:
		progress(w, "speedrun")
