extends TestCase
## Gebäude nach dem Kurswechsel: nur Schiff (Sonderklasse), Deko und Museum. Keine Fabrik mehr.


func test_only_ship_decor_and_museum_remain() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	for gone in ["sell_terminal", "furnace", "press", "conveyor", "extractor", "chest"]:
		assert_false(defs.has(gone), "Fabrik entfernt: " + gone)
	assert_true(defs.has("ship"))
	assert_true(defs.has("museum"))
	assert_eq(defs["museum"].requires_feature, "museum")
	for id in ["lantern", "bench", "planter", "sculpture", "sign", "stone_ring"]:
		assert_eq(defs[id].category, "decor")


func test_ship_accepts_everything_into_pending() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var s := Building.create(1, defs["ship"], Vector2i(2, 2), 0) as Ship
	assert_true(s != null)
	assert_eq(s.accept_stack("scrap", 300), 300, "das Schiff ist nie voll")
	assert_eq(s.accept_stack("copper", 5), 5)
	assert_true(s.tick())
	assert_eq(s.take_pending(), {"scrap": 300, "copper": 5})
	assert_false(s.tick())


func test_plain_buildings_accept_nothing() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var b := Building.create(2, defs["lantern"], Vector2i(5, 5), 0)
	assert_false(b is Ship)
	assert_eq(b.accept_stack("scrap", 5), 0)
	assert_eq(b.withdraw_stack(), {})


func test_decor_cost_curve_is_flat() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var bench: BuildingDef = defs["bench"]
	assert_eq(Economy.cost_for(bench, 0), Economy.cost_for(bench, 3))
