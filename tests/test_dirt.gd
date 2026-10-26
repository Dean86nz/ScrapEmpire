extends TestCase
## Schmutz je Kachel (MS21): Erzeugung, Putzen mit dem Sauger, zerlegter Müll, Flächen-Sauberkeit, Speichern.


func _map(with_dirt: bool = true) -> Dictionary:
	return {
		"width": 40, "height": 30, "seed": 7, "dirt": with_dirt, "zone_order": ["a", "b"], "unlock_cleanliness": 0.5,
		"player_start": {"x": 5, "y": 15}, "ship": {"x": 2, "y": 13},
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}],
		"nodes": [{"kind": "toaster", "x": 12, "y": 10}, {"kind": "scrap_pile", "x": 15, "y": 20, "amount": 10}],
	}


func _world(with_dirt: bool = true) -> SimWorld:
	var w := TestWorlds.make()
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, _map(with_dirt))
	return w


func _tile_center(t: Vector2i) -> Vector2i:
	return t * 64 + Vector2i(32, 32)


func test_only_maps_with_dirt_get_dirt() -> void:
	assert_false(_world(false).dirt.is_active())
	var w := _world()
	assert_true(w.dirt.is_active())
	assert_eq(w.dirt.width, 40)


func test_generation_dirty_around_trash_clean_at_ship_and_deterministic() -> void:
	var w := _world()
	assert_eq(w.dirt.value(Vector2i(12, 10)), 255, "unter dem Toaster voll verschmutzt")
	assert_true(w.dirt.value(Vector2i(13, 11)) > 0, "Umfeld verschmutzt")
	assert_eq(w.dirt.value(Vector2i(3, 14)), 0, "Schiffsmitte sauber")
	assert_true(int(w.dirt.zone_start["a"]) > 100, "viele schmutzige Kacheln: %d" % int(w.dirt.zone_start["a"]))
	assert_true(w.zones.cleanliness("a", w.nodes) < 0.01, "Zone startet dreckig")
	var w2 := _world()
	assert_eq(w2.dirt.dirt, w.dirt.dirt, "gleicher Seed, gleicher Schmutz")


func test_suction_cleans_tiles_in_cone_only() -> void:
	var w := _world()
	var front := Vector2i(10, 6)
	var back := Vector2i(6, 6)
	w.dirt.soil(front, 200)
	w.dirt.soil(back, 200)
	w.player.pos = _tile_center(Vector2i(8, 6))
	w.player.aim = Vector2.RIGHT
	w.player.suck_held = true
	TestWorlds.run(w, 12)
	assert_eq(w.dirt.value(front), 0, "vor Rusty sauber")
	assert_eq(w.dirt.value(back), 200, "hinter Rusty bleibt Schmutz")


func test_cleaning_drops_scrap_now_and_then() -> void:
	var w := _world()
	w.player.pos = _tile_center(Vector2i(8, 20))
	w.player.aim = Vector2.RIGHT
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var t := Vector2i(8 + dx, 20 + dy)
			w.dirt.clean(t, 255)
			w.dirt.soil(t, 40)
	var collected := []
	w.item_collected.connect(func(item: String, _p: Vector2i) -> void: collected.append(item))
	w.player.suck_held = true
	TestWorlds.run(w, 20)
	assert_true(w.player.inventory.count_of("scrap") >= 1, "Kleinschrott beim Putzen")
	assert_true(collected.has("scrap"))


func test_removing_trash_cleans_the_ground_below() -> void:
	var w := _world()
	var toaster: ResourceNode = null
	for n: ResourceNode in w.nodes.values():
		if n.kind == "toaster":
			toaster = n
	var before := int(w.dirt.zone_now["a"])
	w._remove_node(toaster)
	assert_eq(w.dirt.value(Vector2i(12, 10)), 0)
	assert_eq(w.dirt.value(Vector2i(11, 9)), 0, "Radius 1 mit geputzt")
	assert_true(int(w.dirt.zone_now["a"]) < before)


