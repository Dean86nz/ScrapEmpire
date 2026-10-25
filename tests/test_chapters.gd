extends TestCase


func _map() -> Dictionary:
	return {
		"width": 60, "height": 30, "zone_order": ["a", "b", "c"], "unlock_cleanliness": 0.5,
		"zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 20, "h": 30}, {"id": "b", "name": "B", "x": 20, "y": 0, "w": 20, "h": 30}, {"id": "c", "name": "C", "x": 40, "y": 0, "w": 20, "h": 30}],
		"nodes": [
			{"kind": "toaster", "x": 5, "y": 5}, {"kind": "scrap_pile", "x": 2, "y": 2, "amount": 10},
			{"kind": "toaster", "x": 25, "y": 5}, {"kind": "scrap_pile", "x": 22, "y": 2, "amount": 10},
			{"kind": "toaster", "x": 45, "y": 5},
		],
	}


func _world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	MapLoader.apply(w, _map())
	w.player.pos = Vector2i(320, 352)
	w.player.hammer_tier = 3
	return w


func _smash(w: SimWorld, tile: Vector2i) -> void:
	var n: ResourceNode = null
	for x: ResourceNode in w.nodes.values():
		if x.tile == tile:
			n = x
	w.player.pos = n.center_px() + Vector2i(-40, 0)
	w.player.aim = Vector2.RIGHT
	for i in 12:
		w.player.hammer_pressed = true
		for j in 10:
			w.tick()


func test_initial_unlock_and_chapter() -> void:
	var w := _world()
	assert_true(w.zones.is_unlocked("a"))
	assert_false(w.zones.is_unlocked("b"))
	assert_eq(w.zones.current_chapter_zone(), "a")
	assert_eq(w.zones.next_chapter_zone(), "b")
	assert_eq(w.zones.chapter_index("c"), 2)


func test_zone_unlocks_when_previous_half_clean() -> void:
	var w := _world()
	var unlocked := []
	w.zone_unlocked.connect(func(id: String) -> void: unlocked.append(id))
	_smash(w, Vector2i(5, 5))  # einziger Müll in A → 100 %
	for i in 25:
		w.tick()
	assert_eq(unlocked, ["b"])
	assert_eq(w.zones.current_chapter_zone(), "b")
	assert_false(w.zones.is_unlocked("c"), "C erst nach B")


func test_helper_cannot_be_placed_in_locked_zone() -> void:
	var w := _world()
	w.unlocked_features["helpers"] = true
	w.bolts = 1000
	w.player.inventory.add("chrome", 5)
	w.place_free("chest", Vector2i(3, 10), 0)
	assert_eq(w.can_buy_helper(Vector2i(3, 10), Vector2i(25, 10)), "zone_locked")
	assert_eq(w.can_buy_helper(Vector2i(3, 10), Vector2i(5, 10)), "")


func test_fill_missing_zones_after_load() -> void:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	var data := _map()
	MapLoader.apply(w, data, false)
	w.add_object("toaster", Vector2i(5, 5))  # nur Zone A aus dem Spielstand
	var added := MapLoader.fill_missing_zones(w, data)
	assert_eq(added, 3, "Zonen B und C aufgefüllt, A unverändert")
	assert_eq(w.nodes.size(), 4)


func test_save_keeps_unlocked_zones() -> void:
	var w := _world()
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	w.zones.unlocked["b"] = true
	var data := SaveCodec.encode(w, "x", Vector2(320, 352), 0)
	assert_eq(int(data["version"]), SaveCodec.VERSION)
	var w2 := SimWorld.new()
	w2.defs = w.defs
	MapLoader.apply(w2, _map(), false)
	w2.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_true(w2.zones.is_unlocked("b"))
	assert_false(w2.zones.is_unlocked("c"))


func test_migration_v3_to_v4() -> void:
	var m := SaveMigrations.v3_to_v4({"version": 3})
	assert_eq(int(m["version"]), 4)
	assert_eq(m["unlocked_zones"], ["z01"])


func test_tech_costs_products() -> void:
	var defs := TechState.load_defs("res://data/tech.json")
	var by: Dictionary = {}
	for d in defs:
		by[d["id"]] = d
	assert_eq(int(by["conveyor"]["cost_items"]["iron_bar"]), 5)
	assert_eq(int(by["autopilot"]["cost_items"]["circuit"]), 5)
	assert_eq(int(by["autopilot"]["cost_items"]["chrome"]), 10)
	var b := BuildingDef.load_all("res://data/buildings.json")
	assert_eq(b["press"].cost, {"iron_bar": 5, "plastic": 20})
