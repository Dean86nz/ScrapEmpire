extends TestCase


func _map() -> Dictionary:
	return {
		"width": 40, "height": 30,
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}],
		"zone_order": ["a", "b"],
		"nodes": [{"kind": "scrap_pile", "x": 2, "y": 2, "amount": 10}, {"kind": "toaster", "x": 5, "y": 5}],
	}


func _cfg() -> Dictionary:
	return {"xp": 60, "collectibles": [
		{"id": "gnome", "zone": "a", "name_key": "COL_GNOME", "text_key": "COL_GNOME_TEXT", "sprite": ""},
		{"id": "duck", "zone": "b", "name_key": "COL_DUCK", "text_key": "COL_DUCK_TEXT", "sprite": ""},
	]}


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.helper_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/helpers.json"))
	w.drone_cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/drones.json"))
	w.collectible_cfg = _cfg()
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	MapLoader.apply(w, _map())
	w.player.pos = Vector2i(320, 352)
	return w


func test_decor_requires_feature_and_costs_wood() -> void:
	var w := _world()
	assert_true(not w.is_building_unlocked("lantern"), "Deko gesperrt ohne Feature")
	w.player.inventory.add("wood", 20)
	w.player.inventory.add("copper", 5)
	w.queue_command({"type": "place", "def_id": "lantern", "tile": Vector2i(8, 8)})
	w.tick()
	assert_eq(w.building_count("lantern"), 0)
	w.unlocked_features["decor"] = true
	assert_true(w.is_building_unlocked("lantern"))
	var cost := w.next_cost(w.defs["lantern"])
	assert_true(int(cost.get("wood", 0)) > 0, "Laterne kostet Holz")
	w.queue_command({"type": "place", "def_id": "lantern", "tile": Vector2i(8, 8)})
	w.tick()
	assert_eq(w.building_count("lantern"), 1)
	assert_eq(w.player.inventory.count_of("wood"), 20 - int(cost.get("wood", 0)))
	assert_eq(w.player.inventory.count_of("copper"), 5 - int(cost.get("copper", 0)))
	var def: BuildingDef = w.defs["lantern"]
	assert_eq(def.category, "decor")


func test_museum_unlocks_via_tech_effect() -> void:
	var w := _world()
	assert_true(not w.is_building_unlocked("museum"))
	w._apply_tech_effects("museum")
	assert_true(w.is_building_unlocked("museum"))
	var defs := TechState.load_defs("res://data/tech.json")
	var ids := []
	for d in defs:
		ids.append(str(d["id"]))
	assert_true(ids.has("decor_bench") and ids.has("museum"), "Techs vorhanden")


func test_collectibles_spawn_deterministically_in_their_zone() -> void:
	var w := _world()
	w.spawn_collectibles()
	assert_eq(w.collectibles.size(), 2)
	var tiles := {}
	for c: Collectible in w.collectibles.values():
		var z: Dictionary = w.zones.zone_by_id("a" if c.def_id == "gnome" else "b")
		assert_true((z["rect"] as Rect2i).has_point(c.tile), "%s liegt in seiner Zone" % c.def_id)
		tiles[c.def_id] = c.tile
	w.spawn_collectibles()
	assert_eq(w.collectibles.size(), 2, "kein doppeltes Platzieren")
	var w2 := _world()
	w2.spawn_collectibles()
	for c: Collectible in w2.collectibles.values():
		assert_eq(c.tile, tiles[c.def_id])


func test_walking_over_collects_and_gives_xp() -> void:
	var w := _world()
	w.spawn_collectibles()
	var found := []
	w.collectible_found.connect(func(c: Collectible, def: Dictionary) -> void: found.append([c.def_id, def.get("name_key")]))
	var gnome: Collectible = null
	for c: Collectible in w.collectibles.values():
		if c.def_id == "gnome":
			gnome = c
	var xp_before := w.progression.xp
	w.player.pos = gnome.center_px() + Vector2i(10, 0)
	w.tick()
	assert_eq(found, [["gnome", "COL_GNOME"]])
	assert_eq(w.collectibles.size(), 1)
	assert_true(w.collectibles_found.has("gnome"))
	assert_eq(w.progression.xp - xp_before, 60)
	assert_eq(w.collectible_def("gnome")["text_key"], "COL_GNOME_TEXT")


func test_save_keeps_found_and_does_not_respawn() -> void:
	var w := _world()
	w.spawn_collectibles()
	for c: Collectible in w.collectibles.values():
		if c.def_id == "gnome":
			w.player.pos = c.center_px()
	w.tick()
	var data := SaveCodec.encode(w, "main", Vector2(32, 32), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	assert_eq(data["collectibles_found"], ["gnome"])
	var w2 := _world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	w2.spawn_collectibles()
	assert_true(w2.collectibles_found.has("gnome"))
	assert_eq(w2.collectibles.size(), 1)
	assert_eq((w2.collectibles.values()[0] as Collectible).def_id, "duck")


func test_migration_v5_to_v6() -> void:
	var m := SaveMigrations.v5_to_v6({"version": 5})
	assert_eq(int(m["version"]), 6)
	assert_eq(m["collectibles_found"], [])
