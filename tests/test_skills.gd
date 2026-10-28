extends TestCase
## Skilltree seit MS25: XP verbessert Rusty (Fahren, Saugen, Taschen, Werkzeug), Bolts nur das Schiff.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	w.rare_items = {"copper": true, "plastic": true, "chrome": true}
	w.player.pos = Vector2i(320, 320)
	return w


func _buy(w: SimWorld, id: String) -> void:
	w.queue_command({"type": "buy_skill", "id": id})
	w.tick()


func test_skills_and_ship_do_not_overlap() -> void:
	var w := _world()
	var skill_keys := {}
	for d: Dictionary in w.skills.defs:
		for e: Dictionary in d["effects"]:
			skill_keys[str(e["key"])] = true
	var ids := []
	for u: Dictionary in ShipSystem.upgrade_defs(w):
		ids.append(u["id"])
		for e: Dictionary in u["effects"]:
			assert_false(skill_keys.has(str(e["key"])), "doppelt in Skill und Schiff: " + str(e["key"]))
	assert_eq(ids, ["yield", "courier"], "am Schiff nur Ertrag und Kurier")


func test_buy_needs_points_and_requirements() -> void:
	var w := _world()
	var fails := []
	w.skill_failed.connect(func(r: String) -> void: fails.append(r))
	_buy(w, "drive")
	assert_eq(fails, ["points"])
	w.progression.skill_points = 3
	_buy(w, "boost")
	assert_eq(fails, ["points", "requires"], "Boost braucht Fahrtempo")
	_buy(w, "drive")
	_buy(w, "boost")
	_buy(w, "boost")
	assert_eq(w.progression.skill_points, 0)
	assert_eq(float(w.mods["boost_cooldown"]), 6.0)
	assert_true(absf(float(w.mods["speed_mult"]) - 1.08) < 0.001)


func test_tool_costs_three_points() -> void:
	var w := _world()
	assert_eq(w.skills.can_buy("tool", 2), "points")
	w.progression.skill_points = 3
	_buy(w, "tool")
	assert_eq(w.progression.skill_points, 0)
	assert_eq(w.player.hammer_tier, 2)
	assert_eq(w.player.suction_tier, 2)


func test_no_dead_ends_all_skills_reachable() -> void:
	var w := _world()
	w.progression.skill_points = 200
	var progress := true
	while progress:
		progress = false
		for d: Dictionary in w.skills.defs:
			var id := str(d["id"])
			if w.skills.can_buy(id, w.progression.skill_points) == "":
				_buy(w, id)
				progress = true
	var spent := 200 - w.progression.skill_points
	for d: Dictionary in w.skills.defs:
		assert_eq(w.skills.level_of(str(d["id"])), int(d["max_level"]), "Skill nicht voll: " + str(d["id"]))
	assert_true(spent <= 48, "alle Skills voll (%d Punkte) passen in die 48 Punkte bis Level 25" % spent)


func test_bags_and_magnet() -> void:
	var w := _world()
	w.progression.skill_points = 10
	w.player.inventory.add("scrap", 10)
	_buy(w, "bags")
	assert_eq(w.player.inventory.slot_count, 5)
	assert_eq(w.player.inventory.stack_size, 12)
	assert_eq(w.player.inventory.count_of("scrap"), 10, "Inhalt bleibt")
	_buy(w, "suck")
	_buy(w, "suck")
	_buy(w, "magnet")
	assert_eq(w.player.magnet_radius_px, 64)
	w.add_loose("copper", w.player.pos + Vector2i(-40, 0))
	w.add_loose("copper", w.player.pos + Vector2i(-200, 0))
	w.tick()
	assert_eq(w.player.inventory.count_of("copper"), 1)


func test_suck_and_reach() -> void:
	var w := _world()
	w.progression.skill_points = 10
	_buy(w, "suck")
	_buy(w, "suck")
	assert_eq(w.player.suck_interval, 4, "5 / 1,24 = 4,0 → 4")
	assert_eq(w.player.hammer_interval, 8, "10 / 1,24 = 8,1 → 8")
	_buy(w, "reach")
	_buy(w, "reach")
	assert_eq(w.player.suck_range_px, 224, "160 + 1 Kachel")


func test_yield_includes_rare_bonus() -> void:
	var w := _world()
	TestWorlds.with_ship(w)
	w.ship_upgrades["yield"] = 2
	w.recompute_modifiers()
	w.player.inventory.add("copper", 10)
	w.player.inventory.add("scrap", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	var sell := float(w.mods["sell_mult"])
	var rare := float(w.mods["rare_mult"])
	assert_true(rare > 1.0, "Ertrag enthält den Bonus für seltene Teile")
	assert_eq(w.bolts, int(round(30 * sell * rare)) + int(round(10 * sell)), "Kupfer mit Selten-Bonus, Schrott ohne")


func test_old_save_keeps_every_bought_level() -> void:
	var data := {"version": 8, "skills": {"boost": 2, "agility": 3, "stacker": 2, "magnet": 1, "connoisseur": 2, "tempo": 4, "reach": 1},
		"ship_upgrades": {"cargo": 3, "yield": 4, "speed": 2, "suction": 5, "tool": 1}, "progression": {"level": 6, "skill_points": 0}}
	var m := SaveMigrations.v8_to_v9(data)
	assert_eq(m["version"], 9)
	assert_eq(m["skills"], {"drive": 3, "boost": 2, "suck": 5, "reach": 1, "magnet": 1, "bags": 3, "tool": 1})
	assert_eq(m["ship_upgrades"], {"yield": 4})
	assert_eq(m["progression"]["skill_points"], 10, "alle Punkte nach neuer Regel zurück")
	var w := _world()
	SaveCodec.decode(m, w)
	assert_eq(w.player.inventory.slot_count, 7, "4 + 3 Taschen")
	assert_eq(w.player.hammer_tier, 2)
	assert_eq(w.skills.level_of("suck"), 5)
