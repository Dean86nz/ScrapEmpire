extends TestCase
## Leistungsanzeige (MS79): Raten pro Minute über 5 Minuten, Zählung am Schiff, Engpässe.


func test_rate_per_minute() -> void:
	var p := PerfStats.new()
	p.add("trash", 50, 0)
	p.add("trash", 50, 1100)
	assert_eq(int(round(p.per_min("trash", 1200))), 100, "100 Teile in 60 s")


func test_old_buckets_expire() -> void:
	var p := PerfStats.new()
	p.add("trash", 300, 0)
	assert_eq(int(round(p.per_min("trash", 6400))), 0, "nach über 5 Minuten vergessen")
	p.add("trash", 60, 6500)
	assert_true(p.per_min("trash", 6600) > 0.0)


func test_ship_counts_trash_and_bolts() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(9, 9))
	w.ship().accept_stack("scrap", 10)
	TestWorlds.run(w, 2)
	assert_true(w.perf.per_min("trash", w.tick_count) > 0.0, "Müll am Schiff gezählt")
	assert_true(w.perf.per_min("bolts", w.tick_count) > 0.0, "Bolts gezählt")


func test_issues_full_hopper_and_few_drones() -> void:
	var w := TestWorlds.make()
	TestWorlds.with_ship(w, Vector2i(2, 2))
	var hop := w.place_free("hopper", Vector2i(30, 20)) as Hopper
	hop.capacity = 100
	hop.accept_stack("scrap", 100)
	var issues: Array = ArmyReport.summary(w)["issues"]
	assert_true(issues.has("hopper_full"), "voller Trichter erkannt")
	assert_true(issues.has("few_drones"), "keine Drohne für 100 wartende Teile")
	for i in 20:
		w.add_drone()
	assert_false(ArmyReport.few_drones(w), "genug Drohnen")
