extends TestCase


func _fresh_world() -> SimWorld:
	ResourceNode.load_defs("res://data/scrap_objects.json")
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.recipes = RecipeDef.load_all("res://data/recipes.json")
	w.rare_items = {"copper": true}
	w.setup_progression_data(TechState.load_defs("res://data/tech.json"), SkillState.load_file("res://data/skills.json"))
	return w


## Baut eine Welt mit möglichst viel Zustand.
func _populated() -> SimWorld:
	var w := _fresh_world()
	w.player.pos = Vector2i(320, 96)  # Kachel (5,1), weg von den Gebäuden
	w.player.inventory.add("scrap", 33)
	w.player.inventory.add("chrome", 2)
	w.bolts = 777
	w.progression.add_xp(250)       # Level 3, 2 Punkte
	w.progression.skill_points = 3
	w.queue_command({"type": "buy_skill", "id": "smash"})
	w.tick()
	w.queue_command({"type": "research", "id": "furnace"})
	w.tick()
	for i in 50:
		w.tick()                     # Forschung läuft noch (150 Ticks übrig)
	w.add_pile("scrap_pile", Vector2i(4, 5), 7)
	var toaster := w.add_object("toaster", Vector2i(2, 2))
	toaster.take_one()
	w.add_loose("copper", Vector2i(500, 500), 2)
	w.place_free("extractor", Vector2i(5, 5), 0)
	var c1 := w.place_free("conveyor", Vector2i(6, 5), 0) as Conveyor
	c1.try_insert("scrap", 100)
	c1.try_insert("copper", 20)
	w.place_free("conveyor", Vector2i(7, 5), 0)
	var f := w.place_free("furnace", Vector2i(8, 5), 0) as Machine
	f.accept_stack("scrap", 7)
	f.tick()  # startet Rezept: progress 80, input 4
	f.output["iron_bar"] = 2
	var t := w.place_free("sell_terminal", Vector2i(12, 5), 0) as SellTerminal
	t.accept_stack("plastic", 3)
	var ch := w.place_free("chest", Vector2i(12, 8), 0) as Chest
	ch.accept_stack("gear", 4)
	w.respawns.append({"kind": "fridge", "tile": Vector2i(20, 20), "ticks_left": 1234})
	return w


func test_roundtrip_restores_everything() -> void:
	var w := _populated()
	var data := SaveCodec.encode(w, "tutorial", Vector2(320, 96), 2)
	var text := JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(text)
	var w2 := _fresh_world()
	var pos := SaveCodec.decode(parsed, w2)
	assert_eq(pos, Vector2(320, 96))
	assert_eq(w2.bolts, 727, "777 minus 50 Forschung")
	assert_eq(w2.player.inventory.count_of("scrap"), 33)
	assert_eq(w2.player.inventory.count_of("chrome"), 2)
	assert_eq(w2.progression.level, 3)
	assert_eq(w2.progression.skill_points, 2)
	assert_eq(w2.skills.level_of("smash"), 1)
	assert_eq(w2.player.hammer_tier, 2, "Modifiers nach dem Laden neu berechnet")
	assert_true(w2.tech.is_researching())
	assert_eq(w2.tech.current_id, "furnace")
	assert_eq(w2.tech.remaining_ticks, w.tech.remaining_ticks)
	assert_eq(w2.tech.is_unlocked("terminal"), true)
	assert_eq(w2.nodes.size(), 2)
	var pile_found := false
	var toaster_found := false
	for n: ResourceNode in w2.nodes.values():
		if n.kind == "scrap_pile":
			pile_found = n.amount == 7
		if n.kind == "toaster":
			toaster_found = n.amount == 9
	assert_true(pile_found and toaster_found)
	assert_eq(w2.loose.size(), 1)
	assert_eq(w2.buildings.size(), 6)
	var belt: Conveyor = w2.grid.at(Vector2i(6, 5))
	assert_eq(belt.items.size(), 2)
	assert_eq(belt.items[0], {"item": "scrap", "offset": 100})
	var f2: Machine = w2.grid.at(Vector2i(8, 5))
	assert_eq(f2.input.get("scrap", 0), 4)
	assert_eq(f2.output.get("iron_bar", 0), 2)
	assert_eq(f2.progress_ticks, 80)
	assert_eq(f2.current_recipe.id, "iron_bar")
	var t2: SellTerminal = w2.grid.at(Vector2i(12, 5))
	assert_eq(t2.buffer.size(), 3)
	var ch2: Chest = w2.grid.at(Vector2i(12, 8))
	assert_eq(ch2.contents(), {"gear": 4})
	assert_eq(w2.respawns.size(), 1)
	assert_eq(w2.respawns[0]["tile"], Vector2i(20, 20))


func test_roundtrip_is_deterministic() -> void:
	var w := _populated()
	var data := SaveCodec.encode(w, "tutorial", Vector2(320, 96), 0)
	var w2 := _fresh_world()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	for i in 300:
		w.tick()
		w2.tick()
	assert_eq(w2.bolts, w.bolts)
	assert_eq(w2.tech.remaining_ticks, w.tech.remaining_ticks)
	var f1: Machine = w.grid.at(Vector2i(8, 5))
	var f2: Machine = w2.grid.at(Vector2i(8, 5))
	assert_eq(f2.output, f1.output)
	assert_eq(f2.progress_ticks, f1.progress_ticks)
	var b1: Conveyor = w.grid.at(Vector2i(7, 5))
	var b2: Conveyor = w2.grid.at(Vector2i(7, 5))
	assert_eq(b2.items, b1.items)


func test_decode_ignores_unknown_entries() -> void:
	var w := _fresh_world()
	var data := {
		"version": 1, "player": {"pos": [100, 100]},
		"nodes": [{"kind": "unicorn", "tile": [1, 1]}, {"kind": "toaster", "tile": [2, 2], "amount": 5}],
		"buildings": [{"def": "teleporter", "tile": [3, 3]}, {"def": "chest", "tile": [4, 4]}],
	}
	SaveCodec.decode(data, w)
	assert_eq(w.nodes.size(), 1)
	assert_eq(w.buildings.size(), 1)


func test_migration_from_version_0_adds_defaults() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	var old := {"version": 0, "bolts": 5}
	var migrated: Dictionary = sm.migrate(old)
	assert_eq(int(migrated["version"]), SaveCodec.VERSION)
	assert_eq(int(migrated["bolts"]), 5)
	sm.free()


func test_migration_callable_is_applied() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm.migrations[0] = func(d: Dictionary) -> Dictionary:
		d["version"] = 1
		d["bolts"] = int(d.get("bolts", 0)) + 100
		return d
	var migrated: Dictionary = sm.migrate({"version": 0, "bolts": 5})
	assert_eq(int(migrated["bolts"]), 105)
	sm.free()


func test_file_rotation_and_meta() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm._ready()
	sm.delete_all()
	assert_false(sm.has_save())
	assert_true(sm.write({"version": 1, "bolts": 1}))
	assert_true(sm.write({"version": 1, "bolts": 2}))
	assert_true(sm.write({"version": 1, "bolts": 3}))
	assert_true(sm.has_save())
	assert_eq(int(sm.read()["bolts"]), 3, "Meta zeigt auf den neuesten Stand")
	# Neuester Stand kaputt → der ältere wird genommen
	var latest: String = sm._latest_file()
	var f := FileAccess.open(sm.SAVE_DIR + latest, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	assert_eq(int(sm.read()["bolts"]), 2, "Fallback auf die andere Datei")
	sm.delete_all()
	assert_false(sm.has_save())
	sm.free()
