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


func test_world_grants_xp_for_collect_build_sell() -> void:
	var w := SimWorld.new()
	w.set_size(40, 30)
	w.defs = BuildingDef.load_all("res://data/buildings.json")
	w.item_values = Economy.load_item_values("res://data/items.json")
	w.player.pos = Vector2i(320, 320)
	w.player.aim = Vector2.RIGHT
	w.add_pile("scrap_pile", Vector2i(6, 5), 10)
	w.player.suck_held = true
	w.tick()
	w.player.suck_held = false
	assert_eq(w.progression.total_xp, 1)
	w.player.inventory.add("scrap", 40)
	w.player.inventory.add("iron_bar", 5)
	w.queue_command({"type": "place", "def_id": "sell_terminal", "tile": Vector2i(7, 5)})
	w.tick()
	assert_eq(w.progression.total_xp, 6)
	w.player.inventory.add("scrap", 10)  # nach dem Bezahlen wieder Schrott in Slot 0
	w.queue_command({"type": "deposit", "tile": Vector2i(7, 5), "slot": 0})
	for i in 60:
		w.tick()
	assert_true(w.progression.total_xp >= 7, "Verkauf bringt XP")
