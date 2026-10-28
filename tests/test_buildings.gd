extends TestCase
## Gebäude seit MS38: nur Schiff (Sonderklasse) und Sammelstelle. Keine Fabrik, Deko oder Museum mehr.


func test_only_ship_and_collection_point_remain() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	for gone in ["sell_terminal", "furnace", "press", "conveyor", "extractor", "chest",
			"lantern", "bench", "planter", "sculpture", "sign", "stone_ring", "museum"]:
		assert_false(defs.has(gone), "entfernt: " + gone)
	assert_eq(defs.keys().size(), 2)
	assert_true(defs.has("ship"))
	assert_false(defs["ship"].buildable)
	assert_eq(defs["collection_point"].requires_feature, "collection")


func test_ship_accepts_everything_into_pending() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var s := Building.create(1, defs["ship"], Vector2i(2, 2), 0) as Ship
	assert_true(s != null)
	assert_eq(s.accept_stack("scrap", 300), 300, "das Schiff ist nie voll")
	assert_eq(s.accept_stack("copper", 5), 5)
	assert_true(s.tick())
	assert_eq(s.take_pending(), {"scrap": 300, "copper": 5})
	assert_false(s.tick())

