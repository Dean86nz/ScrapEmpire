extends TestCase


## Baut eine Welt mit möglichst viel Zustand.
func _populated() -> SimWorld:
	var w := TestWorlds.make()
	w.player.pos = Vector2i(320, 96)
	w.player.inventory.add("scrap", 23)
	w.player.inventory.add("chrome", 2)
	w.bolts = 777
	w.progression.add_xp(250)
	w.progression.skill_points = 3
	w.queue_command({"type": "buy_skill", "id": "tempo"})
	w.tick()
	var s := TestWorlds.with_ship(w, Vector2i(12, 5))
	s.stage = 2
	ShipSystem.apply_stage(w, s)
	w.ship_upgrades["cargo"] = 1
	w.recompute_modifiers()
	w.add_pile("scrap_pile", Vector2i(4, 5), 7)
	var toaster := w.add_object("toaster", Vector2i(2, 2))
	toaster.take_one()
	w.add_loose("copper", Vector2i(500, 500), 2)
	w.respawns.append({"kind": "fridge", "tile": Vector2i(20, 20), "ticks_left": 1234})
	return w


func test_roundtrip_restores_everything() -> void:
	var w := _populated()
	var data := SaveCodec.encode(w, "main", Vector2(320, 96), 2)
	var w2 := TestWorlds.make()
	var pos := SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	assert_eq(pos, Vector2(320, 96))
	assert_eq(w2.bolts, 777)
	assert_eq(w2.player.inventory.count_of("scrap"), 23)
	assert_eq(w2.player.inventory.count_of("chrome"), 2)
	assert_eq(w2.player.inventory.slot_count, 5, "Laderaum-Upgrade nach dem Laden")
	assert_eq(w2.progression.level, 3)
	assert_eq(w2.skills.level_of("tempo"), 1)
	assert_eq(w2.ship().stage, 2)
	assert_true(w2.unlocked_features.has("helpers"))
	assert_eq(w2.nodes.size(), 2)
	assert_eq(w2.loose.size(), 1)
	assert_eq(w2.respawns.size(), 1)
	assert_eq(w2.respawns[0]["tile"], Vector2i(20, 20))


func test_roundtrip_is_deterministic() -> void:
	var w := _populated()
	w.unlocked_features["helpers"] = true
	w.add_helper(Vector2i(6, 5), w.ship().tile)
	var data := SaveCodec.encode(w, "main", Vector2(320, 96), 0)
	var w2 := TestWorlds.make()
	SaveCodec.decode(JSON.parse_string(JSON.stringify(data)), w2)
	for i in 300:
		w.tick()
		w2.tick()
	assert_eq(w2.bolts, w.bolts)
	assert_eq(w2.nodes.size(), w.nodes.size())


func test_decode_ignores_unknown_entries() -> void:
	var w := TestWorlds.make()
	var data := {
		"version": SaveCodec.VERSION, "player": {"pos": [100, 100]},
		"nodes": [{"kind": "unicorn", "tile": [1, 1]}, {"kind": "toaster", "tile": [2, 2], "amount": 5}],
		"buildings": [{"def": "teleporter", "tile": [3, 3]}, {"def": "furnace", "tile": [8, 8]}, {"def": "ship", "tile": [10, 10]}],
	}
	SaveCodec.decode(data, w)
	assert_eq(w.nodes.size(), 1)
	assert_eq(w.buildings.size(), 1, "nur das Schiff: Ofen gibt es nicht mehr")


func test_old_saves_are_not_loaded() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm.use_directory("user://saves_test/")  # NIE der echte Ordner
	sm.delete_all()
	assert_true(sm.write({"version": 7, "bolts": 5}))
	assert_true(sm.has_only_old_saves())
	assert_eq(sm.read(), {}, "Fabrik-Spielstand wird nicht geladen")
	assert_true(sm.write({"version": SaveCodec.VERSION, "bolts": 9}))
	assert_false(sm.has_only_old_saves())
	assert_eq(int(sm.read()["bolts"]), 9)
	sm.archive_all()
	assert_false(sm.has_save())
	var backups := 0
	for f in DirAccess.get_files_at(sm.save_dir):
		if f.contains(".bak_"):
			backups += 1
			DirAccess.remove_absolute(sm.save_dir + f)
	assert_true(backups >= 1, "alter Stand gesichert, nicht gelöscht")
	sm.free()


func test_migration_callable_is_applied() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm.migrations[SaveCodec.VERSION - 1] = func(d: Dictionary) -> Dictionary:
		d["version"] = SaveCodec.VERSION
		d["bolts"] = int(d.get("bolts", 0)) + 100
		return d
	var migrated: Dictionary = sm.migrate({"version": SaveCodec.VERSION - 1, "bolts": 5})
	assert_eq(int(migrated["bolts"]), 105)
	sm.free()


func test_file_rotation_and_meta() -> void:
	var sm: Node = load("res://src/autoload/save_manager.gd").new()
	sm.use_directory("user://saves_test/")  # NIE der echte Ordner
	sm.delete_all()
	assert_false(sm.has_save())
	var v := SaveCodec.VERSION
	assert_true(sm.write({"version": v, "bolts": 1}))
	assert_true(sm.write({"version": v, "bolts": 2}))
	assert_true(sm.write({"version": v, "bolts": 3}))
	assert_eq(int(sm.read()["bolts"]), 3, "Meta zeigt auf den neuesten Stand")
	var latest: String = sm._latest_file()
	var f := FileAccess.open(sm.save_dir + latest, FileAccess.WRITE)
	f.store_string("{kaputt")
	f.close()
	assert_eq(int(sm.read()["bolts"]), 2, "Fallback auf die andere Datei")
	sm.delete_all()
	assert_false(sm.has_save())
	sm.free()
