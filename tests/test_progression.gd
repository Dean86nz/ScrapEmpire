extends TestCase


func _prog() -> Progression:
	return Progression.load_config("res://data/progression.json")


func _cfg() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/progression.json"))


func test_curve_values() -> void:
	var p := _prog()
	var c := _cfg()
	var base := float(c["level_base_xp"])
	var growth := float(c["level_growth"])
	var r := int(c["level_round_to"])
	assert_eq(p.xp_for_level(2), int(c["level_base_xp"]))
	for n in [3, 5, 10, 20, 50]:
		assert_eq(p.xp_for_level(n), int(round(base * pow(growth, n - 2) / r)) * r, "Level %d: Basis × Wachstum^(n-2), gerundet" % n)
	assert_true(p.xp_for_level(20) > p.xp_for_level(10) and p.xp_for_level(10) > p.xp_for_level(3), "Kurve steigt")


func test_level_up_gives_skill_point() -> void:
	var p := _prog()
	var ups := []
	p.level_up.connect(func(l: int, sp: int) -> void: ups.append([l, sp]))
	p.add_xp(99)
	assert_eq(p.level, 1)
	p.add_xp(1)
	assert_eq(p.level, 2)
	assert_eq(p.skill_points, 2)
	assert_eq(p.xp, 0)
	assert_eq(ups, [[2, 2]])


func test_overflow_carries_over_multiple_levels() -> void:
	var p := _prog()
	p.add_xp(p.xp_for_level(2) + p.xp_for_level(3) + 10)
	assert_eq(p.level, 3)
	assert_eq(p.xp, 10)
	assert_eq(p.skill_points, 2 * p.points_per_level)


func test_level_cap() -> void:
	var p := _prog()
	var cap := int(_cfg()["level_cap"])
	var total := 0
	for n in range(2, cap + 1):
		total += p.xp_for_level(n)
	p.add_xp(total - 1)
	assert_eq(p.level, cap - 1, "1 XP vor dem Limit")
	p.add_xp(1000)
	assert_eq(p.level, cap)
	assert_eq(p.skill_points, (cap - 1) * int(_cfg()["skill_points_per_level"]))
	assert_eq(p.xp, 0)
	p.add_xp(50)
	assert_eq(p.xp, 0, "am Limit keine XP mehr")


func test_sources() -> void:
	var p := _prog()
	p.on_collect(1)
	p.on_collect(3)
	assert_eq(p.total_xp, 4)
	p.on_build()
	assert_eq(p.total_xp, 9)
	var bpx := int(_cfg()["xp_sources"]["bolts_per_xp"])
	p.on_sale(bpx - 2)
	assert_eq(p.total_xp, 9, "knapp unter einer XP: noch keine XP")
	p.on_sale(3)
	assert_eq(p.total_xp, 10, "1 XP, Rest 1")
	p.on_sale(2 * bpx - 1)
	assert_eq(p.total_xp, 12, "Rest 1 + (2 × Satz − 1): 2 XP")
	p.on_tech(2000)
	assert_eq(p.total_xp, 12 + 2000 / int(_cfg()["xp_sources"]["tech_cost_divisor"]))


func test_world_grants_xp_for_collect_build_deliver() -> void:
	var w := TestWorlds.make()
	# eine Zone, damit die Sammelstelle (max. 1 je Zone) gebaut werden darf
	MapLoader.apply(w, {"width": 40, "height": 30, "zones": [{"id": "a", "name": "A", "x": 0, "y": 0, "w": 40, "h": 30}], "nodes": []})
	w.player.pos = Vector2i(320, 320)
	w.player.aim = Vector2.RIGHT
	w.add_pile("scrap_pile", Vector2i(6, 5), 10)
	w.player.suck_held = true
	w.tick()
	w.player.suck_held = false
	assert_eq(w.progression.total_xp, 1)
	w.unlocked_features["collection"] = true
	w.bolts = int(w.next_cost(w.defs["collection_point"]).get("bolts", 0))
	w.queue_command({"type": "place", "def_id": "collection_point", "tile": Vector2i(7, 7)})
	w.tick()
	assert_eq(w.progression.total_xp, 6, "Bauen gibt 5 XP")
	TestWorlds.with_ship(w, Vector2i(10, 2))
	w.player.inventory.add("chrome", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_true(w.progression.total_xp >= 7, "Abliefern bringt XP")
