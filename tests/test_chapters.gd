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


func test_removed_objects_stay_gone_after_load() -> void:
	# Ally-Fehler v2.12.0: nach Speichern/Laden waren aller Müll und alle Bosse wieder da.
	var w := _world()
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	var data := _map()
	var before := w.nodes.size()
	var gone: ResourceNode = w.nodes.values()[0]
	w._remove_node(gone)
	var save := SaveCodec.encode(w, "x", Vector2(320, 352), 0)
	var w2 := SimWorld.new()
	w2.defs = w.defs
	w2.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	MapLoader.load_save(w2, data, save)
	assert_eq(w2.nodes.size(), before - 1, "abgebautes Objekt bleibt weg")
	# ganz leer geräumt: auch nach dem Laden leer (kein Nachfüllen aus der Karte)
	for n: ResourceNode in w2.nodes.values().duplicate():
		w2._remove_node(n)
	var save2 := SaveCodec.encode(w2, "x", Vector2(320, 352), 0)
	var w3 := SimWorld.new()
	w3.defs = w.defs
	w3.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	MapLoader.load_save(w3, data, save2)
	assert_eq(w3.nodes.size(), 0, "saubere Zonen bleiben sauber")


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


func test_factory_data_is_gone() -> void:
	var tech := TechState.load_defs("res://data/tech.json")
	assert_eq(tech.size(), 0, "Forschungsbaum entfällt, Freischaltungen über Schiffsstufen")
	assert_false(FileAccess.file_exists("res://data/recipes.json"))
	var items := Economy.load_item_values("res://data/items.json")
	for gone in ["iron_bar", "copper_bar", "plastic_sheet", "gear", "circuit"]:
		assert_false(items.has(gone), "Produkt entfernt: " + gone)
	assert_eq(int(items["scrap"]), 1)
	assert_eq(int(items["chrome"]), 8)
