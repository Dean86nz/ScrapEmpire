extends TestCase
## Großer Planet und Ausbau (MS80): neue Karte lädt, Station- und Trichter-Upgrades wirken.


func test_big_map_loads_with_ship() -> void:
	var map: Dictionary = MapLoader.read("res://data/maps/main2.json")
	var w := TestWorlds.make(int(map["width"]), int(map["height"]))
	MapLoader.apply(w, map)
	assert_eq(Vector2i(w.width_tiles, w.height_tiles), Vector2i(180, 134))
	assert_true(w.ship() != null, "Schiff steht")
	assert_eq(w.zones.zones.size(), 6, "dieselben 6 Zonen")
	assert_true(w.nodes.size() > 2000, "deutlich mehr Müll: %d" % w.nodes.size())


func test_station_upgrades_raise_slots_and_radius() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(2, 2))
	var st := w.place_free(StationSystem.DEF, Vector2i(20, 15)) as Station
	StationSystem.apply(w, st)
	var h := w.add_helper(st.tile, st.tile)
	StationSystem.bind(h, st)
	var slots := st.slots
	var radius := st.radius_tiles
	w.helper_upgrades["station_slots"] = 2
	w.helper_upgrades["station_radius"] = 3
	w.recompute_modifiers()
	assert_eq(st.slots, slots + 2)
	assert_eq(st.radius_tiles, radius + 3)
	assert_eq(h.radius_tiles, radius + 3, "der Bot arbeitet im größeren Umkreis")


func test_hopper_upgrade_raises_capacity() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(2, 2))
	var hop := w.place_free(RoamerSystem.HOPPER_DEF, Vector2i(20, 15)) as Hopper
	var before := RoamerSystem.hopper_capacity(w)
	w.helper_upgrades["hopper_size"] = 4
	w.helper_upgrades["throw_range"] = 1
	w.recompute_modifiers()
	assert_eq(hop.capacity, before + 240)
	assert_eq(int(RoamerSystem.throw_range(w)), 1600 + 256)
