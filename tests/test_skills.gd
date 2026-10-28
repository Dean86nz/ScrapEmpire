extends TestCase
## Skilltree seit MS25: XP verbessert Rusty (Fahren, Saugen, Taschen, Werkzeug), Bolts nur das Schiff.


func _world() -> SimWorld:
	var w := TestWorlds.make()
	w.rare_items = {"copper": true, "plastic": true, "chrome": true}
	w.player.pos = Vector2i(320, 320)
	return w


## Wert je Stufe eines Skill-Effekts aus skills.json.
func _per(w: SimWorld, id: String, key: String) -> float:
	for e: Dictionary in w.skills.by_id[id]["effects"]:
		if e["key"] == key:
			return float(e.get("per_level", 0.0))
	return 0.0


func _table(w: SimWorld, id: String, key: String) -> Array:
	for e: Dictionary in w.skills.by_id[id]["effects"]:
		if e["key"] == key:
			return e.get("values", [])
	return []


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
	assert_true(absf(float(w.mods["speed_mult"]) - (1.0 + _per(w, "drive", "speed_mult"))) < 0.001, "schneller um den Wert aus skills.json")
	assert_true(float(w.mods["speed_mult"]) > 1.0, "spürbar schneller")


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
	var start_points := 0
	for d: Dictionary in w.skills.defs:
		start_points += int(d["max_level"]) * int(d.get("cost_points", 1))
	start_points += 50  # Puffer: es darf nichts übrig bleiben, was noch kaufbar wäre
	w.progression.skill_points = start_points
	var progress := true
	while progress:
		progress = false
		for d: Dictionary in w.skills.defs:
			var id := str(d["id"])
			if w.skills.can_buy(id, w.progression.skill_points) == "":
				_buy(w, id)
				progress = true
	var spent := start_points - w.progression.skill_points
	for d: Dictionary in w.skills.defs:
		assert_eq(w.skills.level_of(str(d["id"])), int(d["max_level"]), "Skill nicht voll: " + str(d["id"]))
	# alle Punkte bis zum Level-Limit (progression.json) reichen für alle Skills
	var prog := Progression.load_config("res://data/progression.json")
	var cap_points := (prog.level_cap - 1) * prog.points_per_level
	assert_true(spent <= cap_points, "alle Skills voll (%d Punkte) passen in die %d Punkte bis Level %d" % [spent, cap_points, prog.level_cap])


func test_bags_and_magnet() -> void:
	var w := _world()
	# so viele Taschen-Stufen, dass mindestens ein ganzer Slot dazukommt
	var bag_levels := ceili(1.0 / _per(w, "bags", "slots_add") - 0.001)
	w.progression.skill_points = bag_levels + 3
	w.player.inventory.add("scrap", 10)
	for i in bag_levels:
		_buy(w, "bags")
	assert_eq(w.player.inventory.slot_count, 4 + int(round(_per(w, "bags", "slots_add") * bag_levels)))
	assert_true(w.player.inventory.slot_count > 4, "mehr Slots")
	assert_eq(w.player.inventory.stack_size, 10 + int(round(_per(w, "bags", "stack_add") * bag_levels)))
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
	var mine := 1.0 + 2 * _per(w, "suck", "mine_speed_mult")
	assert_eq(w.player.suck_interval, maxi(int(round(5 / mine)), 1), "5 / Saugtempo")
	assert_eq(w.player.hammer_interval, maxi(int(round(10 / mine)), 2), "10 / Saugtempo")
	assert_true(w.player.suck_interval < 5, "schneller als ohne Skill")
	assert_eq(w.player.suck_targets, int(_table(w, "suck", "suck_targets")[1]), "Teile je Zug laut Tabelle")
	assert_true(w.player.suck_targets > 1, "mehrere Teile je Zug")
	_buy(w, "reach")
	_buy(w, "reach")
	assert_eq(w.player.suck_range_px, 160 + int(round(2 * _per(w, "reach", "range_add") * 64)), "Reichweite je Stufe aus skills.json")
	assert_true(w.player.suck_range_px > 160)


func test_full_suction_is_a_vortex_that_pulls_many_at_once() -> void:
	var w := _world()
	# erste Stufe mit 360° laut Tabelle = Wirbel
	var cones := _table(w, "suck", "suck_cone_deg")
	var vortex := 0
	for i in cones.size():
		if float(cones[i]) >= 360.0:
			vortex = i + 1
			break
	assert_true(vortex > 0, "Saugen hat eine Wirbel-Stufe")
	w.progression.skill_points = vortex
	for i in vortex:
		_buy(w, "suck")
	assert_eq(w.skills.level_of("suck"), vortex)
	assert_true(w.player.suck_half_angle >= PI - 0.01, "Wirbel rundherum")
	assert_eq(w.player.suck_targets, int(_table(w, "suck", "suck_targets")[vortex - 1]))
	assert_true(w.player.suck_targets >= 6, "genug Teile je Zug für den Test")
	# Teile hinter Rusty werden auch eingesaugt, mehrere in einem Zug
	for i in 6:
		w.add_loose("scrap", w.player.pos + Vector2i(-60 - i * 6, 10))
	w.player.aim = Vector2.RIGHT
	w.player.suck_held = true
	w.tick()
	assert_eq(w.player.inventory.count_of("scrap"), 6, "sechs Teile in einem Zug, auch von hinten")


func test_old_save_with_higher_levels_gets_points_back() -> void:
	var w := _world()
	var max_drive := int(w.skills.by_id["drive"]["max_level"])
	var max_suck := int(w.skills.by_id["suck"]["max_level"])
	var refund := w.skills.from_dict({"drive": max_drive + 3, "suck": max_suck + 3})
	assert_eq(w.skills.level_of("drive"), max_drive)
	assert_eq(w.skills.level_of("suck"), max_suck)
	assert_eq(refund, 6, "3 + 3 Stufen zurück")


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
	assert_eq(w.skills.level_of("bags"), 3)
	assert_eq(w.player.inventory.slot_count, 4 + int(round(3 * _per(w, "bags", "slots_add"))), "4 + 3 Taschen-Stufen")
	assert_eq(w.player.inventory.stack_size, 10 + int(round(3 * _per(w, "bags", "stack_add"))), "Stapel aus 3 Taschen-Stufen")
	assert_eq(w.player.hammer_tier, 2)
	assert_eq(w.skills.level_of("suck"), 5)