func test_trash_tile_cannot_be_vacuumed_while_trash_lies_there() -> void:
	var w := _world()
	w.player.pos = _tile_center(Vector2i(11, 10))
	w.player.aim = Vector2.RIGHT
	w.player.suck_held = true
	TestWorlds.run(w, 30)
	assert_eq(w.dirt.value(Vector2i(12, 10)), 255, "unter dem Toaster bleibt es dreckig")


func test_zone_cleanliness_from_area_unlocks_gate() -> void:
	var w := _world()
	assert_false(w.zones.is_unlocked("b"))
	for y in 30:
		for x in 20:
			if w.dirt.value(Vector2i(x, y)) > 0 and not w._node_tiles.has(Vector2i(x, y)):
				w.dirt.clean(Vector2i(x, y), 255)
	var c := w.zones.cleanliness("a", w.nodes)
	assert_true(c > 0.9, "fast alles geputzt: %.2f" % c)
	TestWorlds.run(w, 21)
	assert_true(w.zones.is_unlocked("b"), "Tor öffnet sich über die geputzte Fläche")
	assert_true(w.zones.planet_health(w.nodes) > 0.3 and w.zones.planet_health(w.nodes) < 0.7, "Planet: Zone A sauber, B dreckig")


func test_respawned_trash_soils_again() -> void:
	var w := _world()
	w.dirt.clean(Vector2i(30, 5), 255)
	w.respawns.append({"kind": "toaster", "tile": Vector2i(30, 5), "ticks_left": 1})
	w.tick()
	assert_eq(w.dirt.value(Vector2i(30, 5)), 255)


func test_save_roundtrip_keeps_dirt() -> void:
	var w := _world()
	w.dirt.clean(Vector2i(12, 11), 255)
	w.dirt.soil(Vector2i(19, 29), 77)
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_true((data["dirt"]["dirt"] as String).length() < 20000, "komprimiert gespeichert")
	var w2 := TestWorlds.make()
	w2.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w2, _map(), false)
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_true(w2.dirt.is_active())
	assert_eq(w2.dirt.dirt, w.dirt.dirt)
	assert_eq(w2.dirt.start, w.dirt.start)
	assert_eq(w2.dirt.zone_now, w.dirt.zone_now)
	MapLoader.ensure_dirt(w2, _map())
	assert_eq(w2.dirt.dirt, w.dirt.dirt, "geladener Schmutz wird nicht neu erzeugt")


func test_old_save_without_dirt_gets_generated() -> void:
	var w := TestWorlds.make()
	w.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w, _map(), false)
	assert_false(w.dirt.is_active())
	MapLoader.ensure_dirt(w, _map())
	assert_true(w.dirt.is_active())


func test_ship_repair_sends_cleaning_wave() -> void:
	var w := _world()
	var s := w.ship()
	var c := s.tile + s.size() / 2
	var near := c + Vector2i(6, 0)
	var far := c + Vector2i(9, 0)
	w.dirt.soil(near, 200)
	w.dirt.soil(far, 200)
	TestWorlds.run(w, 30)
	assert_eq(s.clean_radius, 4, "Stufe 1: Welle bis Radius 4")
	assert_eq(w.dirt.value(near), 200, "außerhalb noch dreckig")
	w.bolts = 1000
	w.queue_command({"type": "upgrade_ship"})
	TestWorlds.run(w, 30)
	assert_eq(s.stage, 2)
	assert_eq(s.clean_radius, 7, "Stufe 2: Welle bis Radius 7")
	assert_eq(w.dirt.value(near), 0, "Welle hat geputzt")
	assert_eq(w.dirt.value(far), 200, "jenseits der Welle unberührt")
	assert_eq(w.player.inventory.count_of("scrap"), 0, "Schiffswelle gibt keinen Kleinschrott")


func test_ship_wave_radius_is_saved() -> void:
	var w := _world()
	w.bolts = 1000
	w.queue_command({"type": "upgrade_ship"})
	TestWorlds.run(w, 10)
	var r := w.ship().clean_radius
	assert_true(r > 0 and r < 7, "Welle mitten im Wachsen: %d" % r)
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	var w2 := TestWorlds.make()
	w2.dirt_cfg = DirtMap.load_config()
	MapLoader.apply(w2, _map(), false)
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(w2.ship().clean_radius, r)
	assert_eq(w2.ship().stage, 2)
