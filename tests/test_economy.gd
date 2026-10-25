extends TestCase


func test_terminal_is_flat_and_furnace_cost_curve() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var t: BuildingDef = defs["sell_terminal"]
	var flat: Array[int] = []
	var curve: Array[int] = []
	for n in 5:
		flat.append(Economy.cost_for(t, n)["scrap"])
		curve.append(Economy.cost_for(defs["furnace"], n)["scrap"])
	assert_eq(flat, [40, 40, 40, 40, 40] as Array[int], "Außenposten: feste Kosten")
	assert_eq(curve, [40, 55, 75, 100, 135] as Array[int], "Ofen: 35 % je Exemplar, auf 5 gerundet")


func test_chest_cost_is_flat() -> void:
	var defs := BuildingDef.load_all("res://data/buildings.json")
	var c: BuildingDef = defs["chest"]
	assert_eq(Economy.cost_for(c, 0)["scrap"], 10)
	assert_eq(Economy.cost_for(c, 7)["scrap"], 10)


func test_afford_pay_refund() -> void:
	var inv := Inventory.new(2, 20)
	inv.add("scrap", 35)
	var cost := {"scrap": 30}
	assert_true(Economy.can_afford(inv, cost))
	assert_false(Economy.can_afford(inv, {"scrap": 36}))
	assert_false(Economy.can_afford(inv, {"copper": 1}))
	Economy.pay(inv, cost)
	assert_eq(inv.count_of("scrap"), 5)
	var rest := Economy.refund(inv, {"scrap": 40})
	assert_eq(inv.count_of("scrap"), 40)
	assert_eq(rest.get("scrap", 0), 5)


func test_item_values() -> void:
	var v := Economy.load_item_values("res://data/items.json")
	assert_eq(v["scrap"], 1)
	assert_eq(v["copper"], 3)
	assert_eq(v["plastic"], 2)
