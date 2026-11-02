class_name StationSystem
extends RefCounted
## Stations-Bots (MS78): Jeder Sammel-Bot gehört zu einer kleinen Station, arbeitet nur in ihrem
## Umkreis und liefert dort ab. Stationen nah am Schiff schießen ihre Ladung als Würfel hinüber,
## weiter entfernte leert eine Drohne. Alte Sammelstellen werden beim Laden zu Fangtrichter plus
## Station. Werte in data/helpers.json („station“). Teilsystem von SimWorld: statische Funktionen.

const DEF := "station"


static func cfg(w: SimWorld) -> Dictionary:
	return w.helper_cfg.get("station", {})


static func stations(w: SimWorld) -> Array[Station]:
	var out: Array[Station] = []
	for b: Building in w.buildings.values():
		if b is Station:
			out.append(b as Station)
	return out


static func bots_of(w: SimWorld, st: Station) -> int:
	var n := 0
	for h: Helper in w.helpers.values():
		if h.station_id == st.id:
			n += 1
	return n


## Station mit freiem Platz, die `pos` am nächsten liegt (null: keine).
static func free_station_near(w: SimWorld, pos: Vector2i) -> Station:
	var best: Station = null
	var best_d := INF
	for st in stations(w):
		if bots_of(w, st) >= st.slots:
			continue
		var d := Vector2(pos).distance_to(Vector2(st.center_px()))
		if d < best_d:
			best_d = d
			best = st
	return best


## Liegt nah genug am Schiff, um selbst hinüberzuschießen?
static func linked_to_ship(w: SimWorld, st: Station) -> bool:
	var s := ShipSystem.ship(w)
	return s != null and Vector2(st.center_px()).distance_to(Vector2(s.center_px())) <= float(cfg(w).get("ship_link_px", 900))


static func apply(w: SimWorld, st: Station) -> void:
	st.radius_tiles = int(cfg(w).get("radius_tiles", 7))
	st.slots = int(cfg(w).get("slots", 3))


## Bot an seine Station binden: arbeitet im Kreis um sie, liefert dort ab.
static func bind(h: Helper, st: Station) -> void:
	h.station_id = st.id
	h.zone_id = ""
	h.zone_tile = st.tile
	h.radius_tiles = st.radius_tiles
	h.depot_tile = st.tile
	h.request_replan()


static func _cmd_build(w: SimWorld, _cmd: Dictionary) -> void:
	BuildingSystem.place_near_player(w, DEF)


static func _tick(w: SimWorld) -> void:
	if w.tick_count % 20 != 11:
		return
	var s := ShipSystem.ship(w)
	if s == null:
		return
	for st in stations(w):
		if st.total() >= int(cfg(w).get("send_min", 6)) and linked_to_ship(w, st):
			RoamerSystem.launch_cube(w, st.contents(), st.center_px(), s)
			st.store.clear()
			w.building_changed.emit(st)


## Alte Spielstände (vor MS78): jede Sammelstelle wird Fangtrichter (mit Inhalt) plus Station,
## jeder Bot ohne Station bekommt einen freien Platz in seiner Zone, sonst eine neue Station dort,
## wo er gerade arbeitet (so verteilt sich eine große Armee).
static func migrate(w: SimWorld) -> void:
	for b: Building in w.buildings.values().duplicate():
		if b.def.id != NetworkSystem.POINT_DEF:
			continue
		var store := (b as CollectionPoint).contents()
		var tile := b.tile
		BuildingSystem.remove_free(w, b)
		var hop := w.place_free(RoamerSystem.HOPPER_DEF, tile, 0) as Hopper
		if hop != null:
			hop.capacity = int(RoamerSystem.cfg(w).get("hopper_capacity", 120))
			hop.store = store
		var st := BuildingSystem.place_free_near(w, DEF, tile + Vector2i(2, 0)) as Station
		if st != null:
			apply(w, st)
	for h: Helper in w.helpers.values():
		if h.kind != "" or (h.station_id >= 0 and w.buildings.has(h.station_id)):
			continue
		# Station mit freiem Platz in seiner Zone, sonst eine neue dort, wo er gerade arbeitet
		var best: Station = null
		var best_d := INF
		for st in stations(w):
			if bots_of(w, st) >= st.slots or (h.zone_id != "" and w.zones.zone_id_at(st.tile) != h.zone_id):
				continue
			var d := Vector2(h.pos).distance_to(Vector2(st.center_px()))
			if d < best_d:
				best_d = d
				best = st
		if best == null:
			best = BuildingSystem.place_free_near(w, DEF, h.pos / SimWorld.TILE) as Station
			if best == null:
				continue
			apply(w, best)
		bind(h, best)
