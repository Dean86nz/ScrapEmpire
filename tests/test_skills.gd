extends TestCase
## Skilltree nach dem Kurswechsel: nur noch Perks, die sich nicht mit den Schiff-Upgrades doppeln.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	w.rare_items = {"copper": true, "plastic": true, "chrome": true}
	w.player.pos = Vector2i(320, 320)
	return w


func _buy(w: SimWorld, id: String) -> void:
	w.queue_command({"type": "buy_skill", "id": id})
	w.tick()


func test_defs_without_ship_overlaps() -> void:
	var w := _world()
	var ids := []
	for d in w.skills.defs:
		ids.append(str(d["id"]))
	assert_eq(ids.size(), 7)
	for gone in ["fast_wheels", "pockets", "haggle", "smash", "suction_power", "wholesale"]:
		assert_false(ids.has(gone), "ins Schiff umgezogen oder entfallen: " + gone)


func test_buy_needs_points_and_requirements() -> void:
	var w := _world()
	var fails := []
	w.skill_failed.connect(func(r: String) -> void: fails.append(r))
	_buy(w, "boost")
	assert_eq(fails, ["points"])
	w.progression.skill_points = 3
	_buy(w, "agility")
	assert_eq(fails, ["points", "requires"], "Wendigkeit braucht Turbo")
	_buy(w, "boost")
	_buy(w, "boost")
	_buy(w, "agility")
	assert_eq(w.progression.skill_points, 0)
	assert_eq(float(w.mods["boost_cooldown"]), 6.0)


func test_no_dead_ends_all_skills_reachable() -> void:
	var w := _world()
	w.progression.skill_points = 100
	var progress := true
	while progress:
		progress = false
		for d: Dictionary in w.skills.defs:
			var id := str(d["id"])
			if w.skills.can_buy(id, w.progression.skill_points) == "":
				_buy(w, id)
				progress = true
	for d: Dictionary in w.skills.defs:
		assert_eq(w.skills.level_of(str(d["id"])), int(d["max_level"]), "Skill nicht voll: " + str(d["id"]))


func test_stacker_and_magnet() -> void:
	var w := _world()
	w.progression.skill_points = 10
	w.player.inventory.add("scrap", 10)
	_buy(w, "stacker")
	assert_eq(w.player.inventory.stack_size, 15)
	assert_eq(w.player.inventory.count_of("scrap"), 10, "Inhalt bleibt")
	_buy(w, "stacker")
	_buy(w, "magnet")
	assert_eq(w.player.magnet_radius_px, 64)
	w.add_loose("copper", w.player.pos + Vector2i(-40, 0))
	w.add_loose("copper", w.player.pos + Vector2i(-200, 0))
	w.tick()
	assert_eq(w.player.inventory.count_of("copper"), 1)


func test_connoisseur_raises_rare_delivery() -> void:
	var w := _world()
	TestWorlds.with_ship(w)
	w.progression.skill_points = 3
	_buy(w, "connoisseur")
	_buy(w, "connoisseur")
	w.player.inventory.add("copper", 10)
	w.player.inventory.add("scrap", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_eq(w.bolts, 36 + 10, "Kupfer 30 × 1,2 = 36, Schrott unverändert")


func test_tempo_and_reach() -> void:
	var w := _world()
	w.progression.skill_points = 10
	_buy(w, "tempo")
	_buy(w, "tempo")
	assert_eq(w.player.suck_interval, 4, "5 / 1,30 = 3,8 → 4")
	assert_eq(w.player.hammer_interval, 8, "10 / 1,30 = 7,7 → 8")
	_buy(w, "reach")
	_buy(w, "reach")
	assert_eq(w.player.suck_range_px, 224, "160 + 1 Kachel")
