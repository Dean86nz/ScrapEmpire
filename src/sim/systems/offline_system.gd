class_name OfflineSystem
extends RefCounted
## Fortschritt im Hintergrund (MS81): Beim Laden wird die Abwesenheit hochgerechnet, höchstens
## 8 Stunden. Grundlage sind die gemessenen Raten der Bot-Armee (PerfStats, ohne Rustys Anteil),
## begrenzt durch den Müll, den die Bots überhaupt schaffen. Abgebaut wird zuerst Müll nahe an
## Stationen und Fangtrichtern. Deterministisch: die Dauer kommt von außen (echte Uhr liest nur
## das Spiel). Teilsystem von SimWorld: statische Funktionen.

const MAX_S := 8 * 3600
const MIN_S := 60


## Rechnet `elapsed_s` Sekunden Abwesenheit hoch und wendet sie an. Leer: nichts passiert.
## Sonst {"seconds", "trash", "bolts", "zones": [[Name, vorher, nachher], …]}.
static func apply(w: SimWorld, elapsed_s: int) -> Dictionary:
	var secs := clampi(elapsed_s, 0, MAX_S)
	if secs < MIN_S or w.helpers.is_empty():
		return {}
	var trash_rate := w.perf.per_min("trash", w.tick_count)
	var bot_rate := maxf(0.0, trash_rate - w.perf.per_min("rusty", w.tick_count))
	if bot_rate <= 0.0:
		return {}
	var bolts_per_part := w.perf.per_min("bolts", w.tick_count) / trash_rate
	var want := int(bot_rate * secs / 60.0)
	var before := _cleanliness(w)
	var got := _consume(w, want)
	if got <= 0:
		return {}
	var bolts := int(round(bolts_per_part * got))
	w.bolts += bolts
	w.progression.on_sale(bolts)
	w.bolts_changed.emit(w.bolts)
	var after := _cleanliness(w)
	var zones: Array = []
	for zid: String in before:
		if int(after[zid] * 100.0) > int(before[zid] * 100.0):
			zones.append([str(w.zones.zone_by_id(zid).get("name", zid)), before[zid], after[zid]])
	return {"seconds": secs, "trash": got, "bolts": bolts, "zones": zones}


static func _cleanliness(w: SimWorld) -> Dictionary:
	var out := {}
	for z: Dictionary in w.zones.zones:
		var zid := str(z["id"])
		if w.zones.is_unlocked(zid):
			out[zid] = w.zones.cleanliness(zid, w.nodes)
	return out


## Baut bis zu `want` Teile Müll ab, den die Bots schaffen (offene Zonen, Werkzeugstufe),
## zuerst nahe an Stationen und Trichtern. Gibt die abgebaute Menge zurück.
static func _consume(w: SimWorld, want: int) -> int:
	var tier := 1
	for h: Helper in w.helpers.values():
		tier = maxi(tier, maxi(h.hammer_tier, h.suction_tier))
	var anchors: Array[Vector2] = []
	for b: Building in w.buildings.values():
		if b is CollectionPoint:
			anchors.append(Vector2(b.center_px()))
	if anchors.is_empty():
		var s := ShipSystem.ship(w)
		if s != null:
			anchors.append(Vector2(s.center_px()))
	var cands: Array = []
	for n: ResourceNode in w.nodes.values():
		if n.boss or n.is_depleted() or n.tier > tier:
			continue
		var zid := w.zones.zone_id_at(n.tile)
		if zid != "" and not w.zones.is_unlocked(zid):
			continue
		var d := INF
		for a in anchors:
			d = minf(d, a.distance_to(Vector2(n.center_px())))
		cands.append([d, n.id])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var left := want
	var got := 0
	for c: Array in cands:
		if left <= 0:
			break
		var n: ResourceNode = w.nodes[c[1]]
		var take := mini(n.amount, left)
		n.amount -= take
		got += take
		left -= take
		if n.amount <= 0:
			_clean_around(w, n.tile)
			NodeSystem._remove_node(w, n)
	if w.dirt.is_active():
		w.zones.refresh(w.nodes)
	return got


## Bots saugen beim Abbau auch den Boden drumherum sauber.
static func _clean_around(w: SimWorld, tile: Vector2i) -> void:
	if not w.dirt.is_active():
		return
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			w.dirt.clean(tile + Vector2i(dx, dy), 255)
