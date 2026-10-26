extends TestCase


func _prog() -> Progression:
	return Progression.load_config("res://data/progression.json")


func test_curve_values() -> void:
	var p := _prog()
	assert_eq(p.xp_for_level(2), 100)
	assert_eq(p.xp_for_level(3), 115)
	assert_eq(p.xp_for_level(5), 150)
	assert_eq(p.xp_for_level(10), 305)
	assert_eq(p.xp_for_level(20), 1240)


func test_level_up_gives_skill_point() -> void:
	var p := _prog()
	var ups := []
	p.level_up.connect(func(l: int, sp: int) -> void: ups.append([l, sp]))
	p.add_xp(99)
	assert_eq(p.level, 1)
	p.add_xp(1)
	assert_eq(p.level, 2)
	assert_eq(p.skill_points, 1)
	assert_eq(p.xp, 0)
	assert_eq(ups, [[2, 1]])


func test_overflow_carries_over_multiple_levels() -> void:
	var p := _prog()
	p.add_xp(100 + 115 + 10)
	assert_eq(p.level, 3)
	assert_eq(p.xp, 10)
	assert_eq(p.skill_points, 2)


func test_level_cap() -> void:
	var p := _prog()
	p.add_xp(100000)
	assert_eq(p.level, 20)
	assert_eq(p.skill_points, 19)
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
	p.on_sale(3)
	assert_eq(p.total_xp, 9, "3 Bolts: noch keine XP")
	p.on_sale(3)
	assert_eq(p.total_xp, 10, "6 Bolts: 1 XP, Rest 1")
	p.on_sale(9)
	assert_eq(p.total_xp, 12, "Rest 1 + 9 = 10: 2 XP")
	p.on_tech(2000)
	assert_eq(p.total_xp, 212)


func test_world_grants_xp_for_collect_build_deliver() -> void:
	var w := TestWorlds.make()
	w.player.pos = Vector2i(320, 320)
	w.player.aim = Vector2.RIGHT
	w.add_pile("scrap_pile", Vector2i(6, 5), 10)
	w.player.suck_held = true
	w.tick()
	w.player.suck_held = false
	assert_eq(w.progression.total_xp, 1)
	w.unlocked_features["decor"] = true
	w.player.inventory.add("wood", 10)
	w.queue_command({"type": "place", "def_id": "bench", "tile": Vector2i(7, 7)})
	w.tick()
	assert_eq(w.progression.total_xp, 6, "Bauen gibt 5 XP")
	TestWorlds.with_ship(w, Vector2i(10, 2))
	w.player.inventory.add("chrome", 10)
	w.queue_command({"type": "deliver_all"})
	w.tick()
	assert_true(w.progression.total_xp >= 7, "Abliefern bringt XP")
