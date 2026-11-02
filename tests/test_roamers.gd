extends TestCase
## Streuner, Müllwürfel, Fangtrichter (MS77): Zielsuche über Zonengrenzen, Würfel zum Trichter,
## voller Trichter leitet um, ohne Trichter Symbol, Trichter → Drohne → Schiff → Bolts.


func _world(open_b := true) -> SimWorld:
	var w := TestWorlds.make(60, 30)
	MapLoader.apply(w, {"width": 60, "height": 30, "zone_order": ["a", "b"], "unlock_cleanliness": 2.0,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 2},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 30, "h": 30}, {"id": "b", "name": "B", "x": 30, "y": 0, "w": 30, "h": 30}],
		"nodes": []})
	if open_b:
		w.zones.unlocked["b"] = true
	return w


func _roamer(w: SimWorld, tile: Vector2i) -> Helper:
	var h := w.add_helper(tile, w.ship().tile)
	h.kind = RoamerSystem.KIND
	h.zone_id = ""
	h.pos = tile * SimWorld.TILE
	return h


func test_roamer_finds_work_in_other_zone() -> void:
	var w := _world()
	var pile := w.add_pile("scrap_pile", Vector2i(45, 15), 10)
	var h := _roamer(w, Vector2i(10, 15))
	assert_eq(RoamerSystem.find_target(w, h), pile, "keine Zonenbindung")


func test_roamer_ignores_closed_zone() -> void:
	var w := _world(false)
	w.add_pile("scrap_pile", Vector2i(45, 15), 10)
	var h := _roamer(w, Vector2i(10, 15))
	assert_eq(RoamerSystem.find_target(w, h), null, "geschlossene Zone bleibt tabu")


func test_cube_skips_full_hopper() -> void:
	var w := _world()
	var full := w.place_free("hopper", Vector2i(12, 20)) as Hopper
	full.capacity = 10
	full.accept_stack("scrap", 10)
	var free := w.place_free("hopper", Vector2i(20, 20)) as Hopper
	var h := _roamer(w, Vector2i(10, 18))
	h.inventory.add("scrap", 12)
	assert_true(RoamerSystem.throw_cube(w, h))
	assert_eq(h.inventory.total(), 0, "Ladung ist als Würfel unterwegs")
	TestWorlds.run(w, 60)
	assert_eq(free.total(), 12, "Würfel landet im freien Trichter")
	assert_eq(full.total(), 10)


func test_no_hopper_shows_symbol() -> void:
	var w := _world()
	w.add_pile("scrap_pile", Vector2i(14, 15), 10)
	var h := _roamer(w, Vector2i(10, 15))
	h.inventory.add("scrap", h.inventory.slot_count * h.inventory.stack_size)
	TestWorlds.run(w, 3)
	assert_eq(h.bored, "no_hopper")
	assert_true(h.inventory.total() > 0, "behält die Ladung")


func test_hopper_drone_ship_bolts() -> void:
	var w := _world()
	var hop := w.place_free("hopper", Vector2i(12, 12)) as Hopper
	hop.accept_stack("scrap", 20)
	w.add_drone()
	TestWorlds.run(w, 20 * 60)
	assert_true(hop.total() < 20, "Drohne holt ab")
	assert_true(w.bolts > 0, "am Schiff werden Bolts daraus: %d" % w.bolts)


func test_save_keeps_roamer_and_cube() -> void:
	var w := _world()
	var hop := w.place_free("hopper", Vector2i(20, 20)) as Hopper
	var h := _roamer(w, Vector2i(10, 18))
	h.inventory.add("scrap", 5)
	RoamerSystem.throw_cube(w, h)
	var data := SaveCodec.encode(w, "main", Vector2(320, 96), 0)
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(RoamerSystem.count(w2), 1, "Streuner bleibt Streuner")
	assert_eq(w2.cubes.size(), 1, "Würfel fliegt weiter")
	TestWorlds.run(w2, 80)
	var hop2: Hopper = RoamerSystem.hoppers(w2)[0]
	assert_eq(hop2.total(), 5, "und landet nach dem Laden im Trichter")
	assert_eq(hop.capacity, hop2.capacity)
